import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

String deviceConnectionPhaseText(
  AppLocalizations l10n,
  DeviceManagerState state, {
  required String fallbackDeviceName,
  required String connectType,
}) {
  final deviceName = state.connectionTargetName ?? fallbackDeviceName;
  return switch (state.connectionPhase) {
    DeviceConnectionPhase.preparing => l10n.deviceConnectionPreparing,
    DeviceConnectionPhase.connectingTransport =>
      l10n.deviceConnectionEstablishing(connectType.toUpperCase()),
    DeviceConnectionPhase.initializingProtocol =>
      l10n.deviceConnectionInitializing,
    DeviceConnectionPhase.authenticating => l10n.deviceConnectionAuthenticating,
    DeviceConnectionPhase.fetchingDeviceStatus =>
      l10n.deviceConnectionFetchingStatus,
    null => l10n.deviceConnectingTo(deviceName),
  };
}
