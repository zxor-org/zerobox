enum ZeppOsConnectionCapability { ble, both, btbr }

enum ZeppOsDeviceIllustration { watch, band, bandPro }

class ZeppOsDeviceCatalogEntry {
  const ZeppOsDeviceCatalogEntry({
    required this.id,
    required this.bluetoothNames,
    this.connectionCapability = ZeppOsConnectionCapability.ble,
    this.illustration = ZeppOsDeviceIllustration.watch,
  });

  final String id;
  final List<String> bluetoothNames;
  final ZeppOsConnectionCapability connectionCapability;
  final ZeppOsDeviceIllustration illustration;

  bool matches(String name) {
    final normalized = name.trim();
    for (final bluetoothName in bluetoothNames) {
      if (normalized == bluetoothName) return true;
      if (normalized.startsWith('$bluetoothName ') ||
          normalized.startsWith('$bluetoothName-')) {
        final suffix = normalized.substring(bluetoothName.length + 1);
        if (RegExp(r'^[A-F0-9]{4}$', caseSensitive: false).hasMatch(suffix)) {
          return true;
        }
      }
    }
    return false;
  }
}

/// Port of Gadgetbridge's ZeppOS coordinator Bluetooth-name registry.
const zeppOsDeviceCatalog = <ZeppOsDeviceCatalogEntry>[
  ZeppOsDeviceCatalogEntry(
    id: 'helio-ring',
    bluetoothNames: ['Amazfit Helio Ring'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'helio-strap',
    bluetoothNames: ['Amazfit Helio Strap'],
  ),
  ZeppOsDeviceCatalogEntry(id: 'active', bluetoothNames: ['Amazfit Active']),
  ZeppOsDeviceCatalogEntry(
    id: 'active-edge',
    bluetoothNames: ['Amazfit Active Edge'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'active-max',
    bluetoothNames: ['Amazfit Active Max', 'Active Max'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'active-2-nfc-round',
    bluetoothNames: ['Active 2 NFC (Round)'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'active-2-round',
    bluetoothNames: ['Active 2 (Round)'],
    connectionCapability: ZeppOsConnectionCapability.both,
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'active-2-square',
    bluetoothNames: [
      'Active 2 (Square)',
      'Active 2 NFC (Square)',
      'Active 2 Square',
      'Active 2 NFC Square',
    ],
    connectionCapability: ZeppOsConnectionCapability.both,
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'active-3-premium',
    bluetoothNames: ['Amazfit Active 3 Premium', 'Active 3 Premium'],
    connectionCapability: ZeppOsConnectionCapability.both,
  ),
  ZeppOsDeviceCatalogEntry(id: 'balance', bluetoothNames: ['Amazfit Balance']),
  ZeppOsDeviceCatalogEntry(
    id: 'balance-2',
    bluetoothNames: ['Amazfit Balance 2'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'balance-2-xt',
    bluetoothNames: ['Amazfit Balance 2 XT'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'band-7',
    bluetoothNames: ['Amazfit Band 7'],
    illustration: ZeppOsDeviceIllustration.bandPro,
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'mi-band-7',
    bluetoothNames: ['Xiaomi Smart Band 7'],
    illustration: ZeppOsDeviceIllustration.band,
  ),
  ZeppOsDeviceCatalogEntry(id: 'bip-5', bluetoothNames: ['Amazfit Bip 5']),
  ZeppOsDeviceCatalogEntry(
    id: 'bip-5-unity',
    bluetoothNames: ['Amazfit Bip 5 Unity'],
  ),
  ZeppOsDeviceCatalogEntry(id: 'bip-6', bluetoothNames: ['Amazfit Bip 6']),
  ZeppOsDeviceCatalogEntry(
    id: 'cheetah-pro',
    bluetoothNames: ['Amazfit Cheetah Pro'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'cheetah-round',
    bluetoothNames: ['Amazfit Cheetah R'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'cheetah-square',
    bluetoothNames: ['Amazfit Cheetah S'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'cheetah-2-pro',
    bluetoothNames: ['Amazfit Cheetah 2 Pro', 'Cheetah 2 Pro'],
    connectionCapability: ZeppOsConnectionCapability.both,
  ),
  ZeppOsDeviceCatalogEntry(id: 'falcon', bluetoothNames: ['Amazfit Falcon']),
  ZeppOsDeviceCatalogEntry(id: 'gtr-3', bluetoothNames: ['Amazfit GTR 3']),
  ZeppOsDeviceCatalogEntry(
    id: 'gtr-3-pro',
    bluetoothNames: ['Amazfit GTR 3 Pro'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'gtr-4',
    bluetoothNames: ['Amazfit GTR 4', 'Amazfit GTR 4 LE'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'gtr-mini',
    bluetoothNames: ['Amazfit GTR Mini'],
  ),
  ZeppOsDeviceCatalogEntry(id: 'gts-3', bluetoothNames: ['Amazfit GTS 3']),
  ZeppOsDeviceCatalogEntry(id: 'gts-4', bluetoothNames: ['Amazfit GTS 4']),
  ZeppOsDeviceCatalogEntry(
    id: 'gts-4-mini',
    bluetoothNames: ['Amazfit GTS 4 Mini'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'gts-4-mini-new',
    bluetoothNames: ['Amazfit GTS 4 mini New'],
  ),
  ZeppOsDeviceCatalogEntry(id: 'trex-2', bluetoothNames: ['Amazfit T-Rex 2']),
  ZeppOsDeviceCatalogEntry(id: 'trex-3', bluetoothNames: ['Amazfit T-Rex 3']),
  ZeppOsDeviceCatalogEntry(
    id: 'trex-3-pro-44',
    bluetoothNames: ['T-Rex 3 Pro (44mm)'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'trex-3-pro-48',
    bluetoothNames: ['T-Rex 3 Pro (48mm)'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'trex-ultra',
    bluetoothNames: ['Amazfit T-Rex Ultra'],
  ),
  ZeppOsDeviceCatalogEntry(
    id: 'trex-ultra-2',
    bluetoothNames: ['Amazfit T-Rex Ultra 2', 'T-Rex Ultra 2'],
  ),
];

ZeppOsDeviceCatalogEntry? zeppOsDeviceForBluetoothName(String name) {
  for (final entry in zeppOsDeviceCatalog) {
    if (entry.matches(name)) return entry;
  }
  return null;
}
