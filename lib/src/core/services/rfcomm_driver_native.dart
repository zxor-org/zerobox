import 'dart:async';

import 'package:flutter/services.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/device/core/connect_type.dart';

class NativeRfcommConnection implements RfcommConnection {
  NativeRfcommConnection({
    required this.deviceId,
    required this.deviceName,
    required this._service,
  });

  @override
  final String deviceId;

  @override
  final String deviceName;

  final NativeRfcommDriver _service;
  bool _disposed = false;

  @override
  Stream<Uint8List> get incomingData => _service.incomingData;

  @override
  Stream<bool> get connectionState => _service.connectionState;

  @override
  Future<void> start() async {
    _service._markConnected();
  }

  @override
  Future<void> send(Uint8List data) => _service.send(data);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _service.disconnect();
  }
}

class NativeRfcommDriver implements RfcommDriver {
  NativeRfcommDriver() : _log = getLogger('RfcommDriver');

  static const _method = MethodChannel('zerobox/classic_spp');
  static const _events = EventChannel('zerobox/classic_spp/events');
  static const _scanEvents = EventChannel('zerobox/classic_spp/scan_events');

  final Logger _log;
  Stream<BluetoothEndpoint>? _scanData;
  StreamSubscription<Object?>? _eventSubscription;
  final _incomingController = StreamController<Uint8List>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();
  final _scanResults = <String, BluetoothEndpoint>{};

  Stream<Uint8List> get incomingData {
    _ensureEventSubscription();
    return _incomingController.stream;
  }

  Stream<bool> get connectionState {
    _ensureEventSubscription();
    return _connectionController.stream;
  }

  void _ensureEventSubscription() {
    _eventSubscription ??= _events.receiveBroadcastStream().listen(
      _onNativeEvent,
      onError: (Object e, StackTrace st) {
        _log.warning('SPP event stream error', e, st);
        _markDisconnected();
      },
    );
  }

  void _onNativeEvent(Object? event) {
    if (event is Uint8List) {
      _incomingController.add(event);
      return;
    }
    if (event is List<int>) {
      _incomingController.add(Uint8List.fromList(event));
      return;
    }
    if (event is Map) {
      final kind = event['event'] as String?;
      if (kind == 'disconnected') {
        _log.info('SPP native event: disconnected');
        _markDisconnected();
        return;
      }
      if (kind == 'data') {
        final data = event['data'];
        if (data is Uint8List) {
          _incomingController.add(data);
          return;
        }
        if (data is List<int>) {
          _incomingController.add(Uint8List.fromList(data));
          return;
        }
      }
    }
    throw StateError('Unexpected SPP event: ${event.runtimeType}');
  }

  void _markConnected() {
    if (!_connectionController.isClosed) {
      _connectionController.add(true);
    }
  }

  void _markDisconnected() {
    if (!_connectionController.isClosed) {
      _connectionController.add(false);
    }
  }

  @override
  Stream<BluetoothEndpoint> get scanStream {
    return _scanData ??= _scanEvents.receiveBroadcastStream().map((event) {
      if (event is! Map) {
        throw StateError('Unexpected SPP scan event: ${event.runtimeType}');
      }
      final addr = event['addr'] as String? ?? event['address'] as String?;
      if (addr == null || addr.isEmpty) {
        throw StateError('SPP scan event missing address');
      }
      final rawName = event['name'] as String?;
      final endpoint = BluetoothEndpoint(
        name: rawName?.trim().isNotEmpty == true
            ? rawName!.trim()
            : 'Unknown device',
        address: addr,
        connectType: ConnectType.spp,
      );
      final previous = _scanResults[endpoint.address];
      final shouldLog =
          previous == null ||
          previous.name != endpoint.name ||
          previous.connectType != endpoint.connectType;
      if (shouldLog) {
        _log.info(
          'device_identity platform.spp_scan '
          'addr=$addr sppName="$rawName" displayName="${endpoint.name}"',
        );
      }
      _scanResults[endpoint.address] = endpoint;
      return endpoint;
    });
  }

  @override
  Future<void> requestPermissions() async {
    await _method.invokeMethod<void>('requestPermissions');
  }

  @override
  Future<void> startScan({
    Duration timeout = const Duration(seconds: 15),
  }) async {
    _scanResults.clear();
    await _method.invokeMethod<void>('startScan', {
      'timeoutMs': timeout.inMilliseconds,
    });
  }

  @override
  Future<List<BluetoothEndpoint>> stopScan() async {
    final result = await _method.invokeListMethod<Object?>('stopScan');
    if (result != null) {
      for (final item in result) {
        if (item is! Map) continue;
        final addr = item['addr'] as String? ?? item['address'] as String?;
        if (addr == null || addr.isEmpty) continue;
        final rawName = item['name'] as String?;
        final displayName = rawName?.trim().isNotEmpty == true
            ? rawName!.trim()
            : 'Unknown device';
        _log.info(
          'device_identity platform.spp_scan_result '
          'addr=$addr sppName="$rawName" displayName="$displayName"',
        );
        _scanResults[addr] = BluetoothEndpoint(
          name: displayName,
          address: addr,
          connectType: ConnectType.spp,
        );
      }
    }
    return _scanResults.values.toList(growable: false);
  }

  @override
  Future<RfcommConnection> connect(
    String deviceId,
    String deviceName, {
    String? serviceUuid,
    List<int> fallbackChannels = const [5, 1],
  }) async {
    _ensureEventSubscription();
    _log.info('[$deviceId] initiating SPP connection');
    final Map<String, Object?>? result;
    try {
      result = await _method.invokeMapMethod<String, Object?>('connect', {
        'addr': deviceId,
        if (serviceUuid != null) 'serviceUuid': serviceUuid,
        'fallbackChannels': fallbackChannels,
      });
    } on PlatformException catch (e) {
      // Normalize the platform-specific native error (Android Java exception
      // text, macOS FlutterError) into one stable shape so the UI error
      // mapping does not have to match every native wording.
      _log.warning('[$deviceId] SPP connect failed: ${e.code} ${e.message}');
      throw StateError('SPP connect failed: ${e.code}: ${e.message}');
    }
    _log.info('[$deviceId] SPP connected on channel ${result?['channel']}');
    final connection = NativeRfcommConnection(
      deviceId: deviceId,
      deviceName: deviceName,
      service: this,
    );
    await connection.start();
    return connection;
  }

  @override
  Future<void> send(Uint8List data) async {
    await _method.invokeMethod<void>('send', {'data': data});
  }

  @override
  Future<void> disconnect() async {
    await _method.invokeMethod<void>('disconnect');
    _markDisconnected();
  }
}

RfcommDriver createRfcommDriver() => NativeRfcommDriver();
RfcommConnection createRfcommConnection({
  required String deviceId,
  required String deviceName,
  required RfcommDriver service,
}) => NativeRfcommConnection(
  deviceId: deviceId,
  deviceName: deviceName,
  service: service as NativeRfcommDriver,
);
