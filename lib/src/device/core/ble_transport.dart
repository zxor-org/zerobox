import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/ble_gatt_driver.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/device/core/transport.dart';

class BleTransport implements Transport {
  BleTransport.xiaomi(BleConnection connection)
    : _bleConnection = connection,
      _bluetoothConnection = null,
      _serviceUuid = _xiaomiServiceUuid,
      _recvCharUuid = _xiaomiRecvCharUuid,
      _sentCharUuid = _xiaomiSentCharUuid;

  BleTransport.zepp(BleConnection connection)
    : _bleConnection = connection,
      _bluetoothConnection = null,
      _serviceUuid = _zeppServiceUuid,
      _recvCharUuid = _zeppRecvCharUuid,
      _sentCharUuid = _zeppSentCharUuid;

  BleTransport.xiaomiBluetooth(BluetoothConnection connection)
    : _bleConnection = null,
      _bluetoothConnection = connection,
      _serviceUuid = _xiaomiServiceUuid,
      _recvCharUuid = _xiaomiRecvCharUuid,
      _sentCharUuid = _xiaomiSentCharUuid;

  BleTransport.zeppBluetooth(BluetoothConnection connection)
    : _bleConnection = null,
      _bluetoothConnection = connection,
      _serviceUuid = _zeppServiceUuid,
      _recvCharUuid = _zeppRecvCharUuid,
      _sentCharUuid = _zeppSentCharUuid;

  static final _log = getLogger('BleTransport');
  final BleConnection? _bleConnection;
  final BluetoothConnection? _bluetoothConnection;
  final String _serviceUuid;
  final String _recvCharUuid;
  final String _sentCharUuid;

  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _valueSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  static const String _xiaomiServiceUuid =
      '0000fe95-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiRecvCharUuid =
      '0000005e-0000-1000-8000-00805f9b34fb';
  static const String _xiaomiSentCharUuid =
      '0000005f-0000-1000-8000-00805f9b34fb';

  static const String _zeppServiceUuid = '00001530-0000-3512-2118-0009af100700';
  static const String _zeppRecvCharUuid =
      '00000017-0000-3512-2118-0009af100700';
  static const String _zeppSentCharUuid =
      '00000016-0000-3512-2118-0009af100700';

  @override
  String get deviceId =>
      _bleConnection?.deviceId ?? _bluetoothConnection!.deviceId;

  @override
  String get deviceName =>
      _bleConnection?.deviceName ?? _bluetoothConnection!.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState =>
      _bleConnection?.connectionState ?? _bluetoothConnection!.connectionState;

  Future<void> start() async {
    _log.info('[$deviceId] starting transport on recv=$_recvCharUuid');
    final bleConnection = _bleConnection;
    if (bleConnection != null) {
      _valueSubscription = await bleConnection.subscribe(
        _serviceUuid,
        _recvCharUuid,
        _incomingController.add,
      );
    } else {
      await _bluetoothConnection!.subscribe(
        characteristic: BleRequiredCharacteristic(
          serviceUuid: _serviceUuid,
          characteristicUuid: _recvCharUuid,
        ),
        onData: _incomingController.add,
      );
    }
    _connectionSubscription = connectionState.listen(
      (connected) {
        _log.info('[$deviceId] transport connection state: $connected');
        if (!connected && !_incomingController.isClosed) {
          _incomingController.close();
        }
      },
      onError: (Object e) =>
          _log.warning('[$deviceId] connection stream error', e),
    );
  }

  @override
  Future<void> send(Uint8List data) async {
    _log.fine('[$deviceId] sending ${data.length} bytes');
    final bleConnection = _bleConnection;
    if (bleConnection != null) {
      await bleConnection.write(
        _serviceUuid,
        _sentCharUuid,
        data,
        withResponse: false,
      );
    } else {
      await _bluetoothConnection!.send(
        data,
        characteristic: BleRequiredCharacteristic(
          serviceUuid: _serviceUuid,
          characteristicUuid: _sentCharUuid,
        ),
      );
    }
  }

  @override
  Future<void> dispose() async {
    _log.info('[$deviceId] disposing transport');
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await (_bleConnection?.dispose() ?? _bluetoothConnection!.dispose());
  }
}
