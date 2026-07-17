import 'package:flutter/services.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

String localizedErrorMessage(AppLocalizations l10n, Object? error) {
  final raw = _flattenError(error);
  final normalized = raw.toLowerCase();

  if (raw == DeviceManager.errorBluetoothUnavailable ||
      normalized.contains('bluetooth is not available') ||
      normalized.contains('bluetooth not available') ||
      normalized.contains('availabilitystate.unsupported')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('web serial api is not available')) {
    return l10n.errorWebSerialUnavailable;
  }

  if (normalized.contains('certificate_verify_failed') ||
      normalized.contains('self signed certificate') ||
      normalized.contains('handshakeexception') ||
      normalized.contains('certificate verify failed')) {
    return l10n.errorCertificateVerificationFailed;
  }

  if (normalized.contains('ble connect failed: timeout') ||
      normalized.contains('ble connect failed: service discovery timed out') ||
      normalized.contains('ble notification subscription timed out')) {
    // All connection-failure causes (timeout or refused) share one message:
    // permissions, radio off, device occupied, or wrong device mode.
    return l10n.errorBluetoothConnectFailed;
  }

  // The BLE and SPP drivers normalize native failures into these stable
  // shapes at the Dart boundary; match the shape, not native wording.
  if (normalized.contains('ble connect failed') ||
      normalized.contains('spp connect failed')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('ble write timed out')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('bluetooth permission is required')) {
    return l10n.errorBluetoothUnavailable;
  }

  if (normalized.contains('timeout') ||
      normalized.contains('timed out') ||
      normalized.contains('future not completed') ||
      normalized.contains('操作超时')) {
    // Preserve the connection stage carried by the error instead of reducing
    // every failure to the same unactionable timeout message.
    final detail = _trimPlatformNoise(raw);
    return detail.isEmpty
        ? l10n.errorOperationTimeout
        : l10n.errorUnknownWithDetail(detail);
  }

  if (normalized.contains('device not ready')) {
    return l10n.errorDeviceNotReady;
  }

  if (normalized.contains('unsupported or unrecognized file type') ||
      normalized.contains('unsupported file type') ||
      normalized.contains('unsupported file')) {
    return l10n.errorUnsupportedFileType;
  }

  if (normalized.contains('required ble characteristics not found') ||
      normalized.contains('characteristic') &&
          normalized.contains('not found')) {
    final detail = _trimPlatformNoise(raw);
    return normalized.contains('discovered:')
        ? l10n.errorUnknownWithDetail(detail)
        : l10n.errorBleCharacteristicsMissing;
  }

  if (normalized.contains('send_failed') ||
      normalized.contains('disconnected') ||
      normalized.contains('not connected') ||
      normalized.contains('传输端点尚未连接') ||
      normalized.contains('socket is not connected')) {
    return l10n.errorBluetoothDisconnected;
  }

  if (normalized.contains('connect_failed') ||
      normalized.contains('connect failed on channel') ||
      normalized.contains('universalble.connect failed') ||
      normalized.contains('连接被拒绝') ||
      normalized.contains('设备或资源忙') ||
      normalized.contains('无法分配内存')) {
    return l10n.errorBluetoothConnectFailed;
  }

  if (normalized.contains('username or password is incorrect')) {
    return l10n.errorAccountPasswordIncorrect;
  }

  if (normalized.contains('bandbbs account is not signed in')) {
    return l10n.settingsBandBbsAccountRequired;
  }

  if (normalized.contains('huami account is not signed in')) {
    return l10n.settingsHuamiAccountRequired;
  }

  if (normalized.contains('2fa') ||
      normalized.contains('two-factor') ||
      normalized.contains('did not return account cookies')) {
    return l10n.errorAccountTwoFactorIncomplete;
  }

  if (raw.trim().isEmpty) {
    return l10n.error;
  }

  return l10n.errorUnknownWithDetail(_trimPlatformNoise(raw));
}

String _flattenError(Object? error) {
  if (error == null) {
    return '';
  }
  if (error is PlatformException) {
    return [
      error.code,
      if (error.message != null) error.message!,
      if (error.details != null) error.details.toString(),
    ].join(' ');
  }
  return error.toString();
}

String _trimPlatformNoise(String raw) {
  var text = raw.trim();
  if (text.startsWith('Exception: ')) {
    text = text.substring('Exception: '.length);
  }
  if (text.startsWith('Bad state: ')) {
    text = text.substring('Bad state: '.length);
  }
  return text;
}
