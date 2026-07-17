/// Address display/comparison helpers for Bluetooth endpoints.
///
/// Platforms report MAC addresses in mixed shapes — Android gives
/// `0C:07:DF:F5:A0:F6`, macOS IOBluetooth gives `0c-07-df-f5-a0-f6` — while
/// BLE peripherals on Apple platforms use CoreBluetooth UUIDs instead of
/// MACs. Display MACs in one canonical form and compare them
/// case/separator-insensitively.
library;

final _nonHex = RegExp(r'[^0-9a-fA-F]');
final _macPattern = RegExp(r'^[0-9a-fA-F]{2}([:-][0-9a-fA-F]{2}){5}$');

/// Formats a MAC-like address as uppercase colon-separated pairs.
/// Identifiers that are not MACs (CoreBluetooth UUIDs, web-serial ids, …)
/// are returned unchanged.
String formatDeviceAddress(String address) {
  if (!_macPattern.hasMatch(address)) {
    return address;
  }
  final upper = address.replaceAll(_nonHex, '').toUpperCase();
  return [
    for (var i = 0; i < upper.length; i += 2) upper.substring(i, i + 2),
  ].join(':');
}

/// Compares two endpoint addresses ignoring case and separator style, so
/// `0C:07:DF:F5:A0:F6` and `0c-07-df-f5-a0-f6` count as the same device.
bool deviceAddressEquals(String a, String b) {
  return formatDeviceAddress(a).toUpperCase() ==
      formatDeviceAddress(b).toUpperCase();
}
