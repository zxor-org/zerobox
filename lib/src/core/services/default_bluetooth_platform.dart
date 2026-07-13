import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/ble_gatt_driver.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';

class DefaultBluetoothPlatform implements BluetoothPlatform {
  DefaultBluetoothPlatform(this._ble, this._rfcomm)
    : _log = getLogger('BluetoothPlatform') {
    _bleSubscription = _ble.scanStream.listen(
      _onEndpoint,
      onError: _scanController.addError,
    );
    _sppSubscription = _rfcomm.scanStream.listen(
      _onEndpoint,
      onError: _scanController.addError,
    );
  }

  final BleGattDriver _ble;
  final RfcommDriver _rfcomm;
  final Logger _log;
  final _scanController = StreamController<BluetoothEndpoint>.broadcast();
  final _scanResults = <String, BluetoothEndpoint>{};
  var _activeScanTypes = <ConnectType>{};
  StreamSubscription<BluetoothEndpoint>? _bleSubscription;
  StreamSubscription<BluetoothEndpoint>? _sppSubscription;
  BluetoothConnection? _connection;

  @override
  Stream<BluetoothEndpoint> get scanStream => _scanController.stream;

  @override
  Future<bool> isAvailable() => _ble.isAvailable();

  @override
  Future<void> requestPermissions() async {
    await _ble.requestPermissions();
    try {
      await _rfcomm.requestPermissions();
    } catch (e) {
      _log.fine('SPP permission request ignored: $e');
    }
  }

  @override
  Future<void> startScan(BluetoothScanOptions options) async {
    await stopScan();
    _scanResults.clear();

    final connectTypes = options.normalizedConnectTypes;
    _activeScanTypes = connectTypes;

    if (connectTypes.contains(ConnectType.ble)) {
      await _ble.startScan(
        withServices: options.serviceUuids,
        withNamePrefixes: options.namePrefixes,
        timeout: options.timeout,
      );
    }

    if (connectTypes.contains(ConnectType.spp)) {
      try {
        await _rfcomm.startScan(timeout: options.timeout);
      } catch (e) {
        _log.warning('RFCOMM scan failed to start', e);
        if (!connectTypes.contains(ConnectType.ble)) rethrow;
      }
    }
  }

  @override
  Future<List<BluetoothEndpoint>> stopScan() async {
    final stopTypes = _activeScanTypes;
    _activeScanTypes = {};

    // An empty set means scanning is already stopped. Previously it meant
    // "stop every backend again", so connect() could block forever waiting on
    // an inactive native RFCOMM MethodChannel after the UI had already stopped
    // the scan.
    if (stopTypes.isEmpty) {
      return _scanResults.values.toList(growable: false);
    }

    if (stopTypes.contains(ConnectType.ble)) {
      for (final endpoint in await _ble.stopScan()) {
        _rememberEndpoint(endpoint);
      }
    }
    if (stopTypes.contains(ConnectType.spp)) {
      for (final endpoint in await _stopRfcommScanBestEffort()) {
        _rememberEndpoint(endpoint);
      }
    }
    return _scanResults.values.toList(growable: false);
  }

  Future<List<BluetoothEndpoint>> _stopRfcommScanBestEffort() async {
    try {
      return await _rfcomm.stopScan();
    } catch (e) {
      _log.fine('RFCOMM stop scan ignored: $e');
      return const [];
    }
  }

  void _onEndpoint(BluetoothEndpoint endpoint) {
    final key = _endpointKey(endpoint);
    if (_scanResults.containsKey(key)) return;
    _scanResults[key] = endpoint;
    _scanController.add(endpoint);
  }

  void _rememberEndpoint(BluetoothEndpoint endpoint) {
    _scanResults[_endpointKey(endpoint)] = endpoint;
  }

  String _endpointKey(BluetoothEndpoint endpoint) =>
      '${endpoint.connectType.name}:${endpoint.address}';

