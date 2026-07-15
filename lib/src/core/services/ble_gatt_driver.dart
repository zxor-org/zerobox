import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/device/core/connect_type.dart';

export 'package:zerobox/src/device/core/ble_requirement.dart';
export 'package:zerobox/src/device/core/connect_type.dart';

class BleConnection {
  BleConnection({
    required this.deviceId,
    required this.deviceName,
    this.mtu = 23,
  });

  static final _log = getLogger('BleConnection');

  final String deviceId;
  final String deviceName;
  int mtu;
  List<BleService> services = [];
  final _connectionController = StreamController<bool>.broadcast();
  StreamSubscription<bool>? _connectionSubscription;
  StreamSubscription<Uint8List>? _valueSubscription;
  bool _disposed = false;
  Future<void> _writeTail = Future<void>.value();

  Stream<bool> get connectionState => _connectionController.stream;

  Future<void> start() async {
    _log.info('[$deviceId] starting connection state listener');
    _connectionSubscription = UniversalBle.connectionStream(deviceId).listen(
      _onConnectionStateChanged,
      onError: (Object e) =>
          _log.warning('[$deviceId] connection stream error', e),
    );
  }

  void _onConnectionStateChanged(bool connected) {
    if (_disposed) return;
    _log.info('[$deviceId] connection state changed: connected=$connected');
    _connectionController.add(connected);
  }

  BleCharacteristic? findCharacteristic(String serviceUuid, String charUuid) {
    final targetService = BleUuidParser.stringOrNull(serviceUuid);
    final targetChar = BleUuidParser.stringOrNull(charUuid);
    if (targetService == null || targetChar == null) return null;

    // Prefer the expected parent service, but do not require it. Huami devices
    // expose the ZeppOS 0x16/0x17 characteristics under FEE0 on some models,
    // while Gadgetbridge resolves characteristics globally by UUID.
    for (final service in services) {
      if (!BleUuidParser.compareStrings(service.uuid, targetService)) continue;
      for (final characteristic in service.characteristics) {
        if (BleUuidParser.compareStrings(characteristic.uuid, targetChar)) {
          return characteristic;
        }
      }
    }
    for (final service in services) {
      for (final characteristic in service.characteristics) {
        if (BleUuidParser.compareStrings(characteristic.uuid, targetChar)) {
          _log.info(
            '[$deviceId] characteristic $charUuid found under '
            '${service.uuid} instead of $serviceUuid',
          );
          return characteristic;
        }
      }
    }
    return null;
  }

