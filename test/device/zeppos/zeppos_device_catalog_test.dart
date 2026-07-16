import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/device_profile.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_catalog.dart';

void main() {
  test('catalog entries have unique IDs and Bluetooth names', () {
    final ids = zeppOsDeviceCatalog.map((entry) => entry.id).toList();
    final names = zeppOsDeviceCatalog
        .expand((entry) => entry.bluetoothNames)
        .map((name) => name.toLowerCase())
        .toList();

    expect(ids.toSet(), hasLength(ids.length));
    expect(names.toSet(), hasLength(names.length));
    expect(ids, everyElement(matches(RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$'))));
    expect(names, everyElement(isNotEmpty));
  });

  test('matches exact names and Gadgetbridge four-character suffixes', () {
    expect(
      zeppOsDeviceForBluetoothName('Active 2 (Round)')?.id,
      'active-2-round',
    );
    expect(
      zeppOsDeviceForBluetoothName('Active 2 (Round) A1B2')?.id,
      'active-2-round',
    );
    expect(zeppOsDeviceForBluetoothName('Amazfit GTR 4-12AF')?.id, 'gtr-4');
    expect(zeppOsDeviceForBluetoothName('Amazfit GTR 4-CALL'), isNull);
  });

  test('Mi Band 7 resolves to ZeppOS before the Xiaomi catalog', () {
    final profile = DeviceRegistry.resolveIdentity(
      name: 'Xiaomi Smart Band 7 1A2B',
    );
    expect(profile.kind, DeviceKind.zepp);
  });

  test('records Gadgetbridge BOTH connection capability', () {
    expect(
      zeppOsDeviceForBluetoothName('Active 3 Premium')?.connectionCapability,
      ZeppOsConnectionCapability.both,
    );
  });

  test('uses the configured artwork for both ZeppOS band models', () {
    expect(
      DeviceRegistry.resolveIdentity(
        name: 'Xiaomi Smart Band 7',
        codename: 'zepp:mi-band-7',
      ).illustrationAsset,
      'assets/images/devices/xiaomi-band.svg',
    );
    expect(
      DeviceRegistry.resolveIdentity(
        name: 'Amazfit Band 7',
        codename: 'zepp:band-7',
      ).illustrationAsset,
      'assets/images/devices/xiaomi-band-pro.svg',
    );
  });
}
