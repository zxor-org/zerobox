import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_permission.dart';
import 'package:zerobox/src/features/plugins/legacy/astrobox_legacy_adapter.dart';
import 'package:zerobox/src/features/plugins/application/plugin_permission_broker.dart';
import 'package:zerobox/src/features/plugins/application/plugin_text_file_codec.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime_factory.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_wasm_host.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage_factory.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';

class PluginManager {
  PluginManager({
    required this.deviceManager,
    required this.readDeviceState,
    required this.emitEvent,
  }) : _safeMode =
           SharedPrefsService.instance.getBool(_safeModePreference) ?? false {
    _interconnectSubscription = deviceManager.interconnectMessages.listen((
      message,
    ) {
      _queueInterconnectDispatch(message.pkgName, message.payload);
    });
    _rawProtocolSubscription = deviceManager.rawProtocolFrames.listen(
      _queueRawProtocolDispatch,
    );
  }

  static final _log = getLogger('PluginManager');
  static const _safeModePreference = 'plugins.safe_mode';
  static const _operationTimeout = Duration(seconds: 15);

  final DeviceManager deviceManager;
  final DeviceManagerState Function() readDeviceState;
  final void Function(CommandEvent event) emitEvent;
  final _plugins = <String, InstalledPlugin>{};
  final _runtimeStarts = <String, Future<PluginRuntime>>{};
  final _wasmHosts = <String, PluginWasmHost>{};
  final _uiNodes = <String, List<Map<String, Object?>>>{};
  final _openPages = <String, List<Map<String, Object?>>>{};
  final _hostRequests = <String, Completer<Map<String, Object?>>>{};
  final _providers = <String, _PluginProvider>{};
  final _failures = <String, PluginExecutionFailure>{};
  final _interconnectObservers = <String>{};
  final _rawProtocolObservers = <String>{};
  Future<void> _interconnectDispatchTail = Future<void>.value();
  Future<void> _rawProtocolDispatchTail = Future<void>.value();
  Future<void> _interconnectSendTail = Future<void>.value();
  Future<void> _runtimeTransition = Future<void>.value();
  final _dio = Dio();
  final _installer = ResourceInstallService();
  late final Future<PluginStorage> _storage = createPluginStorage();
  late final PluginPermissionBroker _permissionBroker = PluginPermissionBroker(
    prompt: _promptPermission,
    readPersistentGrants: (id) async =>
        (await _storage).readPermissionGrants(id),
    writePersistentGrants: (id, grants) async =>
        (await _storage).writePermissionGrants(id, grants),
  );
  late final StreamSubscription _interconnectSubscription;
  late final StreamSubscription _rawProtocolSubscription;
  Future<void>? _initialization;
  var _requestSequence = 0;
  var _closed = false;
  bool _safeMode;
  String? _activePluginId;
  PluginRuntime? _activeRuntime;
  PluginRuntime? _quickJsRuntime;
  PluginRuntime? _wasmRuntime;

  Future<void> initialize() => _initialization ??= _loadInstalledPlugins();

  Future<void> _loadInstalledPlugins() async {
    try {
      final installed = await (await _storage).loadInstalled();
      for (final plugin in installed) {
        _plugins[plugin.manifest.id] = plugin;
      }
    } catch (error, stackTrace) {
      _log.warning('Unable to load installed plugins', error, stackTrace);
    }
  }

  bool get safeMode => _safeMode;

  List<Map<String, Object?>> failures() => _failures.values
      .map((failure) => failure.toJson())
      .toList(growable: false);

  Future<void> setSafeMode(bool enabled) async {
    await initialize();
    if (_safeMode == enabled) return;
    _safeMode = enabled;
    await SharedPrefsService.instance.setBool(_safeModePreference, enabled);
    if (enabled) {
      await _closeActiveRuntime();
    }
    emitEvent(CommandEvent('plugin.safeMode', data: {'enabled': enabled}));
  }

