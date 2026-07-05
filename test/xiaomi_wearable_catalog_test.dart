import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';

void main() {
  group('Xiaomi wearable identity normalization', () {
    test('normalizes AB v2 id, upstream model, hardware model and names', () {
      final inputs = [
        'xmb9p',
        'miwear.watch.n67cn',
        'M2401B1',
        'n67',
        'N67',
        '小米手环9 Pro',
        'Xiaomi Smart Band 9 Pro',
      ];

      for (final input in inputs) {
        final identity = normalizeXiaomiWearableIdentity(input);
        expect(identity?.codename, 'n67', reason: input);
        expect(identity?.displayName, 'Xiaomi Smart Band 9 Pro');
      }
    });

    test('normalizes REDMI Watch 5 eSIM aliases', () {
      final inputs = [
        'xmrw5xring',
        'miwear.watch.o65m',
        'M2428W1',
        'o65m',
        'REDMI Watch 5 eSIM',
        '红米手表5 eSIM',
      ];

      for (final input in inputs) {
        final identity = normalizeXiaomiWearableIdentity(input);
        expect(identity?.codename, 'o65m', reason: input);
        expect(identity?.displayName, 'REDMI Watch 5 eSIM');
      }
    });
  });
}
