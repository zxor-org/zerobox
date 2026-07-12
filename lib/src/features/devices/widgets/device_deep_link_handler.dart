import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/devices/services/device_share_link.dart';

final initialDeepLinksProvider = Provider<List<String>>((ref) => const []);

class DeviceDeepLinkHandler extends ConsumerStatefulWidget {
  const DeviceDeepLinkHandler({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<DeviceDeepLinkHandler> createState() =>
      _DeviceDeepLinkHandlerState();
}

class _DeviceDeepLinkHandlerState extends ConsumerState<DeviceDeepLinkHandler> {
  final AppLinks _appLinks = AppLinks();
  final Set<String> _handledLinks = {};
  StreamSubscription<Uri>? _linkSubscription;
  bool _handledInitialLinks = false;

  @override
  void initState() {
    super.initState();
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleLink(uri.toString());
    });
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_handledInitialLinks) return;
    _handledInitialLinks = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      for (final link in ref.read(initialDeepLinksProvider)) {
        if (await _handleLink(link)) {
          return;
        }
      }
      final initialLink = await _appLinks.getInitialLinkString();
      if (initialLink != null) {
        await _handleLink(initialLink);
      }
    });
  }

  Future<bool> _handleLink(String link) async {
    if (!_handledLinks.add(link)) return false;
    final uri = Uri.tryParse(link);
    if (uri != null) {
      final handled = await _handleBandBbsCallback(uri);
      if (handled) return true;
    }
    final device = DeviceShareLink.parse(link);
    if (device == null) return false;
    await _showDeviceDialog(device);
    return true;
  }

  Future<bool> _handleBandBbsCallback(Uri uri) async {
    try {
      final handled = await ref
          .read(bandBbsAuthProvider.notifier)
          .handleCallback(uri);
      if (!handled || !mounted) return handled;
      final l10n = AppLocalizations.of(context)!;
      final state = ref.read(bandBbsAuthProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            state.isSignedIn
                ? l10n.settingsAccountBandBbsSignedIn
                : l10n.settingsAccountBandBbsLoginFailed,
          ),
        ),
      );
      return true;
    } catch (_) {
      if (!mounted) return true;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountBandBbsLoginFailed)),
      );
      return true;
    }
  }

  Future<void> _showDeviceDialog(MiWearState device) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(deviceManagerProvider.notifier).importSharedDevice(device);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.deviceActionsShareQR),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.name),
            const SizedBox(height: 4),
            Text(device.addr, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.close),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              context.go('/devices/switch');
            },
            child: Text(l10n.deviceConnect),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