  Future<List<Map<String, Object?>>> list({bool includeIcons = true}) async {
    await initialize();
    return _plugins.values
        .map((plugin) => _summary(plugin, includeIcon: includeIcons))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> install(
    Uint8List bytes, {
    String? fileName,
    bool includeIcon = true,
  }) async {
    await initialize();
    final package = const PluginPackageReader().read(bytes, fileName: fileName);
    final id = package.manifest.id;
    final config = _plugins[id]?.config ?? const <String, Object?>{};
    await _closeRuntime(id);
    _failures.remove(id);
    final plugin = await (await _storage).install(package, config: config);
    _plugins[id] = plugin;
    _emitState(id);
    return plugin.summaryJson(includeIcon: includeIcon);
  }

  Future<Map<String, Object?>> get(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    return {
      ..._summary(plugin),
      'ui': _uiNodes[id] ?? const [],
      if (_openPages[id] != null) 'page': _openPages[id],
    };
  }

  Future<List<Map<String, Object?>>> open(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    return _runPluginOperation(plugin, 'open', () async {
      await _ensureRuntime(id);
      return _uiNodes[id] ?? const [];
    });
  }

  Future<List<Map<String, Object?>>> invoke(
    String id,
    String callbackId,
    String? value,
  ) async {
    final plugin = _requirePlugin(id);
    return _runPluginOperation(plugin, 'callback', () async {
      final runtime = await _ensureRuntime(id);
      await runtime.invokeCallback(callbackId, value);
      return _uiNodes[id] ?? const [];
    });
  }

  Future<void> closePlugin(String id) async {
    await initialize();
    _requirePlugin(id);
    await _runtimeTransition.catchError((_) {});
    await _closeRuntime(id);
  }

  Future<void> clearData(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    await _closeRuntime(id);
    await _permissionBroker.clearPlugin(id);
    await (await _storage).clearPluginData(id);
    _plugins[id] = plugin.copyWith(config: const {});
    _failures.remove(id);
    _uiNodes.remove(id);
    _openPages.remove(id);
    _emitState(id);
  }

  Future<void> remove(String id) async {
    await initialize();
    _requirePlugin(id);
    await _closeRuntime(id);
    await _permissionBroker.clearPlugin(id);
    await (await _storage).removePlugin(id);
    _plugins.remove(id);
    _failures.remove(id);
    _uiNodes.remove(id);
    _openPages.remove(id);
    _providers.removeWhere((_, provider) => provider.pluginId == id);
    _interconnectObservers.remove(id);
    _rawProtocolObservers.remove(id);
    _emitState(id);
  }

  Future<void> respondToHostRequest(
    String requestId,
    Map<String, Object?> response,
  ) async {
    final completer = _hostRequests.remove(requestId);
    if (completer == null) {
      _log.warning('received response for unknown host request $requestId');
      return;
    }
    _log.info(
      'host request $requestId completed '
      '(cancelled=${response['cancelled'] == true})',
    );
    completer.complete(response);
  }

  Future<Object?> callProvider(
    String providerName,
    String operation,
    List<Object?> arguments,
  ) async {
    final provider = _providers[providerName];
    if (provider == null) throw StateError('Plugin provider not found');
    final plugin = _requirePlugin(provider.pluginId);
    try {
      return await _runPluginOperation(plugin, 'provider.$operation', () async {
        final runtime = await _ensureRuntime(provider.pluginId);
        final activeProvider = _providers[providerName];
        if (activeProvider == null ||
            activeProvider.pluginId != plugin.manifest.id) {
          throw StateError('Plugin did not register provider $providerName');
        }
        if (operation == 'categories' && activeProvider.categories == null) {
          return const <Object?>[];
        }
        final callback = switch (operation) {
          'categories' => activeProvider.categories!,
          'query' => activeProvider.query,
          'detail' => activeProvider.detail,
          'download' => activeProvider.download,
          _ => throw StateError('Unknown provider operation: $operation'),
        };
        return runtime.invokeRegistered(callback, arguments);
      });
    } finally {
      await closePlugin(provider.pluginId);
    }
  }

  Future<List<Map<String, Object?>>> providers() async {
    await initialize();
    return _providers.values
        .map((provider) => provider.toJson())
        .toList(growable: false);
  }

  String providerDisplayName(String id) => _providers[id]?.name ?? id;

  Future<Uint8List> readProviderFile(String providerName, String path) async {
    final provider = _providers[providerName];
    if (provider == null) throw StateError('Plugin provider not found');
    return (await _storage).readFile(
      provider.pluginId,
      PluginStoragePath.parse(path),
    );
  }

  Future<PluginRuntime> _ensureRuntime(String id) async {
    await initialize();
    if (_closed) throw StateError('Plugin manager is closed');
    final plugin = _requirePlugin(id);
    if (_safeMode) {
      throw PluginExecutionException(
        plugin.manifest.id,
        plugin.manifest.name,
        'Plugins are disabled in safe mode',
      );
    }
    final failure = _failures[id];
    if (failure != null) throw PluginExecutionException.fromFailure(failure);
    final pending = _runtimeStarts[id];
    if (pending != null) return pending;
    if (_activePluginId == id && _activeRuntime != null) {
      return _activeRuntime!;
    }
    final start = _runtimeTransition
        .catchError((_) {})
        .then((_) => _startRuntime(id));
    _runtimeTransition = start.then<void>((_) {}, onError: (_, _) {});
    _runtimeStarts[id] = start;
    try {
      return await start;
    } finally {
      if (identical(_runtimeStarts[id], start)) {
        _runtimeStarts.remove(id);
      }
    }
  }

  Future<PluginRuntime> _startRuntime(String id) async {
    final plugin = _requirePlugin(id);
    await _closeActiveRuntime();
    _uiNodes.remove(id);
    _openPages.remove(id);
    _providers.removeWhere((_, provider) => provider.pluginId == id);
    final runtime = await _runtimeFor(plugin.manifest.runtime);
    _activePluginId = id;
    _activeRuntime = runtime;
    try {
      await runtime.start(
        pluginId: id,
        pluginName: plugin.manifest.name,
        pluginVersion: plugin.manifest.version,
        runtimeVersion: BuildInfoService.appVersion,
        entryBytes: plugin.entryBytes,
        bootstrap: plugin.manifest.runtime == PluginRuntimeType.legacy
            ? astroBoxLegacyBootstrap
            : zeroBoxPluginBootstrap,
        hostCall: (method, arguments) =>
            _handleHostCall(plugin, method, arguments),
      );
      return runtime;
    } catch (_) {
      if (_activePluginId == id) {
        _activePluginId = null;
        _activeRuntime = null;
      }
      _providers.removeWhere((_, provider) => provider.pluginId == id);
      await runtime.close();
      rethrow;
    }
  }

  Future<void> _closeRuntime(String id) async {
    if (_activePluginId == id) await _closeActiveRuntime();
    await _wasmHosts.remove(id)?.dispose();
    _permissionBroker.endSession(id);
    _interconnectObservers.remove(id);
    _rawProtocolObservers.remove(id);
  }

  Future<PluginRuntime> _runtimeFor(PluginRuntimeType type) async {
    if (type == PluginRuntimeType.wasm) {
      return _wasmRuntime ??= createPluginRuntime(
        type,
        storage: await _storage,
      );
    }
    return _quickJsRuntime ??= createJavaScriptPluginRuntime();
  }

  Future<void> _closeActiveRuntime() async {
    final id = _activePluginId;
    final runtime = _activeRuntime;
    _activePluginId = null;
    _activeRuntime = null;
    if (runtime != null) await runtime.close();
    if (id == null) return;
    await _wasmHosts.remove(id)?.dispose();
    _permissionBroker.endSession(id);
    _interconnectObservers.remove(id);
    _rawProtocolObservers.remove(id);
  }

  Future<Object?> _handleHostCall(
    InstalledPlugin plugin,
    String method,
    List<Object?> arguments,
  ) async {
    final id = plugin.manifest.id;
    if (method == 'runtime.reportError') {
      final message = arguments.firstOrNull?.toString() ?? 'Unknown error';
      if (_isTransientHostError(message)) {
        _log.warning(
          'Plugin ${plugin.manifest.name} observed a transient host error: '
          '$message',
        );
        return null;
      }
      scheduleMicrotask(() {
        unawaited(
          _recordFailure(
            plugin,
            StateError(message),
            StackTrace.current,
            phase: 'runtime',
          ),
        );
      });
      return null;
    }
    final permission = _permissionRequest(plugin, method, arguments);
    if (permission != null) {
      await _permissionBroker.authorize(plugin, permission);
    }

    return switch (method) {
      'log.debug' || 'log.info' => _pluginLog(id, arguments, 'info'),
      'log.warning' => _pluginLog(id, arguments, 'warning'),
      'log.error' => _pluginLog(id, arguments, 'severe'),
      'storage.get' => _storageGet(id, arguments),
      'storage.set' => _storageSet(id, arguments),
      'storage.remove' => _storageRemove(id, arguments),
      'storage.clear' => _storageClear(id),
      'file.read' => _readSandboxFile(id, arguments),
      'file.write' => _writeSandboxFile(id, arguments),
      'file.list' => _listSandboxDirectory(id, arguments),
      'file.stat' => _statSandboxPath(id, arguments),
      'file.mkdir' => _mkdirSandboxPath(id, arguments),
      'file.copy' => _copySandboxPath(id, arguments),
      'file.move' => _moveSandboxPath(id, arguments),
      'file.remove' => _removeSandboxPath(id, arguments),
      'file.pick' => _pickSandboxFile(id, arguments),
      'file.unload' => _unloadSandboxFile(id, arguments),
      'network.fetch' => _networkFetch(arguments),
      'network.download' => _networkDownload(id, arguments),
      'interconnect.send' => _sendInterconnect(id, arguments),
      'interconnect.observe' => _interconnectObservers.add(id),
      'interconnect.unobserve' => _interconnectObservers.remove(id),
      'provider.register' => _registerProvider(id, arguments),
      'provider.unregister' => _unregisterProvider(id, arguments),
      'device.list' => _deviceList(),
      'device.info' => _deviceInfo(),
      'device.connect' => _connectDevice(arguments),
      'device.disconnect' => deviceManager.disconnect(),
      'device.apps.list' => _deviceApps(),
      'device.apps.launch' => _launchPluginApp(arguments),
      'device.apps.uninstall' => _uninstallPluginApp(arguments),
      'device.install' => _installSandboxFile(id, arguments),
      'protocol.send' => _sendProtocol(arguments),
      'protocol.observe' => _rawProtocolObservers.add(id),
      'protocol.unobserve' => _rawProtocolObservers.remove(id),
      'wasm.load' => _wasmLoad(plugin, arguments),
      'wasm.call' => _wasmCall(plugin, arguments),
      'wasm.memory.read' => _wasmMemoryRead(plugin, arguments),
      'wasm.memory.write' => _wasmMemoryWrite(plugin, arguments),
      'wasm.dispose' => _wasmDispose(plugin, arguments),
      'ui.update' => _updateSettingsUi(id, arguments),
      'ui.openPage' => _openPageWithNodes(id, arguments),
      'ui.openExternal' => _openUrl(id, arguments),
      _ => throw UnsupportedError('Unsupported ZeroBox Host API: $method'),
    };
  }

  PluginPermissionRequest? _permissionRequest(
    InstalledPlugin plugin,
    String method,
    List<Object?> arguments,
  ) {
    final policy = switch (method) {
      'ui.update' || 'ui.openPage' => ('ui', PluginPermissionRisk.low),
      'ui.openExternal' => ('ui', PluginPermissionRisk.medium),
      'file.read' ||
      'file.write' ||
      'file.list' ||
      'file.stat' ||
      'file.mkdir' ||
      'file.copy' ||
      'file.move' ||
      'file.remove' => ('file', PluginPermissionRisk.low),
      'file.pick' || 'file.unload' => ('file', PluginPermissionRisk.medium),
      'network.fetch' ||
      'network.download' => ('network', PluginPermissionRisk.medium),
      'interconnect.send' ||
      'interconnect.observe' => ('interconnect', PluginPermissionRisk.medium),
      'provider.register' ||
      'provider.unregister' => ('provider', PluginPermissionRisk.medium),
      'device.list' ||
      'device.info' ||
      'device.apps.list' => ('device', PluginPermissionRisk.medium),
      'device.connect' ||
      'device.disconnect' ||
      'device.apps.launch' ||
      'device.apps.uninstall' ||
      'device.install' => ('device', PluginPermissionRisk.high),
      'protocol.observe' => ('protocol', PluginPermissionRisk.medium),
      'protocol.send' => ('protocol', PluginPermissionRisk.high),
      _ => null,
    };
    if (policy == null) return null;
    final resource = _permissionResource(method, arguments);
    final scoped =
        method.startsWith('network.') ||
        method == 'ui.openExternal' ||
        method.startsWith('interconnect.') ||
        method.startsWith('device.') ||
        method.startsWith('protocol.');
    return PluginPermissionRequest(
      pluginId: plugin.manifest.id,
      pluginName: plugin.manifest.name,
      capability: policy.$1,
      operation: method,
      risk: policy.$2,
      description: _permissionDescription(method, resource),
      resource: resource,
      scope: scoped ? resource : null,
    );
  }

  String? _permissionResource(String method, List<Object?> arguments) {
    if (method == 'network.fetch' ||
        method == 'network.download' ||
        method == 'ui.openExternal') {
      return Uri.tryParse(arguments.firstOrNull?.toString() ?? '')?.host;
    }
    if (method == 'interconnect.send' || method.startsWith('device.apps.')) {
      return arguments.firstOrNull?.toString();
    }
    if (method == 'device.connect') return arguments.firstOrNull?.toString();
    if (method.startsWith('device.') || method.startsWith('protocol.')) {
      return readDeviceState().currentDevice?.name;
    }
    if (method == 'file.unload') return arguments.firstOrNull?.toString();
    return null;
  }

  bool _isTransientHostError(String message) {
    final normalized = message.toLowerCase();
    return normalized.contains('device not ready') ||
        normalized.contains('device disconnected') ||
        normalized.contains('transport disconnected') ||
        normalized.contains('has not established an interconnect session') ||
        normalized.contains('did not establish an interconnect session');
  }

  String _permissionDescription(String method, String? resource) {
    final target = resource?.isNotEmpty == true ? ' $resource' : '';
    return switch (method) {
      'file.pick' => 'select files from the native environment',
      'file.unload' => 'export$target to the native environment',
      'network.fetch' => 'access$target',
      'interconnect.send' => 'communicate with$target',
      'interconnect.observe' => 'receive interconnect messages',
      'provider.register' => 'register a resource provider',
      'provider.unregister' => 'remove a resource provider',
      'device.list' => 'access paired devices',
      'device.info' => 'read information from$target',
      'device.connect' => 'connect to$target',
      'device.disconnect' => 'disconnect$target',
      'device.apps.list' => 'read applications from$target',
      'device.apps.launch' => 'launch$target',
      'device.apps.uninstall' => 'uninstall$target',
      'device.install' => 'install a file on$target',
      'protocol.observe' => 'observe the protocol of$target',
      'protocol.send' => 'send raw protocol data to$target',
      _ => method,
    };
  }

  Future<PluginPermissionDecision> _promptPermission(
    PluginPermissionRequest request,
  ) async {
    final response = await _requestHost(
      request.pluginId,
      'permission',
      request.toJson(),
    );
    return switch (response['decision']?.toString()) {
      'once' => PluginPermissionDecision.once,
      'session' => PluginPermissionDecision.session,
      'always' => PluginPermissionDecision.always,
      _ => PluginPermissionDecision.deny,
    };
  }

  Object? _pluginLog(String id, List<Object?> values, String level) {
    final log = getLogger('Plugin.$id');
    final message = values.join(' ');
    switch (level) {
      case 'warning':
        log.warning(message);
      case 'severe':
        log.severe(message);
      default:
        log.info(message);
    }
    return null;
  }

  Object? _storageGet(String id, List<Object?> arguments) {
    final key = arguments.firstOrNull?.toString() ?? '';
    if (key.isEmpty) throw const FormatException('Storage key is required');
    return _requirePlugin(id).config[key];
  }

  Future<void> _storageSet(String id, List<Object?> arguments) async {
    final key = arguments.firstOrNull?.toString() ?? '';
    if (key.isEmpty) throw const FormatException('Storage key is required');
    final current = _requirePlugin(id);
    final config = Map<String, Object?>.of(current.config)
      ..[key] = arguments.elementAtOrNull(1);
    await (await _storage).writeConfig(id, config);
    _plugins[id] = current.copyWith(config: config);
  }

  Future<void> _storageRemove(String id, List<Object?> arguments) async {
    final key = arguments.firstOrNull?.toString() ?? '';
    if (key.isEmpty) throw const FormatException('Storage key is required');
    final current = _requirePlugin(id);
    final config = Map<String, Object?>.of(current.config)..remove(key);
    await (await _storage).writeConfig(id, config);
    _plugins[id] = current.copyWith(config: config);
  }

  Future<void> _storageClear(String id) async {
    final current = _requirePlugin(id);
    await (await _storage).writeConfig(id, const {});
    _plugins[id] = current.copyWith(config: const {});
  }

  Future<Map<String, Object?>?> _pickSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final options = _jsonMap(arguments.firstOrNull);
    final response = await _requestHost(pluginId, 'pickFile', {
      'options': options,
    });
    if (response['cancelled'] == true) return null;
    final bytes = _bytes(response['bytes']);
    final rawName = response['name']?.toString() ?? 'plugin-file';
    final name = rawName.replaceAll(RegExp(r'[/\\\x00]'), '_');
    final path = PluginStoragePath.parse(
      '/temp/picker/${DateTime.now().microsecondsSinceEpoch}/$name',
    );
    await (await _storage).writeFile(pluginId, path, bytes);
    return {
      'name': name,
      'path': path.virtualPath,
      'size': bytes.length,
      if (options['_legacyText'] == true)
        'textLength': PluginTextFileCodec.length(bytes),
    };
  }

