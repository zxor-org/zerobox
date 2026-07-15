import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_app_install_system.dart';

void main() {
  test('runs the Gadgetbridge Zepp OS firmware transfer sequence', () async {
    final transport = _FakeCharacteristicTransport(totalBytes: 10);
    final entity = DeviceEntity(
      id: 'test',
      kind: 'zeppos',
      transport: transport,
      eventBus: DeviceEventBus(),
    );
    final system = ZeppOsAppInstallSystem();
    entity.registerSystem(system);
    final progress = <double>[];

    await system.install(
      ZeppOsInstallPackage(
        type: ZeppOsPackageType.app,
        bytes: Uint8List.fromList(List.generate(10, (index) => index)),
        crc32: 0x12345678,
      ),
      onProgress: progress.add,
    );

    expect(transport.controlWrites.map((value) => value[0]), [
      0xd0,
      0xd2,
      0xd3,
      0xd5,
      0xd6,
    ]);
    final info = transport.controlWrites[1];
    expect(info[1], 0x08);
    expect(ByteData.sublistView(info, 2, 6).getUint32(0, Endian.little), 10);
    expect(
      ByteData.sublistView(info, 6, 10).getUint32(0, Endian.little),
      0x12345678,
    );
    expect(
      transport.dataWrites.expand((value) => value),
      List.generate(10, (index) => index),
    );
    expect(transport.dataWriteModes, everyElement(isFalse));
    expect(progress.last, 1);
  });
}

class _FakeCharacteristicTransport implements CharacteristicTransport {
  _FakeCharacteristicTransport({required this.totalBytes});

  final int totalBytes;
  final controlWrites = <Uint8List>[];
  final dataWrites = <Uint8List>[];
  final dataWriteModes = <bool>[];
  void Function(Uint8List)? _notify;
  int _received = 0;

  @override
  int get maxWriteLength => 4;
  @override
  String get deviceId => 'test';
  @override
  String get deviceName => 'test';
  @override
  Stream<Uint8List> get incomingData => const Stream.empty();
  @override
  Stream<bool> get connectionState => const Stream.empty();

  @override
  Future<void> send(Uint8List data) async {}

  @override
  Future<void> sendToCharacteristic(
    Uint8List data,
    BleRequiredCharacteristic characteristic, {
    bool withResponse = false,
  }) async {
    if (characteristic.characteristicUuid.contains('1531')) {
      controlWrites.add(Uint8List.fromList(data));
      final command = data[0];
      scheduleMicrotask(() {
        _notify?.call(
          Uint8List.fromList(
            command == 0xd0 ? [0x10, command, 1, 0, 8, 0] : [0x10, command, 1],
          ),
        );
      });
      return;
    }
    dataWrites.add(Uint8List.fromList(data));
    dataWriteModes.add(withResponse);
    _received += data.length;
    if (_received == 8 || _received == totalBytes) {
      final offset = _received;
      scheduleMicrotask(
        () => _notify?.call(
          Uint8List.fromList([
            0x10,
            0xd4,
            offset & 0xff,
            (offset >> 8) & 0xff,
            (offset >> 16) & 0xff,
            (offset >> 24) & 0xff,
          ]),
        ),
      );
    }
  }

  @override
  Future<StreamSubscription<Uint8List>?> subscribeToCharacteristic(
    BleRequiredCharacteristic characteristic,
    void Function(Uint8List data) onData,
  ) async {
    _notify = onData;
    return null;
  }

  @override
  Future<void> dispose() async {}
}
