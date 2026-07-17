import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/core/transport.dart';

class DeviceEntity {
  DeviceEntity({
    required this.id,
    required this.kind,
    required this.transport,
    required this.eventBus,
  }) : _log = getLogger('DeviceEntity');

  final String id;
  final String kind;
  final Transport transport;
  final DeviceEventBus eventBus;
  final Logger _log;

  final _components = <Type, Object>{};
  final _systems = <System>[];
  final _rawIncomingController = StreamController<Uint8List>.broadcast();
  Dispatcher? _dispatcher;
  StreamSubscription<Uint8List>? _incomingSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  Stream<Uint8List> get rawIncomingData => _rawIncomingController.stream;

  T? get<T>() => _components[T] as T?;
  T getRequired<T>() => _components[T] as T;
  void set<T>(T component) => _components[T] = component as Object;

  void registerSystem(System system) {
    system.attach(this);
    _systems.add(system);
    _dispatcher?.register(system);
  }

  void setDispatcher(Dispatcher dispatcher) {
    _dispatcher = dispatcher;
    for (final system in _systems) {
      dispatcher.register(system);
    }
  }

  T? system<T extends System>() {
    for (final s in _systems) {
      if (s is T) return s;
    }
    return null;
  }

  void emit(DeviceEvent event) => eventBus.emit(event);

  void startListening() {
    _log.fine('[$id] start listening');
    _incomingSubscription = transport.incomingData.listen(
      _onIncomingData,
      onError: (Object e) {
        _log.warning('[$id] incoming data stream error', e);
        _emitDisconnected();
      },
      onDone: () {
        _log.info('[$id] incoming data stream closed');
        _emitDisconnected();
      },
    );
    _connectionSubscription = transport.connectionState.listen(
      _onConnectionStateChanged,
      onError: (Object e) =>
          _log.warning('[$id] connection state stream error', e),
    );
  }

  void _onIncomingData(Uint8List data) {
    _log.fine('[$id] received ${data.length} bytes');
    _rawIncomingController.add(Uint8List.fromList(data));
    try {
      _dispatcher?.dispatch(data);
    } catch (e, st) {
      _log.severe('[$id] dispatcher error', e, st);
    }
  }

  void _onConnectionStateChanged(bool connected) {
    _log.info('[$id] transport connection state: $connected');
    if (!connected) {
      _emitDisconnected();
    }
  }

  void _emitDisconnected() {
    emit(DeviceError(deviceId: id, error: 'transport disconnected'));
    emit(TransportDisconnected(deviceId: id));
  }

  Future<void> dispose() async {
    _log.fine('[$id] disposing entity');
    await _incomingSubscription?.cancel();
    await _connectionSubscription?.cancel();
    await _rawIncomingController.close();
    for (final system in _systems) {
      try {
        await system.dispose();
      } catch (e, st) {
        _log.warning('[$id] system dispose error', e, st);
      }
    }
    await transport.dispose();
  }
}
