import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/dialog_helper.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';

enum _ExternalLinkAction { openInZeroBox, openExternally }

ResourceRef? astroBoxResourceRefFromUri(Uri uri) {
  final host = uri.host.toLowerCase();
  if ((uri.scheme != 'https' && uri.scheme != 'http') ||
      (host != 'astrobox.online' && host != 'www.astrobox.online') ||
      uri.path != '/open' ||
      uri.queryParameters['source']?.toLowerCase() != 'resv2' ||
      uri.queryParameters['provider']?.toLowerCase() != 'officialv2') {
    return null;
  }
  final id = uri.queryParameters['id']?.trim() ?? '';
  return id.isEmpty
      ? null
      : ResourceRef(source: CommunitySourceId.astroboxRepo, id: id);
}

Future<void> openResourceExternalLink(BuildContext context, Uri uri) async {
  final l10n = AppLocalizations.of(context)!;
  final internalRef = astroBoxResourceRefFromUri(uri);
  final action = await ZeroBoxDialog.show<_ExternalLinkAction>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.externalLinkTitle),
      content: Text(
        '${l10n.externalLinkDescription(uri.toString())}'
        '${internalRef == null ? '' : '\n\n${l10n.externalLinkAstroBoxResourceHint}'}',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.cancel),
        ),
        if (internalRef != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ExternalLinkAction.openInZeroBox),
            child: Text(l10n.viewInZeroBox),
          ),
        FilledButton(
          onPressed: () =>
              Navigator.pop(dialogContext, _ExternalLinkAction.openExternally),
          child: Text(l10n.continueToWebsite),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (action) {
    case _ExternalLinkAction.openInZeroBox:
      final ref = internalRef!;
      final location = Uri(
        pathSegments: ['resources', 'detail', ref.id],
        queryParameters: {'source': ref.source.storageKey},
      );
      context.push('/$location');
    case _ExternalLinkAction.openExternally:
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    case null:
      return;
  }
}
