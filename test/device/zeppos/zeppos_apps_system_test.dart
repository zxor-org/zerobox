import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_apps_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

void main() {
  test(
    'requests and parses the Gadgetbridge Zepp OS app list format',
    () async {
      final fixture = _fixture();
      final future = fixture.system.fetchApps();

      expect(_payload(fixture.transport.writes).sublist(0, 3), [
        0x02,
        0x01,
        0x01,
      ]);

      final response = Uint8List.fromList([
        0x02,
        0x00,
        0x01,
        ...List<int>.filled(13, 0),
        ...'1a2b3c4d-2.3.4;0000002a-1.0;'.codeUnits,
        0,
      ]);
      fixture.system.handlePayload(response);

      final apps = await future;
      expect(apps, hasLength(2));
      expect(apps.first.packageName, '0x1A2B3C4D');
      expect(apps.first.versionCode, 2003004);
      expect(apps.last.packageName, '0x0000002A');
      expect(apps.every((app) => app.canRemove), isTrue);
    },
  );

  test('encodes app uninstall through the apps endpoint', () async {
    final fixture = _fixture();

    await fixture.system.uninstallApp('0000002a');

    expect(_endpoint(fixture.transport.writes), ZeppOsAppsSystem.endpoint);
    final payload = _payload(fixture.transport.writes);
    expect(payload.sublist(0, 3), [0x02, 0x01, 0x03]);
    expect(payload.sublist(16, 20), [0x2a, 0x00, 0x00, 0x00]);
  });

  test('encodes app launch through the watchface endpoint', () async {
    final fixture = _fixture();
    fixture.system.launchEncrypted = false;

    await fixture.system.launchApp('0000002a');

    expect(
      _endpoint(fixture.transport.writes),
      ZeppOsAppsSystem.launchEndpoint,
    );
    expect(_payload(fixture.transport.writes), [0x07, 0x2a, 0, 0, 0]);
  });
}

({ZeppOsAppsSystem system, _FakeTransport transport}) _fixture() {
  final transport = _FakeTransport();
  final entity = DeviceEntity(
    id: 'test-device',
    kind: 'zeppos',
    transport: transport,
    eventBus: DeviceEventBus(),
  );
  entity.set(ZeppOsDeviceComponent(transport: transport));
  final system = ZeppOsAppsSystem();
  entity.registerSystem(system);
  return (system: system, transport: transport);
}

int _endpoint(List<Uint8List> chunks) =>
    chunks.first[9] | (chunks.first[10] << 8);

Uint8List _payload(List<Uint8List> chunks) {
  final bytes = BytesBuilder(copy: false);
  for (var index = 0; index < chunks.length; index += 1) {
    bytes.add(chunks[index].sublist(index == 0 ? 11 : 5));
  }
  return bytes.takeBytes();
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