  Future<void> discoverServices() async {
    _log.info('[$deviceId] discovering services');
    services = await UniversalBle.discoverServices(deviceId).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException(
        'BLE service discovery timed out',
        const Duration(seconds: 10),
      ),
    );
    _log.info('[$deviceId] discovered ${services.length} services');
    for (final service in services) {
      _log.fine(
        '[$deviceId] service ${service.uuid} with ${service.characteristics.length} characteristics',
      );
      for (final char in service.characteristics) {
        _log.fine(
          '[$deviceId]   char ${char.uuid} properties=${char.properties}',
        );
      }
    }
  }

  Future<StreamSubscription<Uint8List>> subscribe(
    String serviceUuid,
    String charUuid,
    void Function(Uint8List data) onData,
  ) async {
    final characteristic = findCharacteristic(serviceUuid, charUuid);
    if (characteristic == null) {
      _log.severe('[$deviceId] characteristic $charUuid not found');
      throw StateError('Characteristic $charUuid not found');
    }
    _log.info('[$deviceId] subscribing to $charUuid');
    await characteristic.notifications.subscribe().timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException(
        'BLE notification subscription timed out for $charUuid',
        const Duration(seconds: 8),
      ),
    );
    return characteristic.onValueReceived.listen(
      (data) {
        _log.fine('[$deviceId] received ${data.length} bytes from $charUuid');
        onData(data);
      },
      onError: (Object e) =>
          _log.warning('[$deviceId] notification stream error', e),
    );
  }

  Future<void> unsubscribe(String serviceUuid, String charUuid) async {
    final characteristic = findCharacteristic(serviceUuid, charUuid);
    if (characteristic == null) return;
    _log.info('[$deviceId] unsubscribing from $charUuid');
    await characteristic.notifications.unsubscribe().timeout(
      const Duration(seconds: 8),
      onTimeout: () => throw TimeoutException(
        'BLE notification unsubscribe timed out for $charUuid',
        const Duration(seconds: 8),
      ),
    );
  }

  Future<void> write(
    String serviceUuid,
    String charUuid,
    Uint8List data, {
    bool withResponse = false,
  }) async {
    final characteristic = findCharacteristic(serviceUuid, charUuid);
    if (characteristic == null) {
      _log.severe('[$deviceId] characteristic $charUuid not found');
      throw StateError('Characteristic $charUuid not found');
    }
    final supportsWrite = characteristic.properties.contains(
      CharacteristicProperty.write,
    );
    final supportsWriteWithoutResponse = characteristic.properties.contains(
      CharacteristicProperty.writeWithoutResponse,
    );
    final effectiveWithResponse = switch ((
      withResponse,
      supportsWrite,
      supportsWriteWithoutResponse,
    )) {
      (true, true, _) => true,
      (true, false, true) => false,
      (false, _, true) => false,
      (false, true, false) => true,
      _ => throw StateError(
        'Characteristic $charUuid does not support writing '
        '(properties: ${characteristic.properties})',
      ),
    };
    final completer = Completer<void>();
    _writeTail = _writeTail.then((_) async {
      if (_disposed) throw StateError('BLE connection is disposed');
      _log.fine(
        '[$deviceId] writing ${data.length} bytes to $charUuid '
        'withResponse=$effectiveWithResponse '
        '(requested=$withResponse, properties=${characteristic.properties})',
      );
      await characteristic
          .write(data, withResponse: effectiveWithResponse)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException(
              'BLE write timed out for $charUuid',
              const Duration(seconds: 5),
            ),
          );
    }).then(
      (_) => completer.complete(),
      onError: (Object error, StackTrace stackTrace) =>
          completer.completeError(error, stackTrace),
    );
    // Keep a failed operation from poisoning all later queued writes.
    _writeTail = _writeTail.catchError((Object _) {});
    await completer.future;
  }

  Future<int> requestMtu(int desiredMtu) async {
    try {
      _log.info('[$deviceId] requesting MTU $desiredMtu');
      mtu = await UniversalBle.requestMtu(
        deviceId,
        desiredMtu,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw TimeoutException(
          'BLE MTU negotiation timed out',
          const Duration(seconds: 5),
        ),
      );
      _log.info('[$deviceId] MTU granted: $mtu');
    } catch (e) {
      _log.warning('[$deviceId] MTU request failed, keeping $mtu', e);
    }
    return mtu;
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _log.info('[$deviceId] disposing');
    await _valueSubscription?.cancel();
    _valueSubscription = null;
    await _connectionSubscription?.cancel();
    _connectionSubscription = null;
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
    try {
      await UniversalBle.disconnect(
        deviceId,
      ).timeout(const Duration(seconds: 3));
    } on TimeoutException catch (e) {
      _log.warning('[$deviceId] disconnect timed out (ignored)', e);
    } catch (e) {
      _log.warning('[$deviceId] disconnect error', e);
    }
  }
}

class BleGattDriver {
  BleGattDriver() : _log = getLogger('BleGattDriver');

  final Logger _log;
  StreamSubscription<BleDevice>? _scanSubscription;
  final _scanController = StreamController<BluetoothEndpoint>.broadcast();
  final _scanResults = <String, BluetoothEndpoint>{};

  Stream<BluetoothEndpoint> get scanStream => _scanController.stream;

  static const String xiaomiServiceUuid = xiaomiBleServiceUuid;
  static const String xiaomiRecvCharUuid = xiaomiBleRecvCharUuid;
  static const String xiaomiSentCharUuid = xiaomiBleSentCharUuid;

