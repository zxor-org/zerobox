import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/device_profile.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_catalog.dart';

void main() {
  test('contains every Gadgetbridge ZeppOS coordinator ported in this revision', () {
    expect(zeppOsDeviceCatalog, hasLength(36));
  });

  test('matches exact names and Gadgetbridge four-character suffixes', () {
    expect(zeppOsDeviceForBluetoothName('Active 2 (Round)')?.id, 'active-2-round');
    expect(zeppOsDeviceForBluetoothName('Active 2 (Round) A1B2')?.id, 'active-2-round');
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
}
