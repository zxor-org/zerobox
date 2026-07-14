import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_device_info_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

void main() {
  test('requests and decodes Zepp OS device information', () async {
    final transport = _FakeTransport();
    final entity = DeviceEntity(
      id: 'test-device',
      kind: 'zeppos',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    entity.set(ZeppOsDeviceComponent(transport: transport));
    final system = ZeppOsDeviceInfoSystem();
    entity.registerSystem(system);

    final future = system.fetchDeviceInfo();
    expect(transport.writes.first.sublist(9, 12), [0x43, 0x00, 0x01]);

    system.handlePayload(
      Uint8List.fromList([
        0x02,
        0x01,
        0x1e,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        ...'SN123'.codeUnits,
        0,
        ...'HW1'.codeUnits,
        0,
        ...'3.2.1'.codeUnits,
        0,
        1,
        2,
        3,
        4,
        5,
        6,
        7,
      ]),
    );

    final info = await future;
    expect(info.serialNumber, 'SN123');
    expect(info.firmwareVersion, '3.2.1');
    expect(info.model, 'HW1 · PNP 01020304050607');
  });
}

class _FakeTransport implements Transport {
  final writes = <Uint8List>[];
  final _incoming = StreamController<Uint8List>.broadcast();
  final _connection = StreamController<bool>.broadcast();

  @override
  String get deviceId => 'test-device';

  @override
  String get deviceName => 'Test ZeppOS';

  @override
  Stream<Uint8List> get incomingData => _incoming.stream;

  @override
  Stream<bool> get connectionState => _connection.stream;

  @override
  Future<void> send(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> dispose() async {
    await _incoming.close();
    await _connection.close();
  }
}