  Future<bool> isAvailable() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    _log.info('bluetooth availability state: $state');
    return state == AvailabilityState.poweredOn;
  }

  Future<void> requestPermissions() async {
    _log.info('requesting bluetooth permissions');
    await UniversalBle.requestPermissions(withAndroidFineLocation: false);
  }

  Future<void> startScan({
    List<String>? withServices,
    List<String>? withNamePrefixes,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    await stopScan();
    _scanResults.clear();
    _log.info('starting BLE scan');

    _scanSubscription = UniversalBle.scanStream.listen((device) {
      final name = device.name?.trim() ?? '';
      if (withNamePrefixes != null && withNamePrefixes.isNotEmpty) {
        final matches = withNamePrefixes.any(
          (prefix) => name.toLowerCase().startsWith(prefix.toLowerCase()),
        );
        if (!matches) return;
      }
      final scanned = BluetoothEndpoint(
        name: name.isEmpty ? 'Unknown device' : name,
        address: device.deviceId,
        connectType: ConnectType.ble,
        rssi: device.rssi,
        serviceUuids: List<String>.from(device.services),
      );
      final previous = _scanResults[device.deviceId];
      final shouldLog =
          previous == null ||
          previous.name != scanned.name ||
          previous.connectType != scanned.connectType;
      if (shouldLog) {
        _log.fine(
          'scanned device: $name @ ${device.deviceId} rssi=${device.rssi}',
        );
        _log.info(
          'device_identity platform.ble_scan '
          'addr=${device.deviceId} bleName="$name" rssi=${device.rssi}',
        );
      }
      _scanResults[device.deviceId] = scanned;
      _scanController.add(scanned);
    }, onError: (Object e) => _log.warning('scan stream error', e));

    await UniversalBle.startScan(
      scanFilter: ScanFilter(withServices: withServices ?? []),
    );

    Future.delayed(timeout, stopScan);
  }

  Future<List<BluetoothEndpoint>> stopScan() async {
    _log.info('stopping BLE scan');
    final scanSubscription = _scanSubscription;
    if (scanSubscription == null) {
      return _scanResults.values.toList(growable: false);
    }
    await scanSubscription.cancel();
    _scanSubscription = null;
    try {
      final scanning = await UniversalBle.isScanning().timeout(
        const Duration(seconds: 2),
      );
      if (scanning) {
        await UniversalBle.stopScan().timeout(const Duration(seconds: 3));
      }
    } on TimeoutException catch (e) {
      _log.warning('BLE stop scan timed out; continuing connection', e);
    }
    return _scanResults.values.toList(growable: false);
  }

  Future<BleConnection> connect(
    String deviceId,
    String deviceName, {
    List<BleRequiredCharacteristic> requiredCharacteristics =
        xiaomiRequiredCharacteristics,
    int? desiredMtu = 517,
    bool attemptPair = true,
  }) async {
    await stopScan();
    _log.info('[$deviceId] initiating BLE connection');
    // Subscribe before starting the platform connection. Some backends emit
    // connected=true before UniversalBle.connect() completes; subscribing
    // afterwards loses that event and makes a healthy connection time out.
    final connection = BleConnection(
      deviceId: deviceId,
      deviceName: deviceName,
    );
    await connection.start();
    try {
      await UniversalBle.connect(deviceId).timeout(
        const Duration(seconds: 12),
        onTimeout: () {
          throw TimeoutException('UniversalBle.connect timed out');
        },
      );
    } catch (e) {
      _log.severe('[$deviceId] UniversalBle.connect failed', e);
      await connection.dispose();
      rethrow;
    }
    _log.info('[$deviceId] UniversalBle.connect returned');

    // A successful platform connect is the readiness gate. The connection
    // stream is retained for later disconnect events, but is not uniformly
    // replayed by every UniversalBle backend and must not gate initialization.
    _log.info('[$deviceId] platform connection established');

    if (attemptPair) {
      try {
        _log.info('[$deviceId] attempting pair');
        await UniversalBle.pair(deviceId).timeout(const Duration(seconds: 5));
        _log.info('[$deviceId] pair succeeded or not needed');
      } catch (e) {
        _log.warning('[$deviceId] pair failed (ignored)', e);
      }
    } else {
      _log.info('[$deviceId] skipping OS pairing for protocol-auth device');
    }

    try {
      await connection.discoverServices();
    } catch (e) {
      _log.severe('[$deviceId] service discovery failed', e);
      await connection.dispose();
      rethrow;
    }

    final missing = requiredCharacteristics.where((required) {
      return connection.findCharacteristic(
            required.serviceUuid,
            required.characteristicUuid,
          ) ==
          null;
    }).toList();
    if (missing.isNotEmpty) {
      final discovered = connection.services
          .map(
            (service) =>
                '${service.uuid}:[${service.characteristics.map((c) => c.uuid).join(',')}]',
          )
          .join('; ');
      _log.severe(
        '[$deviceId] missing BLE characteristics: '
        '${missing.map((c) => c.label ?? c.characteristicUuid).join(', ')}; '
        'discovered=$discovered',
      );
      await connection.dispose();
      throw StateError(
        'Required BLE characteristics not found for $deviceName @ $deviceId. '
        'Missing: ${missing.map((c) => c.characteristicUuid).join(', ')}. '
        'Discovered: $discovered',
      );
    }
    if (requiredCharacteristics.isNotEmpty) {
      _log.info('[$deviceId] required BLE characteristics found');
    }

    if (desiredMtu != null && desiredMtu > 23) {
      try {
        connection.mtu = await connection.requestMtu(desiredMtu);
      } catch (e) {
        _log.warning('[$deviceId] MTU request failed, keeping default', e);
      }
    }

    _log.info('[$deviceId] BLE connection ready');
    return connection;
  }

  Future<void> dispose() async {
    _log.info('disposing BleGattDriver');
    await stopScan();
    await _scanController.close();
  }

  static const xiaomiRequiredCharacteristics = xiaomiRequiredBleCharacteristics;
}
