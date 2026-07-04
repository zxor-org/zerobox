import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/device/core/transport.dart';

class SppTransport implements Transport {
  SppTransport.xiaomi(RfcommConnection connection)
    : _rfcommConnection = connection,
      _bluetoothConnection = null;

  SppTransport.zeppBtbr(RfcommConnection connection)
    : _rfcommConnection = connection,
      _bluetoothConnection = null;

  SppTransport.xiaomiBluetooth(BluetoothConnection connection)
    : _rfcommConnection = null,
      _bluetoothConnection = connection;

  SppTransport.zeppBtbrBluetooth(BluetoothConnection connection)
    : _rfcommConnection = null,
      _bluetoothConnection = connection;

  static final _log = getLogger('SppTransport');
  final RfcommConnection? _rfcommConnection;
  final BluetoothConnection? _bluetoothConnection;

  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _dataSubscription;
  StreamSubscription<bool>? _connectionSubscription;

  @override
  String get deviceId =>
      _rfcommConnection?.deviceId ?? _bluetoothConnection!.deviceId;

  @override
  String get deviceName =>
      _rfcommConnection?.deviceName ?? _bluetoothConnection!.deviceName;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState =>
      _rfcommConnection?.connectionState ??
      _bluetoothConnection!.connectionState;

  Future<void> start() async {
    _log.info('[$deviceId] starting SPP transport');
    final incomingData =
        _rfcommConnection?.incomingData ?? _bluetoothConnection!.incomingData;
    _dataSubscription = incomingData.listen(
      _incomingController.add,
      onError: (Object e) =>
          _log.warning('[$deviceId] SPP data stream error', e),
      onDone: () {
        if (!_incomingController.isClosed) {
          _incomingController.close();
        }
      },
    );
    _connectionSubscription = connectionState.listen(
      (connected) {
        _log.info('[$deviceId] SPP connection state: $connected');
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
    _log.fine('[$deviceId] sending ${data.length} bytes over SPP');
    await (_rfcommConnection?.send(data) ?? _bluetoothConnection!.send(data));
  }

  @override
  Future<void> dispose() async {
    _log.info('[$deviceId] disposing SPP transport');
    await _dataSubscription?.cancel();
    _dataSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await (_rfcommConnection?.dispose() ?? _bluetoothConnection!.dispose());
  }
}
