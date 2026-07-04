import 'package:zerobox/src/device/core/ble_requirement.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_kind.dart';

class DeviceProfile {
  const DeviceProfile({
    required this.id,
    required this.kind,
    required this.namePattern,
    required this.illustrationAsset,
    required this.preferredConnectType,
    this.bleRequiredCharacteristics = xiaomiRequiredBleCharacteristics,
    this.bleDesiredMtu = 517,
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
      bleDesiredMtu: 247,
      classicServiceUuid: '00000022-0000-3512-2118-0009af100700',
    ),
  ];

  static DeviceProfile resolve(String name) {
    for (final profile in profiles) {
      if (profile.matches(name)) return profile;
    }
    return unknown;
  }

  static DeviceProfile unknown = DeviceProfile(
    id: 'unknown',
    kind: DeviceKind.xiaomi,
    namePattern: RegExp(r'.*'),
    illustrationAsset: _xiaomiWatchAsset,
    preferredConnectType: ConnectType.ble,
  );
}