  Future<Map<String, Object?>> _unloadSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final bytes = await (await _storage).readFile(pluginId, path);
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final name = options['suggestedName']?.toString().trim();
    return _requestHost(pluginId, 'saveFile', {
      'name': name?.isNotEmpty == true
          ? name
          : path.relativePath.split('/').last,
      'bytes': bytes.toList(growable: false),
    });
  }

  Future<String> _readSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final allBytes = await (await _storage).readFile(pluginId, path);
    final offset = (options['offset'] as num?)?.toInt() ?? 0;
    final requestedLength = (options['length'] as num?)?.toInt();
    if (options['encoding']?.toString().toLowerCase() == 'text' &&
        options['_legacyText'] == true) {
      return PluginTextFileCodec.slice(
        allBytes,
        offset: offset,
        length: requestedLength,
      );
    }
    if (offset < 0 || offset > allBytes.length) {
      throw RangeError('Invalid file offset: $offset');
    }
    final end = requestedLength == null
        ? allBytes.length
        : (offset + requestedLength).clamp(offset, allBytes.length);
    final bytes = Uint8List.sublistView(allBytes, offset, end);
    return switch (options['encoding']?.toString().toLowerCase()) {
      'utf8' || 'utf-8' || 'text' => utf8.decode(bytes),
      null || '' || 'base64' => base64Encode(bytes),
      final encoding => throw FormatException(
        'Unsupported plugin file encoding: $encoding',
      ),
    };
  }

  Future<void> _writeSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final value = arguments.elementAtOrNull(1);
    final options = _jsonMap(arguments.elementAtOrNull(2));
    final bytes = switch (options['encoding']?.toString().toLowerCase()) {
      'utf8' ||
      'utf-8' ||
      'text' => Uint8List.fromList(utf8.encode(value?.toString() ?? '')),
      null || '' || 'base64' => _bytes(value),
      final encoding => throw FormatException(
        'Unsupported plugin file encoding: $encoding',
      ),
    };
    final storage = await _storage;
    if (options['append'] == true) {
      await storage.writeFileStream(
        pluginId,
        path,
        Stream.value(bytes),
        append: true,
      );
    } else {
      await storage.writeFile(pluginId, path, bytes);
    }
  }

  Future<List<Map<String, Object?>>> _listSandboxDirectory(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final entries = await (await _storage).listDirectory(pluginId, path);
    return entries.map((entry) => entry.toJson()).toList(growable: false);
  }

  Future<Map<String, Object?>?> _statSandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final stat = await (await _storage).stat(pluginId, path);
    return stat?.toJson();
  }

  Future<void> _mkdirSandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    await (await _storage).createDirectory(pluginId, path);
  }

  Future<void> _copySandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final source = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final destination = PluginStoragePath.parse(
      arguments.elementAtOrNull(1)?.toString() ?? '',
    );
    await _copyStorageEntry(pluginId, source, destination);
  }

  Future<void> _moveSandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final source = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final destination = PluginStoragePath.parse(
      arguments.elementAtOrNull(1)?.toString() ?? '',
    );
    if (source.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    await _copyStorageEntry(pluginId, source, destination);
    await (await _storage).removeFile(pluginId, source);
  }

  Future<void> _copyStorageEntry(
    String pluginId,
    PluginStoragePath source,
    PluginStoragePath destination,
  ) async {
    final storage = await _storage;
    final stat = await storage.stat(pluginId, source);
    if (stat == null) {
      throw StateError('Plugin file does not exist: ${source.virtualPath}');
    }
    if (!stat.isDirectory) {
      await storage.writeFile(
        pluginId,
        destination,
        await storage.readFile(pluginId, source),
      );
      return;
    }
    if (destination.area == source.area &&
        (source.relativePath.isEmpty ||
            destination.relativePath == source.relativePath ||
            destination.relativePath.startsWith('${source.relativePath}/'))) {
      throw const FormatException('A directory cannot be copied into itself');
    }
    await storage.createDirectory(pluginId, destination);
    for (final child in await storage.listDirectory(pluginId, source)) {
      final name = child.path.split('/').last;
      await _copyStorageEntry(
        pluginId,
        PluginStoragePath.parse(child.path),
        PluginStoragePath.parse('${destination.virtualPath}/$name'),
      );
    }
  }

  Future<void> _removeSandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    await (await _storage).removeFile(pluginId, path);
  }

  Future<void> _sendInterconnect(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final packageName = arguments.firstOrNull?.toString() ?? '';
    final data = arguments.elementAtOrNull(1)?.toString() ?? '';
    if (packageName.isEmpty) {
      throw const FormatException('Package name is required');
    }
    final payload = Uint8List.fromList(utf8.encode(data));
    _log.info(
      'plugin $pluginId sending interconnect message to $packageName '
      '(${payload.length} bytes)',
    );
    final send = _interconnectSendTail.catchError((_) {}).then((_) async {
      try {
        await deviceManager.sendInterconnectMessage(packageName, payload);
        _log.info(
          'plugin $pluginId interconnect message queued for $packageName',
        );
      } catch (error, stackTrace) {
        _log.warning(
          'plugin $pluginId failed to send interconnect message to '
          '$packageName',
          error,
          stackTrace,
        );
        rethrow;
      }
    });
    _interconnectSendTail = send;
    await send;
  }

  List<Map<String, Object?>> _deviceList() => readDeviceState().pairedDevices
      .map(
        (device) => {
          'id': device.addr,
          'name': device.name,
          'connectType': device.connectType,
          if (device.codename != null) 'codename': device.codename,
          'connected': readDeviceState().currentDevice?.addr == device.addr,
        },
      )
      .toList(growable: false);

  Map<String, Object?> _deviceInfo() {
    final state = readDeviceState();
    final device = state.currentDevice;
    if (device == null) throw StateError('No device is connected');
    return {
      'id': device.addr,
      'name': device.name,
      if (device.codename != null) 'codename': device.codename,
      if (state.battery != null) 'battery': state.battery!.capacity,
      if (state.systemInfo != null) ...{
        'model': state.systemInfo!.model,
        'firmwareVersion': state.systemInfo!.firmwareVersion,
      },
    };
  }

  Future<Map<String, Object?>> _connectDevice(List<Object?> arguments) async {
    final requested = arguments.firstOrNull?.toString() ?? '';
    final state = readDeviceState();
    final target = state.pairedDevices
        .where((device) => requested.isEmpty || device.addr == requested)
        .firstOrNull;
    if (target == null) throw StateError('Paired device not found: $requested');
    final authKey = target.authkey ?? '';
    if (authKey.isEmpty) throw StateError('Device has no authentication key');
    await deviceManager.connect(
      target.addr,
      target.name,
      authKey,
      connectType: target.connectType,
    );
    return _deviceInfo();
  }

  Future<List<Map<String, Object?>>> _deviceApps() async {
    await deviceManager.fetchApps();
    return readDeviceState().apps
        .map(
          (app) => {
            'packageName': app.packageName,
            'name': app.appName,
            'versionCode': app.versionCode,
            'canRemove': app.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<void> _launchPluginApp(List<Object?> arguments) async {
    final app = await _pluginApp(arguments.firstOrNull?.toString() ?? '');
    final options = _jsonMap(arguments.elementAtOrNull(1));
    await deviceManager.openApp(app, page: options['page']?.toString() ?? '');
  }

  Future<void> _uninstallPluginApp(List<Object?> arguments) async {
    final app = await _pluginApp(arguments.firstOrNull?.toString() ?? '');
    await deviceManager.uninstallApp(app);
  }

  Future<AppInfo> _pluginApp(String packageName) async {
    await deviceManager.fetchApps();
    final app = readDeviceState().apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) throw StateError('Application not found: $packageName');
    return app;
  }

  Future<void> _installSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final type = switch (options['type']?.toString()) {
      'app' => LocalDeviceInstallType.app,
      'watchface' => LocalDeviceInstallType.watchface,
      'firmware' => LocalDeviceInstallType.firmware,
      final value => throw FormatException('Unsupported install type: $value'),
    };
    final bytes = await (await _storage).readFile(pluginId, path);
    await _installer.installLocalPayload(
      type: type,
      fileName:
          options['fileName']?.toString() ?? path.relativePath.split('/').last,
      bytes: bytes,
      deviceManager: deviceManager,
      onProgress: (progress) => emitEvent(
        CommandEvent(
          'plugin.installProgress',
          data: {'pluginId': pluginId, 'progress': progress},
        ),
      ),
    );
  }

  Future<void> _sendProtocol(List<Object?> arguments) async {
    await deviceManager.sendRaw(_bytes(arguments.firstOrNull));
  }

  Future<String> _wasmLoad(
    InstalledPlugin plugin,
    List<Object?> arguments,
  ) async {
    final path = arguments.firstOrNull?.toString() ?? '';
    return (await _wasmHost(
      plugin,
    )).load(path, _jsonMap(arguments.elementAtOrNull(1)));
  }

  Future<List<Object?>> _wasmCall(
    InstalledPlugin plugin,
    List<Object?> arguments,
  ) async {
    final id = arguments.firstOrNull?.toString() ?? '';
    final function = arguments.elementAtOrNull(1)?.toString() ?? '';
    final values =
        (arguments.elementAtOrNull(2) as List?)?.cast<Object?>() ?? const [];
    return (await _wasmHost(plugin)).call(id, function, values);
  }

  Future<String> _wasmMemoryRead(
    InstalledPlugin plugin,
    List<Object?> arguments,
  ) async {
    return (await _wasmHost(plugin)).readMemory(
      arguments.firstOrNull?.toString() ?? '',
      arguments.elementAtOrNull(1)?.toString() ?? 'memory',
      (arguments.elementAtOrNull(2) as num?)?.toInt() ?? 0,
      (arguments.elementAtOrNull(3) as num?)?.toInt() ?? 0,
    );
  }

  Future<void> _wasmMemoryWrite(
    InstalledPlugin plugin,
    List<Object?> arguments,
  ) async {
    (await _wasmHost(plugin)).writeMemory(
      arguments.firstOrNull?.toString() ?? '',
      arguments.elementAtOrNull(1)?.toString() ?? 'memory',
      (arguments.elementAtOrNull(2) as num?)?.toInt() ?? 0,
      _bytes(arguments.elementAtOrNull(3)),
    );
  }

  Future<void> _wasmDispose(
    InstalledPlugin plugin,
    List<Object?> arguments,
  ) async {
    (await _wasmHost(
      plugin,
    )).disposeInstance(arguments.firstOrNull?.toString() ?? '');
  }

  Future<PluginWasmHost> _wasmHost(InstalledPlugin plugin) async {
    if (plugin.manifest.runtime != PluginRuntimeType.hybrid) {
      throw UnsupportedError('WASM is only available to hybrid plugins');
    }
    return _wasmHosts[plugin.manifest.id] ??= PluginWasmHost(
      pluginId: plugin.manifest.id,
      storage: await _storage,
    );
  }

  Uint8List _bytes(Object? value) {
    if (value is Uint8List) return value;
    if (value is List) {
      return Uint8List.fromList(
        value.whereType<num>().map((item) => item.toInt() & 0xff).toList(),
      );
    }
    if (value is String) return base64Decode(value);
    throw const FormatException('Binary data is required');
  }

  void _queueInterconnectDispatch(String packageName, Uint8List bytes) {
    final payload = utf8.decode(bytes, allowMalformed: true);
    _interconnectDispatchTail = _interconnectDispatchTail
        .catchError((_) {})
        .then((_) async {
          _log.info(
            'dispatching interconnect message from $packageName '
            '(${bytes.length} bytes)',
          );
          final id = _activePluginId;
          final runtime = _activeRuntime;
          final plugin = id == null ? null : _plugins[id];
          if (id == null ||
              runtime == null ||
              plugin == null ||
              _failures.containsKey(id) ||
              !_interconnectObservers.contains(id)) {
            return;
          }
          try {
            await runtime.dispatchEvent(
              plugin.manifest.runtime == PluginRuntimeType.legacy
                  ? 'onQAICMessage_$packageName'
                  : 'interconnect',
              plugin.manifest.runtime == PluginRuntimeType.legacy
                  ? payload
                  : jsonEncode({'packageName': packageName, 'data': payload}),
            );
          } catch (error, stackTrace) {
            await _recordFailure(
              plugin,
              error,
              stackTrace,
              phase: 'interconnect',
            );
          }
        });
  }

  void _queueRawProtocolDispatch(Uint8List bytes) {
    final payload = jsonEncode({'data': base64Encode(bytes)});
    _rawProtocolDispatchTail = _rawProtocolDispatchTail.catchError((_) {}).then(
      (_) async {
        final id = _activePluginId;
        final runtime = _activeRuntime;
        final plugin = id == null ? null : _plugins[id];
        if (id == null ||
            runtime == null ||
            plugin == null ||
            _failures.containsKey(id) ||
            !_rawProtocolObservers.contains(id)) {
          return;
        }
        try {
          await runtime.dispatchEvent('protocol.data', payload);
        } catch (error, stackTrace) {
          await _recordFailure(plugin, error, stackTrace, phase: 'protocol');
        }
      },
    );
  }

  Future<Map<String, Object?>> _networkDownload(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final url = arguments.firstOrNull?.toString() ?? '';
    _requireNetworkUri(url);
    final path = PluginStoragePath.parse(
      arguments.elementAtOrNull(1)?.toString() ?? '',
    );
    final options = _jsonMap(arguments.elementAtOrNull(2));
    final response = await _dio.request<ResponseBody>(
      url,
      options: Options(
        method: options['method']?.toString() ?? 'GET',
        headers: (options['headers'] as Map?)?.cast<String, Object?>(),
        responseType: ResponseType.stream,
        validateStatus: (status) =>
            status != null && status >= 200 && status < 300,
      ),
    );
    final body = response.data;
    if (body == null) throw StateError('Network response has no body');
    final written = await (await _storage).writeFileStream(
      pluginId,
      path,
      body.stream,
      append: options['append'] == true,
    );
    return {
      'path': path.virtualPath,
      'bytesWritten': written,
      'status': response.statusCode ?? 0,
    };
  }

  Future<Map<String, Object?>> _networkFetch(List<Object?> arguments) async {
    final url = arguments.firstOrNull?.toString() ?? '';
    _requireNetworkUri(url);
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final body = options['body']?.toString() ?? '';
    Uint8List? requestBody;
    if (body.isNotEmpty) {
      try {
        requestBody = base64Decode(body);
      } on FormatException {
        requestBody = Uint8List.fromList(utf8.encode(body));
      }
    }
    try {
      final response = await _dio.request<ResponseBody>(
        url,
        data: requestBody,
        options: Options(
          method: options['method']?.toString() ?? 'GET',
          headers: (options['headers'] as Map?)?.cast<String, Object?>(),
          responseType: ResponseType.stream,
          validateStatus: (_) => true,
        ),
      );
      final builder = BytesBuilder(copy: false);
      var length = 0;
      await for (final chunk
          in response.data?.stream ?? const Stream<Uint8List>.empty()) {
        length += chunk.length;
        if (length > 16 * 1024 * 1024) {
          throw StateError(
            'Network response exceeds 16 MiB; use network.download',
          );
        }
        builder.add(chunk);
      }
      final bytes = builder.takeBytes();
      return {
        'status': response.statusCode ?? 0,
        'headers': response.headers.map.map(
          (key, values) => MapEntry(key, values.join(',')),
        ),
        'contentType': response.headers.value(Headers.contentTypeHeader) ?? '',
        'body': base64Encode(bytes),
      };
    } on DioException catch (error) {
      return {'error': error.message ?? error.toString()};
    }
  }

  Object? _registerProvider(String pluginId, List<Object?> arguments) {
    final json = _jsonMap(arguments.firstOrNull);
    final provider = _PluginProvider.fromJson(pluginId, json);
    final existing = _providers[provider.id];
    if (existing != null && existing.pluginId != pluginId) {
      throw StateError(
        'Provider ID is already registered by another plugin: ${provider.id}',
      );
    }
    _providers[provider.id] = provider;
    emitEvent(CommandEvent('plugin.provider', data: provider.toJson()));
    return null;
  }

  Uri _requireNetworkUri(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw FormatException('Only HTTP and HTTPS URLs are supported: $value');
    }
    return uri;
  }

  Object? _unregisterProvider(String pluginId, List<Object?> arguments) {
    final id = arguments.firstOrNull?.toString() ?? '';
    final provider = _providers[id];
    if (provider != null && provider.pluginId != pluginId) {
      throw StateError('Provider belongs to another plugin: $id');
    }
    _providers.remove(id);
    emitEvent(
      CommandEvent(
        'plugin.provider',
        data: {'pluginId': pluginId, 'id': id, 'removed': true},
      ),
    );
    return null;
  }

  Object? _openPageWithNodes(String id, List<Object?> arguments) {
    final nodes = _parseUiNodes(arguments.firstOrNull);
    _openPages[id] = nodes;
    emitEvent(
      CommandEvent('plugin.ui', data: {'id': id, 'nodes': nodes, 'page': true}),
    );
    return null;
  }

  Object? _updateSettingsUi(String id, List<Object?> arguments) {
    final nodes = _parseUiNodes(arguments.firstOrNull);
    _uiNodes[id] = nodes;
    _openPages.remove(id);
    emitEvent(CommandEvent('plugin.ui', data: {'id': id, 'nodes': nodes}));
    return null;
  }

  List<Map<String, Object?>> _parseUiNodes(Object? value) {
    final raw = value is String ? jsonDecode(value) : value;
    if (raw is! List) throw const FormatException('Plugin UI must be a list');
    if (raw.length > 256) {
      throw const FormatException('Plugin UI contains too many nodes');
    }
    final ids = <String>{};
    return raw
        .map((value) {
          if (value is! Map) {
            throw const FormatException('Plugin UI node must be an object');
          }
          final node = value.cast<String, Object?>();
          final id = node['node_id']?.toString() ?? '';
          if (id.isEmpty || !ids.add(id)) {
            throw FormatException(
              'Invalid or duplicate plugin UI node ID: $id',
            );
          }
          final contentValue = node['content'];
          if (contentValue is! Map) {
            throw FormatException('Plugin UI node $id has no content');
          }
          final content = contentValue.cast<String, Object?>();
          final type = content['type']?.toString() ?? '';
          final payload = content['value'];
          switch (type) {
            case 'Text' || 'HtmlDocument':
              if (payload is! String) {
                throw FormatException('Plugin UI $type node $id requires text');
              }
              break;
            case 'Button':
              _validateUiCallbackPayload(id, type, payload, requireText: true);
              break;
            case 'Input':
              _validateUiCallbackPayload(id, type, payload, requireText: true);
              break;
            case 'Dropdown':
              final values = _validateUiCallbackPayload(id, type, payload);
              final options = values['options'];
              if (options is! List ||
                  options.length > 256 ||
                  options.any((option) => option is! String)) {
                throw FormatException(
                  'Plugin UI Dropdown node $id has invalid options',
                );
              }
              break;
            default:
              throw FormatException('Unsupported plugin UI node type: $type');
          }
          return {
            'node_id': id,
            'visibility': node['visibility'] != false,
            'disabled': node['disabled'] == true,
            'content': {'type': type, 'value': payload},
          };
        })
        .toList(growable: false);
  }

  Map<String, Object?> _validateUiCallbackPayload(
    String id,
    String type,
    Object? value, {
    bool requireText = false,
  }) {
    if (value is! Map) {
      throw FormatException('Plugin UI $type node $id requires an object');
    }
    final values = value.cast<String, Object?>();
    if (values['callback_fun_id']?.toString().isEmpty != false) {
      throw FormatException('Plugin UI $type node $id has no callback');
    }
    if (requireText && values['text'] is! String) {
      throw FormatException('Plugin UI $type node $id has no text');
    }
    return values;
  }

  Future<Map<String, Object?>> _openUrl(String id, List<Object?> arguments) {
    final url = arguments.firstOrNull?.toString() ?? '';
    _requireNetworkUri(url);
    return _requestHost(id, 'openUrl', {'url': url});
  }

  Future<Map<String, Object?>> _requestHost(
    String pluginId,
    String type,
    Map<String, Object?> data,
  ) {
    final requestId =
        '${DateTime.now().microsecondsSinceEpoch}-${++_requestSequence}';
    final completer = Completer<Map<String, Object?>>();
    _hostRequests[requestId] = completer;
    _log.info(
      'dispatching host request $requestId type=$type for plugin $pluginId',
    );
    emitEvent(
      CommandEvent(
        'plugin.hostRequest',
        data: {
          'requestId': requestId,
          'pluginId': pluginId,
          'type': type,
          ...data,
        },
      ),
    );
    return completer.future.timeout(
      const Duration(minutes: 5),
      onTimeout: () {
        _hostRequests.remove(requestId);
        _log.warning(
          'host request $requestId type=$type timed out for plugin $pluginId',
        );
        throw TimeoutException('Plugin host request timed out');
      },
    );
  }

  Map<String, Object?> _jsonMap(Object? value) {
    final raw = value is String ? jsonDecode(value) : value;
    return (raw as Map?)?.cast<String, Object?>() ?? const {};
  }

  InstalledPlugin _requirePlugin(String id) {
    final plugin = _plugins[id];
    if (plugin == null) throw StateError('Plugin not found: $id');
    return plugin;
  }

  void _emitState(String id) {
    emitEvent(CommandEvent('plugin.state', data: {'id': id}));
  }

  Map<String, Object?> _summary(
    InstalledPlugin plugin, {
    bool includeIcon = true,
  }) => {
    ...plugin.summaryJson(includeIcon: includeIcon),
    if (_failures[plugin.manifest.id] case final failure?)
      'failure': failure.toJson(),
    'safeMode': _safeMode,
    'running': _activePluginId == plugin.manifest.id,
  };

  Future<T> _runPluginOperation<T>(
    InstalledPlugin plugin,
    String phase,
    Future<T> Function() operation,
  ) async {
    try {
      return await operation().timeout(
        _operationTimeout,
        onTimeout: () => throw TimeoutException(
          'Plugin operation $phase timed out',
          _operationTimeout,
        ),
      );
    } on PluginExecutionException {
      rethrow;
    } catch (error, stackTrace) {
      if (_isTransientHostError(error.toString())) {
        throw PluginExecutionException(
          plugin.manifest.id,
          plugin.manifest.name,
          error.toString(),
        );
      }
      await _recordFailure(plugin, error, stackTrace, phase: phase);
      throw PluginExecutionException(
        plugin.manifest.id,
        plugin.manifest.name,
        error.toString(),
      );
    }
  }

  Future<void> _recordFailure(
    InstalledPlugin plugin,
    Object error,
    StackTrace stackTrace, {
    required String phase,
  }) async {
    final id = plugin.manifest.id;
    if (_closed || _failures.containsKey(id)) return;
    final failure = PluginExecutionFailure(
      pluginId: id,
      pluginName: plugin.manifest.name,
      phase: phase,
      message: error.toString(),
      occurredAt: DateTime.now(),
    );
    _failures[id] = failure;
    _log.warning(
      'Plugin ${plugin.manifest.name} failed during $phase',
      error,
      stackTrace,
    );
    emitEvent(CommandEvent('plugin.error', data: failure.toJson()));
    _emitState(id);
    // This method can run inside a QuickJS/WASM host callback. Disposing that
    // runtime before its current dispatch unwinds can deadlock the command bus.
    // Mark it failed and stop feeding it events; a later close/remove/clear
    // command owns runtime disposal from outside the callback stack.
    _interconnectObservers.remove(id);
    _rawProtocolObservers.remove(id);
  }

  Future<void> close() async {
    _closed = true;
    await _interconnectSubscription.cancel();
    await _rawProtocolSubscription.cancel();
    await _closeActiveRuntime();
    _runtimeStarts.clear();
    for (final host in _wasmHosts.values) {
      await host.dispose();
    }
    _wasmHosts.clear();
    final runtimes = {_quickJsRuntime, _wasmRuntime}.whereType<PluginRuntime>();
    for (final runtime in runtimes) {
      await runtime.close();
    }
    _quickJsRuntime = null;
    _wasmRuntime = null;
    for (final completer in _hostRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(StateError('Plugin host is closing'));
      }
    }
    _hostRequests.clear();
    _dio.close(force: true);
    await (await _storage).close();
  }
}

