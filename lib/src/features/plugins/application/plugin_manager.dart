import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:charset/charset.dart' as charset;
import 'package:dio/dio.dart';
import 'package:enough_convert/enough_convert.dart' as enough;
import 'package:flutter/foundation.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime_factory.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage_factory.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';

class PluginManager {
  PluginManager({
    required this.deviceManager,
    required this.readDeviceState,
    required this.emitEvent,
  }) {
    _interconnectSubscription = deviceManager.interconnectMessages.listen((
      message,
    ) {
      final payload = utf8.decode(message.payload, allowMalformed: true);
      _log.info(
        'dispatching interconnect message from ${message.pkgName} '
        '(${message.payload.length} bytes) to ${_runtimes.length} plugins',
      );
      for (final entry in _runtimes.entries) {
        unawaited(
          entry.value.dispatchEvent(
            'onQAICMessage_${message.pkgName}',
            payload,
          ),
        );
      }
    });
  }

  static final _log = getLogger('PluginManager');

  final DeviceManager deviceManager;
  final DeviceManagerState Function() readDeviceState;
  final void Function(CommandEvent event) emitEvent;
  final _plugins = <String, InstalledPlugin>{};
  final _runtimes = <String, PluginRuntime>{};
  final _runtimeStarts = <String, Future<PluginRuntime>>{};
  final _uiNodes = <String, List<Map<String, Object?>>>{};
  final _openPages = <String, List<Map<String, Object?>>>{};
  final _virtualFiles = <String, _PluginFile>{};
  final _hostRequests = <String, Completer<Map<String, Object?>>>{};
  final _providers = <String, _PluginProvider>{};
  final _dio = Dio();
  final _installer = ResourceInstallService();
  late final Future<PluginStorage> _storage = createPluginStorage();
  late final StreamSubscription _interconnectSubscription;
  Future<void>? _initialization;
  var _requestSequence = 0;
  var _closed = false;

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
    Timer.run(_startInstalledPlugins);
  }

  void _startInstalledPlugins() {
    if (_closed) return;
    for (final plugin in _plugins.values.toList(growable: false)) {
      unawaited(
        _ensureRuntime(plugin.manifest.id).then<void>(
          (_) {},
          onError: (Object error, StackTrace stackTrace) => _log.warning(
            'Unable to start plugin ${plugin.manifest.name}',
            error,
            stackTrace,
          ),
        ),
      );
    }
  }

  Future<List<Map<String, Object?>>> list({bool includeIcons = true}) async {
    await initialize();
    return _plugins.values
        .map((plugin) => plugin.summaryJson(includeIcon: includeIcons))
        .toList(growable: false);
  }

  Future<Map<String, Object?>> install(
    Uint8List bytes, {
    bool includeIcon = true,
  }) async {
    await initialize();
    final package = const AbPluginPackageReader().read(bytes);
    final id = package.manifest.id;
    final config = _plugins[id]?.config ?? const <String, Object?>{};
    await _closeRuntime(id);
    final plugin = await (await _storage).install(package, config: config);
    _plugins[id] = plugin;
    _emitState(id);
    unawaited(
      _ensureRuntime(id).then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) => _log.warning(
          'Unable to start plugin ${plugin.manifest.name}',
          error,
          stackTrace,
        ),
      ),
    );
    return plugin.summaryJson(includeIcon: includeIcon);
  }

  Future<Map<String, Object?>> get(String id) async {
    await initialize();
    final plugin = _requirePlugin(id);
    return {
      ...plugin.summaryJson(),
      'ui': _uiNodes[id] ?? const [],
      if (_openPages[id] != null) 'page': _openPages[id],
    };
  }

  Future<List<Map<String, Object?>>> open(String id) async {
    await initialize();
    await _ensureRuntime(id);
    return _uiNodes[id] ?? const [];
  }

  Future<List<Map<String, Object?>>> invoke(
    String id,
    String callbackId,
    String? value,
  ) async {
    final runtime = await _ensureRuntime(id);
    await runtime.invokeCallback(callbackId, value);
    return _uiNodes[id] ?? const [];
  }

  Future<void> remove(String id) async {
    await initialize();
    _requirePlugin(id);
    await _closeRuntime(id);
    await (await _storage).removePlugin(id);
    _plugins.remove(id);
    _uiNodes.remove(id);
    _openPages.remove(id);
    _providers.removeWhere((_, provider) => provider.pluginId == id);
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
    List<String> arguments,
  ) async {
    final provider = _providers[providerName];
    if (provider == null) throw StateError('Plugin provider not found');
    final runtime = await _ensureRuntime(provider.pluginId);
    if (operation == 'categories' && provider.getCategories == null) {
      return '[]';
    }
    final callback = switch (operation) {
      'categories' => provider.getCategories!,
      'page' => provider.getPage,
      'item' => provider.getItem,
      'download' => provider.download,
      _ => throw StateError('Unknown provider operation: $operation'),
    };
    return runtime.invokeRegistered(callback, arguments);
  }

  Future<List<Map<String, Object?>>> providers() async {
    await initialize();
    await Future.wait(
      _plugins.keys.map((id) async {
        try {
          await _ensureRuntime(id);
        } catch (_) {
          // A broken plugin must not hide providers registered by other plugins
        }
      }),
    );
    return _providers.values
        .map((provider) => provider.toJson())
        .toList(growable: false);
  }

  Uint8List? virtualFileBytes(String path) => _virtualFiles[path]?.bytes;

  String? virtualFileName(String path) => _virtualFiles[path]?.name;

  Future<PluginRuntime> _ensureRuntime(String id) async {
    await initialize();
    if (_closed) throw StateError('Plugin manager is closed');
    final pending = _runtimeStarts[id];
    if (pending != null) return pending;
    final existing = _runtimes[id];
    if (existing != null) return existing;
    final start = _startRuntime(id);
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
    final runtime = createPluginRuntime();
    _runtimes[id] = runtime;
    try {
      await runtime.start(
        pluginId: id,
        pluginName: plugin.manifest.name,
        pluginVersion: plugin.manifest.version,
        runtimeVersion: BuildInfoService.appVersion,
        source: plugin.source,
        hostCall: (method, arguments) =>
            _handleHostCall(plugin, method, arguments),
      );
      return runtime;
    } catch (_) {
      if (identical(_runtimes[id], runtime)) _runtimes.remove(id);
      _providers.removeWhere((_, provider) => provider.pluginId == id);
      await runtime.close();
      rethrow;
    }
  }

  Future<void> _closeRuntime(String id) async {
    _runtimeStarts.remove(id);
    await _runtimes.remove(id)?.close();
    _providers.removeWhere((_, provider) => provider.pluginId == id);
  }

  FutureOr<Object?> _handleHostCall(
    InstalledPlugin plugin,
    String method,
    List<Object?> arguments,
  ) {
    final id = plugin.manifest.id;
    final permission = _permissionFor(method);
    if (permission != null) _requirePermission(plugin, permission);

    return switch (method) {
      'permission.require' => _checkPermission(
        plugin,
        arguments.firstOrNull?.toString() ?? '',
      ),
      'console.log' || 'console.info' => _pluginLog(id, arguments, 'info'),
      'console.warn' => _pluginLog(id, arguments, 'warning'),
      'console.error' => _pluginLog(id, arguments, 'severe'),
      'config.readConfig' => jsonEncode(_requirePlugin(id).config),
      'config.writeConfig' => _writeConfig(id, arguments),
      'debug.sendRaw' => _sendRaw(arguments),
      'device.getDeviceList' => jsonEncode(
        readDeviceState().pairedDevices
            .map((device) => {'name': device.name, 'addr': device.addr})
            .toList(growable: false),
      ),
      'device.getDeviceState' => _getDeviceState(arguments),
      'device.modifyDeviceState' => _modifyDeviceState(arguments),
      'device.disconnectDevice' => deviceManager.disconnect(),
      'filesystem.pickFile' => _pickFile(id, arguments),
      'filesystem.readFile' => _readFile(arguments),
      'filesystem.unloadFile' => _unloadFile(arguments),
      'sandbox.readFile' => _readSandboxFile(id, arguments),
      'sandbox.writeFile' => _writeSandboxFile(id, arguments),
      'sandbox.listDirectory' => _listSandboxDirectory(id, arguments),
      'sandbox.stat' => _statSandboxPath(id, arguments),
      'sandbox.remove' => _removeSandboxPath(id, arguments),
      'installer.addThirdPartyAppToQueue' => _installVirtualFile(
        arguments,
        LocalDeviceInstallType.app,
      ),
      'installer.addWatchFaceToQueue' => _installVirtualFile(
        arguments,
        LocalDeviceInstallType.watchface,
      ),
      'installer.addFirmwareToQueue' => _installVirtualFile(
        arguments,
        LocalDeviceInstallType.firmware,
      ),
      'interconnect.sendQAICMessage' => _sendInterconnect(id, arguments),
      'network.fetch' => _networkFetch(arguments),
      'provider.registerCommunityProvider' => _registerProvider(id, arguments),
      'thirdpartyapp.launchQA' => _launchQuickApp(arguments),
      'thirdpartyapp.getThirdPartyAppList' => _getQuickApps(),
      'ui.updatePluginSettingsUI' => _updateSettingsUi(id, arguments),
      'ui.openPageWithNodes' => _openPageWithNodes(id, arguments),
      'ui.openPageWithUrl' => _openUrl(id, arguments),
      _ => throw UnsupportedError('Unsupported ABv1 API: $method'),
    };
  }

  String? _permissionFor(String method) {
    if (method.startsWith('config.')) return 'config';
    if (method.startsWith('debug.')) return 'debug';
    if (method.startsWith('device.')) return 'device';
    if (method.startsWith('filesystem.')) return 'filesystem';
    if (method.startsWith('sandbox.')) return 'filesystem';
    if (method.startsWith('installer.')) return 'installer';
    if (method.startsWith('interconnect.')) return 'interconnect';
    if (method.startsWith('network.')) return 'network';
    if (method.startsWith('provider.')) return 'provider';
    if (method.startsWith('thirdpartyapp.')) return 'thirdpartyapp';
    if (method.startsWith('ui.')) return 'ui';
    return null;
  }

  void _requirePermission(InstalledPlugin plugin, String permission) {
    if (!plugin.manifest.permissions.contains(permission)) {
      throw StateError(
        'Plugin ${plugin.manifest.name} did not declare $permission permission',
      );
    }
  }

  Object? _checkPermission(InstalledPlugin plugin, String permission) {
    _requirePermission(plugin, permission);
    return null;
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

  Future<void> _writeConfig(String id, List<Object?> arguments) async {
    final raw = jsonDecode(arguments.firstOrNull?.toString() ?? '{}');
    if (raw is! Map) {
      throw const FormatException('Plugin config must be an object');
    }
    final current = _requirePlugin(id);
    final config = raw.cast<String, Object?>();
    await (await _storage).writeConfig(id, config);
    _plugins[id] = current.copyWith(config: config);
  }

  Future<void> _sendRaw(List<Object?> arguments) async {
    final payload = base64Decode(arguments.firstOrNull?.toString() ?? '');
    await deviceManager.sendRaw(payload);
  }

  String _getDeviceState(List<Object?> arguments) {
    final address = arguments.firstOrNull?.toString();
    final device = readDeviceState().pairedDevices
        .where((candidate) => candidate.addr == address)
        .firstOrNull;
    if (device == null) throw StateError('Device not found: $address');
    return jsonEncode({
      'name': device.name,
      'addr': device.addr,
      'authkey': device.authkey ?? '',
      'bleservice': {'recv': '', 'sent': ''},
      'max_frame_size': 0,
      'sec_keys': null,
      'network_mtu': 0,
      'codename': device.codename ?? '',
    });
  }

  Object? _modifyDeviceState(List<Object?> arguments) {
    final address = arguments.firstOrNull?.toString();
    final json = jsonDecode(arguments.elementAtOrNull(1)?.toString() ?? '{}');
    if (json is! Map) throw const FormatException('Invalid device state');
    final values = json.cast<String, dynamic>();
    final existing = readDeviceState().pairedDevices
        .where((candidate) => candidate.addr == address)
        .firstOrNull;
    if (existing == null) throw StateError('Device not found: $address');
    final device = existing.copyWith(
      name: values['name']?.toString() ?? existing.name,
      authkey: values['authkey']?.toString() ?? existing.authkey,
      codename: values['codename']?.toString() ?? existing.codename,
    );
    if (address != values['addr']?.toString()) {
      throw const FormatException('Device address mismatch');
    }
    unawaited(deviceManager.importSharedDevice(device));
    return null;
  }

  Future<String?> _pickFile(String pluginId, List<Object?> arguments) async {
    final options = _jsonMap(arguments.firstOrNull);
    _log.info('plugin $pluginId requested a file picker');
    final response = await _requestHost(pluginId, 'pickFile', {
      'options': options,
    });
    if (response['cancelled'] == true) return null;
    final bytes = Uint8List.fromList(
      (response['bytes'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt() & 0xff)
              .toList(growable: false) ??
          const [],
    );
    final name = response['name']?.toString() ?? 'plugin-file';
    final fileId = 'zbfile:${DateTime.now().microsecondsSinceEpoch}:$name';
    final decodeText = options['decode_text'] == true;
    final text = decodeText
        ? _decodePluginText(bytes, options['encoding']?.toString())
        : null;
    _virtualFiles[fileId] = _PluginFile(name: name, bytes: bytes, text: text);
    return jsonEncode({
      'path': fileId,
      'size': bytes.length,
      'text_len': text?.runes.length ?? bytes.length,
    });
  }

  Future<String> _readFile(List<Object?> arguments) async {
    final fileId = arguments.firstOrNull?.toString() ?? '';
    final file = _virtualFiles[fileId];
    if (file == null) throw StateError('File was not selected by this plugin');
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final offset = (options['offset'] as num?)?.toInt() ?? 0;
    final decodeText = options['decode_text'] == true;
    if (decodeText) {
      final runes = (file.text ?? utf8.decode(file.bytes, allowMalformed: true))
          .runes
          .toList();
      final length = (options['len'] as num?)?.toInt() ?? runes.length;
      if (offset < 0 || offset > runes.length) {
        throw RangeError('Invalid offset');
      }
      return String.fromCharCodes(
        runes.sublist(offset, (offset + length).clamp(offset, runes.length)),
      );
    }
    final length = (options['len'] as num?)?.toInt() ?? file.bytes.length;
    if (offset < 0 || offset > file.bytes.length) {
      throw RangeError('Invalid offset');
    }
    return base64Encode(
      file.bytes.sublist(
        offset,
        (offset + length).clamp(offset, file.bytes.length),
      ),
    );
  }

  bool _unloadFile(List<Object?> arguments) {
    return _virtualFiles.remove(arguments.firstOrNull?.toString()) != null;
  }

  Future<String> _readSandboxFile(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final options = _jsonMap(arguments.elementAtOrNull(1));
    final bytes = await (await _storage).readFile(pluginId, path);
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
    final value = arguments.elementAtOrNull(1)?.toString() ?? '';
    final options = _jsonMap(arguments.elementAtOrNull(2));
    final bytes = switch (options['encoding']?.toString().toLowerCase()) {
      'utf8' || 'utf-8' || 'text' => Uint8List.fromList(utf8.encode(value)),
      null || '' || 'base64' => base64Decode(value),
      final encoding => throw FormatException(
        'Unsupported plugin file encoding: $encoding',
      ),
    };
    await (await _storage).writeFile(pluginId, path, bytes);
  }

  Future<String> _listSandboxDirectory(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final entries = await (await _storage).listDirectory(pluginId, path);
    return jsonEncode(entries.map((entry) => entry.toJson()).toList());
  }

  Future<String> _statSandboxPath(
    String pluginId,
    List<Object?> arguments,
  ) async {
    final path = PluginStoragePath.parse(
      arguments.firstOrNull?.toString() ?? '',
    );
    final stat = await (await _storage).stat(pluginId, path);
    return jsonEncode(stat?.toJson());
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

  String _decodePluginText(Uint8List bytes, String? requestedEncoding) {
    final name = requestedEncoding?.trim().toLowerCase();
    Encoding? encoding;
    if (name != null && name.isNotEmpty && name != 'undefined') {
      encoding = name == 'big5' ? enough.big5 : charset.Charset.getByName(name);
      if (encoding == null) {
        throw FormatException('Unsupported text encoding: $requestedEncoding');
      }
    }
    encoding ??= charset.Charset.detect(
      bytes,
      defaultEncoding: utf8,
      orders: [
        utf8,
        charset.gbk,
        enough.big5,
        charset.shiftJis,
        charset.eucJp,
        charset.eucKr,
        charset.windows1252,
        charset.latin2,
      ],
    );
    return (encoding ?? utf8).decode(bytes);
  }

  Future<void> _installVirtualFile(
    List<Object?> arguments,
    LocalDeviceInstallType type,
  ) async {
    final fileId = arguments.firstOrNull?.toString() ?? '';
    final file = _virtualFiles[fileId];
    if (file == null) throw StateError('File was not selected by this plugin');
    await _installer.installLocalPayload(
      type: type,
      fileName: file.name,
      bytes: file.bytes,
      deviceManager: deviceManager,
      onProgress: (progress) => emitEvent(
        CommandEvent('plugin.installProgress', data: {'progress': progress}),
      ),
    );
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
    try {
      await deviceManager.sendInterconnectMessage(packageName, payload);
      _log.info(
        'plugin $pluginId interconnect message queued for $packageName',
      );
    } catch (error, stackTrace) {
      _log.warning(
        'plugin $pluginId failed to send interconnect message to $packageName',
        error,
        stackTrace,
      );
      rethrow;
    }
  }

  Future<Map<String, Object?>> _networkFetch(List<Object?> arguments) async {
    final url = arguments.firstOrNull?.toString() ?? '';
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
      final response = await _dio.request<List<int>>(
        url,
        data: requestBody,
        options: Options(
          method: options['method']?.toString() ?? 'GET',
          headers: (options['headers'] as Map?)?.cast<String, Object?>(),
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final bytes = Uint8List.fromList(response.data ?? const []);
      return {
        'status': response.statusCode ?? 0,
        'headers': jsonEncode(
          response.headers.map.map(
            (key, values) => MapEntry(key, values.join(',')),
          ),
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
    _providers[provider.name] = provider;
    emitEvent(CommandEvent('plugin.provider', data: provider.toJson()));
    return null;
  }

  Future<void> _launchQuickApp(List<Object?> arguments) async {
    final raw = _jsonMap(arguments.firstOrNull);
    final packageName =
        raw['package_name']?.toString() ?? raw['packageName']?.toString() ?? '';
    await deviceManager.fetchApps();
    final app = readDeviceState().apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw StateError('Quick app is not installed: $packageName');
    }
    await deviceManager.openApp(
      app,
      page: arguments.elementAtOrNull(1)?.toString() ?? '',
    );
  }

  Future<String> _getQuickApps() async {
    await deviceManager.fetchApps();
    return jsonEncode(
      readDeviceState().apps
          .map(
            (app) => {
              'package_name': app.packageName,
              'fingerprint': app.fingerprint,
              'version_code': app.versionCode,
              'can_remove': app.canRemove,
              'app_name': app.appName,
            },
          )
          .toList(growable: false),
    );
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

  Object? _openUrl(String id, List<Object?> arguments) {
    final url = arguments.firstOrNull?.toString() ?? '';
    emitEvent(
      CommandEvent(
        'plugin.hostRequest',
        data: {'pluginId': id, 'type': 'openUrl', 'url': url},
      ),
    );
    return null;
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

  Future<void> close() async {
    _closed = true;
    await _interconnectSubscription.cancel();
    for (final runtime in _runtimes.values) {
      await runtime.close();
    }
    _runtimes.clear();
    _runtimeStarts.clear();
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

class _PluginFile {
  const _PluginFile({required this.name, required this.bytes, this.text});
  final String name;
  final Uint8List bytes;
  final String? text;
}

class _PluginProvider {
  const _PluginProvider({
    required this.pluginId,
    required this.name,
    this.getCategories,
    required this.getPage,
    required this.getItem,
    required this.download,
  });

  final String pluginId;
  final String name;
  final String? getCategories;
  final String getPage;
  final String getItem;
  final String download;

  factory _PluginProvider.fromJson(String pluginId, Map<String, Object?> json) {
    String required(String key) {
      final value = json[key]?.toString() ?? '';
      if (value.isEmpty) throw FormatException('Provider $key is required');
      return value;
    }

    return _PluginProvider(
      pluginId: pluginId,
      name: required('name'),
      getCategories: json['fn_get_categories']?.toString(),
      getPage: required('fn_get_page'),
      getItem: required('fn_get_item'),
      download: required('fn_download'),
    );
  }

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'name': name,
    if (getCategories != null) 'fn_get_categories': getCategories,
    'fn_get_page': getPage,
    'fn_get_item': getItem,
    'fn_download': download,
  };
}
