import 'dart:async';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/router/app_router.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

class PluginHostRequestHandler extends ConsumerStatefulWidget {
  const PluginHostRequestHandler({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PluginHostRequestHandler> createState() =>
      _PluginHostRequestHandlerState();
}

class _PluginHostRequestHandlerState
    extends ConsumerState<PluginHostRequestHandler> {
  StreamSubscription<CommandEvent>? _subscription;
  Future<void> _requestTail = Future<void>.value();
  final _shownFailures = <String>{};

  @override
  void initState() {
    super.initState();
    _subscription = ref.read(applicationHostProvider).events.listen(_onEvent);
  }

  void _onEvent(CommandEvent event) {
    if (event.event != 'plugin.hostRequest' && event.event != 'plugin.error') {
      return;
    }
    _requestTail = _requestTail
        .catchError((_) {})
        .then(
          (_) => event.event == 'plugin.hostRequest'
              ? _handle(event.data)
              : _handlePluginFailure(event.data),
        );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _handle(Map<String, Object?> request) async {
    final requestId = request['requestId']?.toString() ?? '';
    if (requestId.isEmpty) return;
    Map<String, Object?> response;
    try {
      response = switch (request['type']?.toString()) {
        'permission' => await _permission(request),
        'pickFile' => await _pickFile(request),
        'saveFile' => await _saveFile(request),
        'openUrl' => await _openUrl(request),
        _ => const {'cancelled': true, 'error': 'Unsupported host request'},
      };
    } catch (error) {
      response = {'cancelled': true, 'error': error.toString()};
    }
    await ref
        .read(applicationHostProvider)
        .execute(
          ZeroBoxCommand(
            method: 'plugin.host.respond',
            params: {'requestId': requestId, 'response': response},
          ),
        );
  }

  Future<Map<String, Object?>> _permission(Map<String, Object?> request) async {
    final navigator = await _waitForNavigator();
    if (!mounted || navigator == null) return const {'decision': 'deny'};
    final dialogContext = navigator.context;
    if (!dialogContext.mounted) return const {'decision': 'deny'};
    final l10n = AppLocalizations.of(dialogContext)!;
    final plugin =
        request['pluginName']?.toString() ??
        request['pluginId']?.toString() ??
        l10n.pluginsTab;
    final operation = _permissionOperation(request, l10n);
    final decision = await showDialog<String>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginPermissionRequestTitle),
        content: Text(l10n.pluginPermissionRequestMessage(plugin, operation)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'deny'),
            child: Text(l10n.pluginPermissionDeny),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'once'),
            child: Text(l10n.pluginPermissionOnce),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'session'),
            child: Text(l10n.pluginPermissionSession),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'always'),
            child: Text(l10n.pluginPermissionAlways),
          ),
        ],
      ),
    );
    return {'decision': decision ?? 'deny'};
  }

  String _permissionOperation(
    Map<String, Object?> request,
    AppLocalizations l10n,
  ) {
    final method = request['operation']?.toString() ?? '';
    final operation = switch (method) {
      'ui.openExternal' => l10n.pluginPermissionOpenExternal,
      'file.pick' => l10n.pluginPermissionPickFile,
      'file.unload' => l10n.pluginPermissionExportFile,
      'network.fetch' || 'network.download' => l10n.pluginPermissionNetwork,
      'interconnect.send' ||
      'interconnect.observe' => l10n.pluginPermissionInterconnect,
      'provider.register' ||
      'provider.unregister' => l10n.pluginPermissionProvider,
      'device.list' ||
      'device.info' ||
      'device.apps.list' => l10n.pluginPermissionReadDevice,
      'device.connect' ||
      'device.disconnect' ||
      'device.apps.launch' ||
      'device.apps.uninstall' ||
      'device.install' => l10n.pluginPermissionOperateDevice,
      'protocol.observe' => l10n.pluginPermissionObserveProtocol,
      'protocol.send' => l10n.pluginPermissionSendProtocol,
      _ => request['description']?.toString() ?? method,
    };
    final resource = request['resource']?.toString().trim() ?? '';
    return resource.isEmpty ? operation : '$operation ($resource)';
  }

  Future<Map<String, Object?>> _pickFile(Map<String, Object?> request) async {
    final result = await FilePicker.pickFiles(withData: true);
    final selected = result?.files.firstOrNull;
    if (selected?.bytes == null) return const {'cancelled': true};
    return {
      'cancelled': false,
      'name': selected!.name,
      'bytes': selected.bytes!.toList(growable: false),
    };
  }

  Future<Map<String, Object?>> _saveFile(Map<String, Object?> request) async {
    final bytes = Uint8List.fromList(
      (request['bytes'] as List? ?? const [])
          .whereType<num>()
          .map((value) => value.toInt() & 0xff)
          .toList(growable: false),
    );
    final path = await FilePicker.saveFile(
      fileName: request['name']?.toString(),
      bytes: bytes,
    );
    return {
      'exported': path != null,
      if (path == null) 'cancelled': true,
      if (path != null) 'name': request['name']?.toString() ?? '',
    };
  }

  Future<Map<String, Object?>> _openUrl(Map<String, Object?> request) async {
    final uri = Uri.tryParse(request['url']?.toString() ?? '');
    if (uri == null) throw const FormatException('Invalid URL');
    return {'opened': await launchUrl(uri)};
  }

  Future<void> _handlePluginFailure(Map<String, Object?> failure) async {
    final pluginId = failure['pluginId']?.toString() ?? '';
    final occurredAt = failure['occurredAt']?.toString() ?? '';
    final key = '$pluginId:$occurredAt';
    if (pluginId.isEmpty || _shownFailures.contains(key)) return;
    final navigator = await _waitForNavigator();
    if (!mounted || navigator == null || !_shownFailures.add(key)) return;
    final dialogContext = navigator.context;
    if (!dialogContext.mounted) return;
    final l10n = AppLocalizations.of(dialogContext)!;
    final pluginName = failure['pluginName']?.toString() ?? pluginId;
    final rawError = failure['message']?.toString() ?? 'Unknown error';
    final error = rawError.length > 800
        ? '${rawError.substring(0, 800)}...'
        : rawError;
    final action = await showDialog<String>(
      context: dialogContext,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginErrorTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Text(l10n.pluginErrorMessage(pluginName, error)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'uninstall'),
            child: Text(l10n.pluginErrorUninstall),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'clear'),
            child: Text(l10n.pluginErrorClearData),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'safeMode'),
            child: Text(l10n.pluginErrorSafeMode),
          ),
        ],
      ),
    );
    final command = switch (action) {
      'uninstall' => ZeroBoxCommand(
        method: 'plugin.remove',
        params: {'id': pluginId},
      ),
      'clear' => ZeroBoxCommand(
        method: 'plugin.data.clear',
        params: {'id': pluginId},
      ),
      'safeMode' => const ZeroBoxCommand(
        method: 'plugin.safeMode.set',
        params: {'enabled': true},
      ),
      _ => null,
    };
    if (command != null) {
      await ref.read(applicationHostProvider).execute(command);
    }
  }

  Future<NavigatorState?> _waitForNavigator() async {
    while (mounted) {
      final navigator = rootNavigatorKey.currentState;
      if (navigator != null) return navigator;
      await WidgetsBinding.instance.endOfFrame;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
