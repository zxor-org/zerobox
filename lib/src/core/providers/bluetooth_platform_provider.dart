import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/ble_gatt_driver.dart';
import 'package:zerobox/src/core/services/rfcomm_driver.dart';
import 'package:zerobox/src/core/services/default_bluetooth_platform.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';

final _bleDriverProvider = Provider<BleGattDriver>((ref) {
  final manager = BleGattDriver();
  ref.onDispose(manager.dispose);
  return manager;
});

final _rfcommDriverProvider = Provider<RfcommDriver>((ref) {
  return createRfcommDriver();
});

final bluetoothPlatformProvider = Provider<BluetoothPlatform>((ref) {
  final platform = DefaultBluetoothPlatform(
    ref.watch(_bleDriverProvider),
    ref.watch(_rfcommDriverProvider),
  );
  ref.onDispose(platform.dispose);
  return platform;
});
