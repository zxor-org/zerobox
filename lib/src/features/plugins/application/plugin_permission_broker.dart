import 'dart:async';

import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_permission.dart';

typedef PluginPermissionPrompt =
    Future<PluginPermissionDecision> Function(PluginPermissionRequest request);
typedef PluginPermissionGrantReader = Future<Set<String>> Function(String id);
typedef PluginPermissionGrantWriter =
    Future<void> Function(String id, Set<String> grants);

class PluginPermissionBroker {
  PluginPermissionBroker({
    required this._prompt,
    required this._readPersistentGrants,
    required this._writePersistentGrants,
  });

  final PluginPermissionPrompt _prompt;
  final PluginPermissionGrantReader _readPersistentGrants;
  final PluginPermissionGrantWriter _writePersistentGrants;
  final Map<String, Set<String>> _sessionGrants = {};
  final Map<String, Set<String>> _persistentGrants = {};
  final Map<String, Future<void>> _pending = {};

  Future<void> authorize(
    InstalledPlugin plugin,
    PluginPermissionRequest request,
  ) async {
    if (!_declares(plugin, request.capability)) {
      throw PluginPermissionException(
        'permission_not_declared',
        '${plugin.manifest.name} did not declare ${request.capability}',
      );
    }
    if (request.risk == PluginPermissionRisk.low) return;

    final persistent = await _persistentFor(plugin.manifest.id);
    if (persistent.contains(request.grantKey) ||
        _sessionGrants[plugin.manifest.id]?.contains(request.grantKey) ==
            true) {
      return;
    }

    final pendingKey = '${plugin.manifest.id}:${request.grantKey}';
    final existing = _pending[pendingKey];
    if (existing != null) return existing;

    late final Future<void> authorization;
    authorization = _ask(plugin, request).whenComplete(() {
      if (identical(_pending[pendingKey], authorization)) {
        _pending.remove(pendingKey);
      }
    });
    _pending[pendingKey] = authorization;
    return authorization;
  }

  bool _declares(InstalledPlugin plugin, String capability) {
    final declared = plugin.manifest.permissions;
    if (declared.contains(capability)) return true;
    if (plugin.manifest.runtime != PluginRuntimeType.legacy) return false;
    final aliases = switch (capability) {
      'file' => const {'filesystem'},
      'protocol' => const {'debug'},
      'device' => const {'device', 'thirdpartyapp', 'installer'},
      _ => const <String>{},
    };
    return aliases.any(declared.contains);
  }

  Future<void> _ask(
    InstalledPlugin plugin,
    PluginPermissionRequest request,
  ) async {
    final decision = await _prompt(request);
    switch (decision) {
      case PluginPermissionDecision.once:
        return;
      case PluginPermissionDecision.session:
        (_sessionGrants[plugin.manifest.id] ??= {}).add(request.grantKey);
        return;
      case PluginPermissionDecision.always:
        final grants = await _persistentFor(plugin.manifest.id);
        grants.add(request.grantKey);
        await _writePersistentGrants(plugin.manifest.id, grants);
        return;
      case PluginPermissionDecision.deny:
        throw PluginPermissionException(
          'permission_denied',
          'Permission denied for ${request.operation}',
        );
    }
  }

  Future<Set<String>> _persistentFor(String pluginId) async {
    final existing = _persistentGrants[pluginId];
    if (existing != null) return existing;
    final loaded = await _readPersistentGrants(pluginId);
    return _persistentGrants[pluginId] = loaded;
  }

  Future<void> clearPlugin(String pluginId) async {
    _sessionGrants.remove(pluginId);
    _persistentGrants.remove(pluginId);
    await _writePersistentGrants(pluginId, const {});
  }

  void endSession(String pluginId) => _sessionGrants.remove(pluginId);
}
