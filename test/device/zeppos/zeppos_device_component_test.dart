import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

void main() {
  test('outbound authentication payload uses extended 2021 chunks', () async {
    final transport = _FakeTransport();
    final component = ZeppOsDeviceComponent(transport: transport);

    await component.sendToEndpoint(
      ZeppOsDeviceComponent.endpointAuthentication,
      Uint8List.fromList(List<int>.generate(12, (index) => index)),
    );

    expect(transport.writes, hasLength(2));
    expect(transport.writes.first.sublist(0, 11), [
      0x03, 0x01, 0x00, 0x01, 0x00,
      0x0c, 0x00, 0x00, 0x00, 0x82, 0x00,
    ]);
    expect(transport.writes.last.sublist(0, 5), [
      0x03, 0x06, 0x00, 0x01, 0x01,
    ]);
  });

  test('rejects continuation chunks without a first chunk', () {
    final component = ZeppOsDeviceComponent(transport: _FakeTransport());
    expect(
      () => component.handleIncoming(
        Uint8List.fromList([0x03, 0x02, 0x00, 0x01, 0x01]),
      ),
      throwsStateError,
    );
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
