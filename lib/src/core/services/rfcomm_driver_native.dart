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
  final _connectionController = StreamController<bool>.broadcast();
  bool _disposed = false;

  @override
  Stream<Uint8List> get incomingData => _service.incomingData;

  @override
  Stream<bool> get connectionState => _connectionController.stream;

  @override
  Future<void> start() async {
    _connectionController.add(true);
  }

  @override
  Future<void> send(Uint8List data) => _service.send(data);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _service.disconnect();
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
  }
}

class NativeRfcommDriver implements RfcommDriver {
  NativeRfcommDriver() : _log = getLogger('RfcommDriver');

  static const _method = MethodChannel('zerobox/classic_spp');
  static const _events = EventChannel('zerobox/classic_spp/events');
  static const _scanEvents = EventChannel('zerobox/classic_spp/scan_events');

  final Logger _log;
  Stream<Uint8List>? _incomingData;
  Stream<BluetoothEndpoint>? _scanData;
  final _scanResults = <String, BluetoothEndpoint>{};

  Stream<Uint8List> get incomingData {
    return _incomingData ??= _events.receiveBroadcastStream().map((event) {
      if (event is Uint8List) return event;
      if (event is List<int>) return Uint8List.fromList(event);
      throw StateError('Unexpected SPP event: ${event.runtimeType}');
    });
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
      _log.info(
        'device_identity platform.spp_scan '
        'addr=$addr sppName="$rawName" displayName="${endpoint.name}"',
      );
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
    _log.info('[$deviceId] initiating SPP connection');
    final result = await _method.invokeMapMethod<String, Object?>('connect', {
      'addr': deviceId,
      if (serviceUuid != null) 'serviceUuid': serviceUuid,
      'fallbackChannels': fallbackChannels,
    });
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
