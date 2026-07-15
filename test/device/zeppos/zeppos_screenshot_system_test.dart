import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_screenshot_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

void main() {
  test(
    'rejects a concurrent request while service negotiation is running',
    () async {
      final fixture = _fixture();
      final first = fixture.screenshot.requestScreenshot();
      final second = fixture.screenshot.requestScreenshot();

      Object? rejection;
      try {
        await second.timeout(const Duration(milliseconds: 50));
      } catch (error) {
        rejection = error;
      }
      expect(rejection, isA<StateError>());

      fixture.services.handlePayload(Uint8List.fromList(const [0x04, 0, 0]));
      await expectLater(first, throwsUnsupportedError);
      await fixture.entity.dispose();
    },
  );

  test(
    'reassembles a Zepp OS v2 screenshot and validates its checksum',
    () async {
      final fixture = _fixture();
      final screenshot = fixture.screenshot.requestScreenshot();
      await _advertiseV2(fixture);

      final bytes = Uint8List.fromList(const [1, 2, 3, 4, 5]);
      fixture.screenshot.handlePayload(
        ZeppOsScreenshotSystem.fileTransferEndpoint,
        _fileRequest(bytes),
      );
      await _flush();
      fixture.screenshot.handlePayload(
        ZeppOsScreenshotSystem.fileTransferEndpoint,
        Uint8List.fromList([0x10, 0, 7, 0, 3, 0, ...bytes.sublist(0, 3)]),
      );
      fixture.screenshot.handlePayload(
        ZeppOsScreenshotSystem.fileTransferEndpoint,
        Uint8List.fromList([0x10, 2, 7, 1, 2, 0, ...bytes.sublist(3)]),
      );

      expect(await screenshot, bytes);
      expect(fixture.transport.writes, isNotEmpty);
      await fixture.entity.dispose();
    },
  );

  test('rejects a screenshot transfer with an unexpected file name', () async {
    final fixture = _fixture();
    final screenshot = fixture.screenshot.requestScreenshot();
    await _advertiseV2(fixture);

    fixture.screenshot.handlePayload(
      ZeppOsScreenshotSystem.fileTransferEndpoint,
      _fileRequest(Uint8List.fromList(const [1]), filename: 'notes.txt'),
    );

    await expectLater(screenshot, throwsFormatException);
    await fixture.entity.dispose();
  });

  test('rejects screenshot bytes whose checksum does not match', () async {
    final fixture = _fixture();
    final screenshot = fixture.screenshot.requestScreenshot();
    await _advertiseV2(fixture);
    final declared = Uint8List.fromList(const [1, 2]);

    fixture.screenshot.handlePayload(
      ZeppOsScreenshotSystem.fileTransferEndpoint,
      _fileRequest(declared),
    );
    await _flush();
    fixture.screenshot.handlePayload(
      ZeppOsScreenshotSystem.fileTransferEndpoint,
      Uint8List.fromList(const [0x10, 2, 7, 0, 2, 0, 9, 9]),
    );

    await expectLater(screenshot, throwsFormatException);
    await fixture.entity.dispose();
  });
}

({
  DeviceEntity entity,
  ZeppOsScreenshotSystem screenshot,
  ZeppOsServicesSystem services,
  _FakeTransport transport,
})
_fixture() {
  final transport = _FakeTransport();
  final entity = DeviceEntity(
    id: 'test-device',
    kind: 'zeppos',
    transport: transport,
    eventBus: DeviceEventBus(),
  );
  entity.set(ZeppOsDeviceComponent(transport: transport));
  final services = ZeppOsServicesSystem();
  final screenshot = ZeppOsScreenshotSystem();
  entity.registerSystem(services);
  entity.registerSystem(screenshot);
  return (
    entity: entity,
    screenshot: screenshot,
    services: services,
    transport: transport,
  );
}

Future<void> _advertiseV2(
  ({
    DeviceEntity entity,
    ZeppOsScreenshotSystem screenshot,
    ZeppOsServicesSystem services,
    _FakeTransport transport,
  })
  fixture,
) async {
  await _flush();
  fixture.services.handlePayload(
    Uint8List.fromList(const [0x04, 2, 0, 0xa0, 0, 0, 0x0d, 0, 0]),
  );
  await _flush();
  fixture.screenshot.handlePayload(
    ZeppOsScreenshotSystem.fileTransferEndpoint,
    Uint8List.fromList(const [0x02, 2, 0, 0]),
  );
  await _flush();
}

Uint8List _fileRequest(
  Uint8List screenshot, {
  String filename = 'screenshot-test.png',
}) {
  final prefix = <int>[0x03, 7, ...'file://screenshot'.codeUnits, 0];
  final name = <int>[...filename.codeUnits, 0];
  final payload = Uint8List(prefix.length + name.length + 9)
    ..setRange(0, prefix.length, prefix)
    ..setRange(prefix.length, prefix.length + name.length, name);
  final offset = prefix.length + name.length;
  final view = ByteData.sublistView(payload);
  view.setUint32(offset, screenshot.length, Endian.little);
  view.setUint32(offset + 4, _crc32(screenshot), Endian.little);
  payload[offset + 8] = 0;
  return payload;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

class _FakeTransport implements Transport {
  final writes = <Uint8List>[];

  @override
  String get deviceId => 'test-device';
  @override
  String get deviceName => 'Test ZeppOS';
  @override
  Stream<Uint8List> get incomingData => const Stream.empty();
  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {
    writes.add(Uint8List.fromList(data));
  }

  @override
  Future<void> dispose() async {}
}
