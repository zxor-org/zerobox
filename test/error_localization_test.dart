import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/app/generated/app_localizations_en.dart';
import 'package:zerobox/src/app/generated/app_localizations_zh.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';

void main() {
  final en = AppLocalizationsEn();
  final zh = AppLocalizationsZh();

  group('localizedErrorMessage', () {
    test('maps every connection failure shape to one unified message', () {
      const shapes = [
        // BLE link-establishment timeout (daemon wrapper included).
        'Bad state: connection: Failed to connect '
            '66F65DDF-EA1A-DE29-7CBC-509EB8DE2E2D: TimeoutException after '
            '0:00:12.000000: BLE connect failed: timeout (Xiaomi Smart Band 7); '
            'the device may be occupied by another host or tool, or out of range',
        // BLE post-connect stage timeouts.
        'TimeoutException after 0:00:10.000000: '
            'BLE connect failed: service discovery timed out',
        'TimeoutException after 0:00:08.000000: '
            'BLE notification subscription timed out for 00000002-0000-3512-2118-0009af100700',
        // BLE native failure, normalized at the driver boundary.
        'Bad state: BLE connect failed: connect_failed: gatt 133',
        // SPP native failures, normalized at the driver boundary.
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'connect failed: channel 5: -536870186, channel 1: -536870186',
        'Bad state: SPP connect failed: CONNECT_FAILED: '
            'read failed, socket might closed or timeout',
      ];

      for (final raw in shapes) {
        expect(
          localizedErrorMessage(en, raw),
          en.errorBluetoothConnectFailed,
          reason: raw,
        );
        expect(
          localizedErrorMessage(zh, raw),
          zh.errorBluetoothConnectFailed,
          reason: raw,
        );
      }
    });

    test('maps BLE write timeout to the disconnected message', () {
      const raw =
          'TimeoutException after 0:00:05.000000: '
          'BLE write timed out for 00000001-0000-3512-2118-0009af100700';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothDisconnected);
    });

    test('maps missing bluetooth permission to the unavailable message', () {
      const raw =
          'PlatformException(MISSING_PERMISSION, '
          'Bluetooth permission is required, null, null)';

      expect(localizedErrorMessage(en, raw), en.errorBluetoothUnavailable);
    });

    test('does not swallow generic timeouts', () {
      const raw = 'TimeoutException after 0:00:05.000000: Future not completed';

      expect(
        localizedErrorMessage(en, raw),
        isNot(en.errorBluetoothConnectFailed),
      );
    });

    test('unified guidance covers permission, nearby, occupied, mode, retry', () {
      for (final message in [
        zh.errorBluetoothConnectFailed,
        en.errorBluetoothConnectFailed,
      ]) {
        expect(message.length, greaterThan(40));
      }
      expect(zh.errorBluetoothConnectFailed, contains('蓝牙权限'));
      expect(zh.errorBluetoothConnectFailed, contains('附近'));
      expect(zh.errorBluetoothConnectFailed, contains('占用'));
      expect(zh.errorBluetoothConnectFailed, contains('连接新手机'));
      expect(zh.errorBluetoothConnectFailed, contains('重试'));
      expect(en.errorBluetoothConnectFailed, contains('permission'));
      expect(en.errorBluetoothConnectFailed, contains('nearby'));
      expect(en.errorBluetoothConnectFailed, contains('occupied'));
      expect(en.errorBluetoothConnectFailed, contains('Connect new phone'));
      expect(en.errorBluetoothConnectFailed, contains('try again'));
    });
  });
}
