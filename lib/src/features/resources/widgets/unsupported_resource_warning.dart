import 'package:flutter/material.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';

bool needsUnsupportedResourceWarning(String label) {
  final normalized = label.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.contains('amazfit') || normalized.contains('华米')) {
    return true;
  }
  final band = RegExp(
    r'(?:xiaomi smart band|小米手环)\s*(\d+)',
  ).firstMatch(normalized);
  final bandGeneration = int.tryParse(band?.group(1) ?? '');
  if (bandGeneration != null && bandGeneration <= 8) return true;

  final redmiWatch = RegExp(
    r'(?:redmi watch|红米手表)\s*(\d+)',
  ).firstMatch(normalized);
  final watchGeneration = int.tryParse(redmiWatch?.group(1) ?? '');
  return watchGeneration != null && watchGeneration <= 4;
}

Future<void> showUnsupportedResourceWarning(
  BuildContext context,
  AppLocalizations l10n,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.unsupportedDeviceResourceTitle),
      content: Text(l10n.unsupportedDeviceResourceMessage),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.understood),
        ),
      ],
    ),
  );
}
