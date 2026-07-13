import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_catalog.dart';

class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.kind,
    required this.namePattern,
    required this.illustrationAsset,
    required this.preferredConnectType,
    this.bleRequiredCharacteristics = xiaomiRequiredBleCharacteristics,
    this.bleDesiredMtu = 517,
    this.bleAttemptPair = true,
    this.classicServiceUuid,
    this.classicFallbackChannels = const [5, 1],
  });

  final String id;
  final DeviceKind kind;
  final RegExp namePattern;
  final String illustrationAsset;
  final ConnectType preferredConnectType;
  final List<BleRequiredCharacteristic> bleRequiredCharacteristics;
  final int? bleDesiredMtu;
  final bool bleAttemptPair;
  final String? classicServiceUuid;
  final List<int> classicFallbackChannels;

  bool matches(String name) => namePattern.hasMatch(name);
}

class DeviceRegistry {
  const DeviceRegistry._();

  static const _xiaomiWatchAsset = 'assets/images/devices/xiaomi-watch.svg';

  static final List<DeviceProfile> profiles = [
    DeviceProfile(
      id: 'redmi-band',
      kind: DeviceKind.xiaomi,
      namePattern: RegExp(r'Redmi Band \w', caseSensitive: false),
      illustrationAsset: 'assets/images/devices/redmi-band.svg',
      preferredConnectType: ConnectType.spp,
    ),
    DeviceProfile(
      id: 'redmi-watch',
      kind: DeviceKind.xiaomi,
      namePattern: RegExp(r'Redmi Watch \w', caseSensitive: false),
      illustrationAsset: 'assets/images/devices/redmi-watch.svg',
      preferredConnectType: ConnectType.spp,
    ),
    DeviceProfile(
      id: 'xiaomi-band-pro',
      kind: DeviceKind.xiaomi,
      namePattern: RegExp(
        r'Xiaomi Smart Band \w\w? Pro .{4}|小米手环\w\w? Pro',
        caseSensitive: false,
      ),
      illustrationAsset: 'assets/images/devices/xiaomi-band-pro.svg',
      preferredConnectType: ConnectType.spp,
    ),
    DeviceProfile(
      id: 'xiaomi-band',
      kind: DeviceKind.xiaomi,
      namePattern: RegExp(
        r'Xiaomi Smart Band \w\w? ?\S{4}?|小米手环\w\w?',
        caseSensitive: false,
      ),
      illustrationAsset: 'assets/images/devices/xiaomi-band.svg',
      preferredConnectType: ConnectType.spp,
    ),
    DeviceProfile(
      id: 'xiaomi-watch-s',
      kind: DeviceKind.xiaomi,
      namePattern: RegExp(
        r'Xiaomi Watch S\w (eSIM )?\S{4}',
        caseSensitive: false,
      ),
      illustrationAsset: _xiaomiWatchAsset,
      preferredConnectType: ConnectType.spp,
    ),
    DeviceProfile(
      id: 'zeppos',
      kind: DeviceKind.zepp,
      namePattern: RegExp(
        r'(Amazfit|Zepp|Mi Band 7|Amazfit Band 7|Amazfit GTR|Amazfit GTS|Amazfit T-Rex|Amazfit Balance|Amazfit Active|Amazfit Cheetah|Amazfit Bip)',
        caseSensitive: false,
      ),
      illustrationAsset: _xiaomiWatchAsset,
      preferredConnectType: ConnectType.ble,
      bleRequiredCharacteristics: [
        BleRequiredCharacteristic(
          serviceUuid: '00001530-0000-3512-2118-0009af100700',
          characteristicUuid: '00000017-0000-3512-2118-0009af100700',
          label: 'zeppos chunked 2021 read',
        ),
        BleRequiredCharacteristic(
          serviceUuid: '00001530-0000-3512-2118-0009af100700',
          characteristicUuid: '00000016-0000-3512-2118-0009af100700',
          label: 'zeppos chunked 2021 write',
        ),
      ],
      // Gadgetbridge starts the protocol encoder at MTU 23; it does not ask
      // the operating system to negotiate MTU 23 before authentication.
      bleDesiredMtu: null,
      // ZeppOS performs its own endpoint 0x0082 authkey handshake. A system
      // bond is not a prerequisite and can leave UniversalBle.pair hanging.
      bleAttemptPair: false,
      classicServiceUuid: '00000022-0000-3512-2118-0009af100700',
    ),
  ];

  static DeviceProfile resolve(String name) {
    for (final profile in profiles) {
      if (profile.matches(name)) return profile;
    }
    return unknown;
  }

  static DeviceProfile resolveIdentity({
    required String name,
    String? codename,
  }) {
    if (codename?.startsWith('zepp:') == true) {
      return _profileById('zeppos');
    }
    // Some ZeppOS devices use Xiaomi/Mi product names (notably Mi Band 7).
    // The Xiaomi wearable catalog also recognizes those names, so consulting
    // it first incorrectly routes a ZeppOS device into the Xiaomi/Vela session.
    // Explicit ZeppOS model matching must take precedence.
    final zeppDevice = zeppOsDeviceForBluetoothName(name);
    if (zeppDevice != null) {
      return _profileById('zeppos');
    }

    final directProfile = resolve(name);

    final identity =
        xiaomiWearableIdentityForCodename(codename) ??
        normalizeXiaomiWearableIdentity(name);
    if (identity != null) {
      return _resolveFamily(identity.family);
    }

    return directProfile;
  }

  static DeviceProfile _resolveFamily(XiaomiWearableFamily family) {
    return switch (family) {
      XiaomiWearableFamily.band => _profileById('xiaomi-band'),
      XiaomiWearableFamily.bandPro => _profileById('xiaomi-band-pro'),
      XiaomiWearableFamily.redmiWatch => _profileById('redmi-watch'),
      XiaomiWearableFamily.xiaomiWatch => _profileById('xiaomi-watch-s'),
      XiaomiWearableFamily.unknown => unknown,
    };
  }

  static DeviceProfile _profileById(String id) {
    return profiles.firstWhere((profile) => profile.id == id);
  }

  static DeviceProfile unknown = DeviceProfile(
    id: 'unknown',
    kind: DeviceKind.xiaomi,
    namePattern: RegExp(r'.*'),
    illustrationAsset: _xiaomiWatchAsset,
    preferredConnectType: ConnectType.ble,
    // Unknown BLE devices must be connected far enough to discover services;
    // their protocol is selected from actual characteristics afterwards.
    bleRequiredCharacteristics: const [],
  );
}