  @override
  Future<BluetoothConnection> connect(
    String address,
    String name,
    BluetoothConnectOptions options,
  ) async {
    await stopScan();
    await disconnect();
    _log.info('connecting to $name @ $address via ${options.connectType.name}');

    final BluetoothConnection connection;
    switch (options.connectType) {
      case ConnectType.ble:
        final bleConnection = await _ble.connect(
          address,
          name,
          requiredCharacteristics: options.bleRequiredCharacteristics,
          desiredMtu: options.bleDesiredMtu,
          attemptPair: options.bleAttemptPair,
        );
        connection = _BleBluetoothConnection(bleConnection);
      case ConnectType.spp:
        final sppConnection = await _rfcomm.connect(
          address,
          name,
          serviceUuid: options.sppServiceUuid,
          fallbackChannels: options.sppFallbackChannels,
        );
        connection = _SppBluetoothConnection(sppConnection);
    }
    _connection = connection;
    return connection;
  }

  @override
  Future<void> disconnect() async {
    final connection = _connection;
    _connection = null;
    if (connection != null) {
      await connection.dispose();
    }
  }

  Future<void> dispose() async {
    await _bleSubscription?.cancel();
    await _sppSubscription?.cancel();
    await disconnect();
    await _scanController.close();
  }
}

class _BleBluetoothConnection implements BluetoothConnection {
  _BleBluetoothConnection(this._connection);

  final BleConnection _connection;
  final _incomingController = StreamController<Uint8List>.broadcast();
  StreamSubscription<Uint8List>? _incomingSubscription;

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  ConnectType get connectType => ConnectType.ble;

  @override
  Stream<Uint8List> get incomingData => _incomingController.stream;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  @override
  int? get maxWriteLength => _connection.mtu - 3;

  @override
  bool supportsCharacteristic(BleRequiredCharacteristic characteristic) =>
      _connection.findCharacteristic(
        characteristic.serviceUuid,
        characteristic.characteristicUuid,
      ) !=
      null;

  @override
  Future<void> send(
    Uint8List data, {
    BleRequiredCharacteristic? characteristic,
  }) {
    final target = characteristic ?? xiaomiRequiredBleCharacteristics.last;
    return _connection.write(
      target.serviceUuid,
      target.characteristicUuid,
      data,
    );
  }

  @override
  Future<void> subscribe({
    BleRequiredCharacteristic? characteristic,
    void Function(Uint8List data)? onData,
  }) async {
    final target = characteristic ?? xiaomiRequiredBleCharacteristics.first;
    await _incomingSubscription?.cancel();
    _incomingSubscription = await _connection.subscribe(
      target.serviceUuid,
      target.characteristicUuid,
      (data) {
        _incomingController.add(data);
        onData?.call(data);
      },
    );
  }

  @override
  Future<void> dispose() async {
    await _incomingSubscription?.cancel();
    if (!_incomingController.isClosed) {
      await _incomingController.close();
    }
    await _connection.dispose();
  }
}

class _SppBluetoothConnection implements BluetoothConnection {
  _SppBluetoothConnection(this._connection);

  final RfcommConnection _connection;
  StreamSubscription<Uint8List>? _incomingSubscription;

  @override
  String get deviceId => _connection.deviceId;

  @override
  String get deviceName => _connection.deviceName;

  @override
  ConnectType get connectType => ConnectType.spp;

  @override
  Stream<Uint8List> get incomingData => _connection.incomingData;

  @override
  Stream<bool> get connectionState => _connection.connectionState;

  @override
  int? get maxWriteLength => null;

  @override
  bool supportsCharacteristic(BleRequiredCharacteristic characteristic) =>
      false;

  @override
  Future<void> send(
    Uint8List data, {
    BleRequiredCharacteristic? characteristic,
  }) {
    return _connection.send(data);
  }

  @override
  Future<void> subscribe({
    BleRequiredCharacteristic? characteristic,
    void Function(Uint8List data)? onData,
  }) async {
    await _incomingSubscription?.cancel();
    if (onData != null) {
      _incomingSubscription = _connection.incomingData.listen(onData);
    }
  }

  @override
  Future<void> dispose() async {
    await _incomingSubscription?.cancel();
    await _connection.dispose();
  }
}