class PluginExecutionFailure {
  const PluginExecutionFailure({
    required this.pluginId,
    required this.pluginName,
    required this.phase,
    required this.message,
    required this.occurredAt,
  });

  final String pluginId;
  final String pluginName;
  final String phase;
  final String message;
  final DateTime occurredAt;

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'pluginName': pluginName,
    'phase': phase,
    'message': message,
    'occurredAt': occurredAt.toIso8601String(),
  };
}

class PluginExecutionException implements Exception {
  const PluginExecutionException(this.pluginId, this.pluginName, this.message);

  factory PluginExecutionException.fromFailure(
    PluginExecutionFailure failure,
  ) => PluginExecutionException(
    failure.pluginId,
    failure.pluginName,
    failure.message,
  );

  final String pluginId;
  final String pluginName;
  final String message;

  @override
  String toString() => '$pluginName: $message';
}

class _PluginProvider {
  const _PluginProvider({
    required this.pluginId,
    required this.id,
    required this.name,
    this.categories,
    required this.query,
    required this.detail,
    required this.download,
  });

  final String pluginId;
  final String id;
  final String name;
  final String? categories;
  final String query;
  final String detail;
  final String download;

  factory _PluginProvider.fromJson(String pluginId, Map<String, Object?> json) {
    String required(String key) {
      final value = json[key]?.toString() ?? '';
      if (value.isEmpty) throw FormatException('Provider $key is required');
      return value;
    }

    final id = required('id');
    if (!RegExp(r'^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*)+$').hasMatch(id)) {
      throw FormatException('Invalid provider ID: $id');
    }
    return _PluginProvider(
      pluginId: pluginId,
      id: id,
      name: required('name'),
      categories: json['categories']?.toString(),
      query: required('query'),
      detail: required('detail'),
      download: required('download'),
    );
  }

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'id': id,
    'name': name,
    if (categories != null) 'categories': categories,
    'query': query,
    'detail': detail,
    'download': download,
  };
}
