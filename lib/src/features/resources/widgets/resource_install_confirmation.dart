import 'dart:async';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/device_profile.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/features/resources/services/resource_payload_analyzer.dart';

enum _InstallDecision { cancel, selectedType, detectedType, forceDetectedType }

Future<bool> confirmAndEnqueueResourceFile({
  required BuildContext context,
  required WidgetRef ref,
  required String fileName,
  required Uint8List bytes,
  required LocalDeviceInstallType selectedType,
}) async {
  final service = ResourceInstallService();
  final analysis = service.analyzePayload(
    fileName: fileName,
    bytes: bytes,
    hint: selectedType,
    source: 'manual-picker',
  );
  final decision = await _confirmInstall(
    context,
    ref,
    analysis,
    selectedType: selectedType,
    fileName: fileName,
    fileSize: _formatFileSize(bytes.length),
  );
  if (!context.mounted || decision == _InstallDecision.cancel) return false;

  final effectiveType = switch (decision) {
    _InstallDecision.selectedType => selectedType,
    _InstallDecision.detectedType ||
    _InstallDecision.forceDetectedType => analysis!.type,
    _InstallDecision.cancel => selectedType,
  };
  final installMode = switch (decision) {
    _InstallDecision.selectedType => ResourceInstallMode.forceType,
    _InstallDecision.forceDetectedType => ResourceInstallMode.forcePlatform,
    _InstallDecision.detectedType => ResourceInstallMode.automatic,
    _InstallDecision.cancel => ResourceInstallMode.automatic,
  };
  await ref
      .read(installQueueProvider.notifier)
      .enqueueConfirmedLocalFile(
        XFile.fromData(bytes, name: fileName),
        type: effectiveType,
        installMode: installMode,
      );
  return true;
}

Future<_InstallDecision> _confirmInstall(
  BuildContext context,
  WidgetRef ref,
  ResourcePayloadAnalysis? analysis, {
  required LocalDeviceInstallType selectedType,
  required String fileName,
  required String fileSize,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final device = ref.read(deviceManagerProvider).currentDevice;
  final deviceKind = device == null
      ? null
      : DeviceRegistry.resolveIdentity(
          name: device.name,
          codename: device.codename,
        ).kind;
  final selectedLabel = _typeLabel(
    l10n,
    selectedType,
    platform: deviceKind == DeviceKind.zepp
        ? ResourcePlatform.zeppOs
        : ResourcePlatform.vela,
  );
  if (analysis == null) {
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeUnknownTitle),
            content: Text(l10n.resourceTypeUnknownMessage(selectedLabel)),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallCancel),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallAsSelected(selectedLabel)
                    : l10n.resourceInstallAsSelectedCountdown(
                        selectedLabel,
                        seconds,
                      ),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.selectedType),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  final resourceKind = analysis.platform == ResourcePlatform.zeppOs
      ? DeviceKind.zepp
      : DeviceKind.xiaomi;
  if (device != null && deviceKind != resourceKind) {
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeErrorTitle),
            content: Text(
              l10n.resourcePlatformMismatchMessage(
                _platformLabel(analysis.platform),
                _typeLabel(l10n, analysis.type, platform: analysis.platform),
                device.name,
                deviceKind == DeviceKind.zepp ? 'ZeppOS' : 'VelaOS',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallAcknowledge),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallForce
                    : l10n.resourceInstallForceCountdown(seconds),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.forceDetectedType),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  if (analysis.type != selectedType) {
    final detectedLabel = _typeLabel(
      l10n,
      analysis.type,
      platform: analysis.platform,
    );
    return await showDialog<_InstallDecision>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(l10n.resourceTypeErrorTitle),
            content: Text(
              l10n.resourceTypeMismatchMessage(detectedLabel, selectedLabel),
            ),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.cancel),
                child: Text(l10n.resourceInstallCancel),
              ),
              _DelayedInstallButton(
                label: (seconds) => seconds == 0
                    ? l10n.resourceInstallAsSelected(selectedLabel)
                    : l10n.resourceInstallAsSelectedCountdown(
                        selectedLabel,
                        seconds,
                      ),
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.selectedType),
              ),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _InstallDecision.detectedType),
                child: Text(l10n.resourceInstallAsDetected(detectedLabel)),
              ),
            ],
          ),
        ) ??
        _InstallDecision.cancel;
  }

  return await showDialog<_InstallDecision>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            l10n.resourceInstallConfirmTitle(
              _typeLabel(l10n, analysis.type, platform: analysis.platform),
            ),
          ),
          content: Text(l10n.resourceInstallConfirmMessage(fileName, fileSize)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, _InstallDecision.cancel),
              child: Text(l10n.resourceInstallCancel),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, _InstallDecision.detectedType),
              child: Text(l10n.resourceInstallConfirm),
            ),
          ],
        ),
      ) ??
      _InstallDecision.cancel;
}

String _formatFileSize(int bytes) {
  if (bytes >= 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
  return '${(bytes / 1024).toStringAsFixed(1)} KB';
}

String _platformLabel(ResourcePlatform platform) => switch (platform) {
  ResourcePlatform.vela => 'VelaOS',
  ResourcePlatform.zeppOs => 'ZeppOS',
};

String _typeLabel(
  AppLocalizations l10n,
  LocalDeviceInstallType type, {
  required ResourcePlatform platform,
}) => switch (type) {
  LocalDeviceInstallType.app =>
    platform == ResourcePlatform.vela
        ? l10n.resourceTypeQuickApp
        : l10n.resourceTypeApp,
  LocalDeviceInstallType.watchface => l10n.resourceTypeWatchface,
  LocalDeviceInstallType.firmware => l10n.resourceTypeFirmware,
};

class _DelayedInstallButton extends StatefulWidget {
  const _DelayedInstallButton({required this.label, required this.onPressed});

  final String Function(int seconds) label;
  final VoidCallback onPressed;

  @override
  State<_DelayedInstallButton> createState() => _DelayedInstallButtonState();
}

class _DelayedInstallButtonState extends State<_DelayedInstallButton> {
  static const _delaySeconds = 3;
  Timer? _timer;
  int _remaining = _delaySeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() => _remaining--);
      if (_remaining == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: _remaining == 0 ? widget.onPressed : null,
      child: Text(widget.label(_remaining)),
    );
  }
}
