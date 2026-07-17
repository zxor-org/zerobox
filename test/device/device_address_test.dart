import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/devices/utils/device_address.dart';

void main() {
  group('formatDeviceAddress', () {
    test('canonicalizes dash-separated lowercase macs', () {
      expect(
        formatDeviceAddress('0c-07-df-f5-a0-f6'),
        '0C:07:DF:F5:A0:F6',
      );
    });

    test('keeps canonical macs unchanged', () {
      expect(
        formatDeviceAddress('0C:07:DF:F5:A0:F6'),
        '0C:07:DF:F5:A0:F6',
      );
    });

    test('normalizes mixed separators and case', () {
      expect(
        formatDeviceAddress('d4-17-61-14-18-6e'),
        'D4:17:61:14:18:6E',
      );
    });

    test('passes CoreBluetooth UUIDs through', () {
      const uuid = '66F65DDF-EA1A-DE29-7CBC-509EB8DE2E2D';
      expect(formatDeviceAddress(uuid), uuid);
    });

    test('passes non-mac identifiers through', () {
      expect(formatDeviceAddress('web-serial:a1b2c3d4'), 'web-serial:a1b2c3d4');
      expect(formatDeviceAddress('serial:SN12345'), 'serial:SN12345');
    });
  });

  group('deviceAddressEquals', () {
    test('matches macs across case and separators', () {
      expect(
        deviceAddressEquals('0C:07:DF:F5:A0:F6', '0c-07-df-f5-a0-f6'),
        isTrue,
      );
    });

    test('matches uuids case-insensitively', () {
      expect(
        deviceAddressEquals(
          '66F65DDF-EA1A-DE29-7CBC-509EB8DE2E2D',
          '66f65ddf-ea1a-de29-7cbc-509eb8de2e2d',
        ),
        isTrue,
      );
    });

    test('rejects different addresses', () {
      expect(
        deviceAddressEquals('0C:07:DF:F5:A0:F6', 'D0:AE:05:2C:D5:80'),
        isFalse,
      );
    });
  });
}
