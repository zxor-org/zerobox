import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/services/ble_gatt_driver.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';

class BleProtocolConnection implements ProtocolConnection {
  BleProtocolConnection(this._connection);

  final BleConnection _connection;
  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _valueSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  static const String xiaomiServiceUuid =
      '0000fe95-0000-1000-8000-00805f9b34fb';
  static const String xiaomiRecvCharUuid =
      '0000005e-0000-1000-8000-00805f9b34fb';
  static const String xiaomiSentCharUuid =
      '0000005f-0000-1000-8000-00805f9b34fb';

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  Future<void> start() async {
    _valueSubscription = await _connection.subscribe(
      xiaomiServiceUuid,
      xiaomiRecvCharUuid,
      _incomingController.add,
    );
    _connectionSubscription = _connection.connectionState.listen((connected) {
      if (!connected) {
        _incomingController.close();
      }
    });
  }

  @override
  Future<void> send(Uint8List data) async {
    await _connection.write(
      xiaomiServiceUuid,
      xiaomiSentCharUuid,
      data,
      withResponse: false,
    );
  }

  @override
  Future<void> dispose() async {
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await _connection.dispose();
  }
}
