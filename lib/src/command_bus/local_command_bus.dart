import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:zerobox/src/data/huami/huami_app_store_resource_provider.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_service.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/community_resource_codec.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';
import 'package:zerobox/src/host/application_host.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';

class LocalCommandBus implements ZeroBoxCommandBus, ActiveOperationController {
  LocalCommandBus(this.container) {
    _deviceManagerSubscription = container.listen<DeviceManagerState>(
      deviceManagerProvider,
      (_, state) => _events.add(
        CommandEvent(
          'device.state',
          data: {'state': _wireValue(_deviceStateJson(state))},
        ),
      ),
      fireImmediately: true,
    );
    _logSubscription = zeroBoxLogStream.listen(
      (line) => _events.add(CommandEvent('log', data: {'message': line})),
    );
  }

  final ProviderContainer container;
  final _events = StreamController<CommandEvent>.broadcast();
  late final ProviderSubscription<DeviceManagerState>
  _deviceManagerSubscription;
  late final StreamSubscription<String> _logSubscription;
  bool _activeCommandCancelled = false;
  Future<void> _commandTail = Future<void>.value();

  DeviceManager get _manager => container.read(deviceManagerProvider.notifier);
  DeviceManagerState get _state => container.read(deviceManagerProvider);

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    final previous = _commandTail;
    final turn = Completer<void>();
    _commandTail = turn.future;
    await previous;
    try {
      return await _execute(command);
    } finally {
      turn.complete();
    }
  }

  Future<CommandResult> _execute(ZeroBoxCommand command) async {
    _activeCommandCancelled = false;
    try {
      final result = await _dispatch(command);
      return CommandResult.success(_wireValue(result));
    } on CommandFailure catch (error) {
      return CommandResult.failure(
        CommandError(error.code, error.message, details: error.details),
      );
    } catch (error, stackTrace) {
      getLogger(
        'LocalCommandBus',
      ).severe('Command ${command.method} failed', error, stackTrace);
      return CommandResult.failure(
        CommandError('internal', error.toString(), details: '$stackTrace'),
      );
    }
  }

  Object? _wireValue(Object? value) {
    if (value == null) return null;
    return jsonDecode(jsonEncode(value));
  }

  @override
  Future<void> cancelActiveOperation() async {
    _activeCommandCancelled = true;
    if (_state.connecting || _state.protocolState == ProtocolState.ready) {
      await _manager.disconnect();
    }
  }

  void _throwIfCancelled() {
    if (_activeCommandCancelled) {
      throw const CommandFailure('cancelled', 'Operation was cancelled');
    }
  }

  Future<Object?> _dispatch(ZeroBoxCommand command) => switch (command.method) {
    'status' => Future.value(_status()),
    'device.snapshot' => Future.value(_deviceStateJson(_state)),
    'device.paired' => Future.value(
      _state.pairedDevices.map(_deviceJson).toList(growable: false),
    ),
    'device.status' => Future.value(_status()),
    'device.connect' => _connect(command.params['device']?.toString()),
    'device.disconnect' => _disconnect(),
    'device.scan' => _scan(command.params),
    'device.scan.start' => _scanStart(command.params),
    'device.scan.stop' => _scanStop(),
    'device.info' => _deviceInfo(),
    'device.refresh.all' => _refreshDeviceData(),
    'device.refresh.battery' => _refreshBattery(),
    'device.refresh.system' => _refreshSystem(),
    'device.refresh.storage' => _refreshStorage(),
    'device.zeppos.find' => _setFindingZeppOsDevice(
      command.params['finding'] == true,
    ),
    'device.remove' => _removeDevice(command.params['device']?.toString()),
    'device.import' => _importDevice(command.params),
    'app.list' => _listApps(),
    'app.uninstall' => _uninstallApp(command.params['package']?.toString()),
    'app.launch' => _launchApp(command.params['package']?.toString()),
    'watchface.list' => _listWatchfaces(),
    'watchface.remove' => _removeWatchface(command.params['id']?.toString()),
    'watchface.set' => _setWatchface(command.params['id']?.toString()),
    'settings.list' => Future.value(_settingsList()),
    'settings.get' => Future.value(
      _settingsGet(command.params['key']?.toString()),
    ),
    'settings.set' => _withStateEvent(
      'settings.state',
      () => _settingsSet(command.params),
      () => _settingsList(),
    ),
    'resource.sources' => Future.value(
      CommunitySourceId.values
          .map(
            (source) => {'id': source.storageKey, 'name': source.displayName},
          )
          .toList(growable: false),
    ),
    'resource.list' || 'resource.search' => _resourceList(command.params),
    'resource.info' => _resourceInfo(command.params),
    'resource.devices' => _resourceDevices(command.params),
    'resource.probe' => _resourceProbe(command.params),
    'resource.bandbbs.categories' => _bandBbsCategories(),
    'resource.huami.publisher' => _huamiPublisher(command.params),
    'resource.download' => _resourceDownload(command.params, install: false),
    'resource.install' => _resourceDownload(command.params, install: true),
    'account.list' => Future.value(_accountList()),
    'account.status' => Future.value(
      _freshAccountStatus(command.params['provider']?.toString()),
    ),
    'account.credentials.get' => Future.value(
      _accountCredentials(command.params['provider']?.toString()),
    ),
    'account.credentials.set' => _setAccountCredentials(command.params),
    'account.login' => _withStateEvent(
      'account.state',
      () => _accountLogin(command.params),
      () => _accountList(),
    ),
    'account.xiaomi.complete' => _withStateEvent(
      'account.state',
      () => _completeXiaomiLogin(command.params),
      () => _accountList(),
    ),
    'account.bandbbs.callback' => _withStateEvent(
      'account.state',
      () => _bandBbsCallback(command.params),
      () => _accountList(),
    ),
    'account.logout' => _withStateEvent(
      'account.state',
      () => _accountLogout(command.params['provider']?.toString()),
      () => _accountList(),
    ),
    'logs.recent' => Future.value(recentZeroBoxLogs),
    'install.local' => _installLocal(command.params),
    _ => throw CommandFailure(
      'unknown_command',
      'Unknown command: ${command.method}',
    ),
  };

  Future<Object?> _withStateEvent(
    String event,
    Future<Object?> Function() operation,
    Object? Function() snapshot,
  ) async {
    final result = await operation();
    _events.add(CommandEvent(event, data: {'state': snapshot()}));
    return result;
  }

  Map<String, Object?> _status() {
    final current = _state.currentDevice;
    return {
      'connected': _state.protocolState == ProtocolState.ready,
      'protocolState': _state.protocolState.name,
      if (current != null) 'device': _deviceJson(current),
      if (_state.battery != null) 'battery': _state.battery!.capacity,
      if (_state.error != null) 'error': _state.error,
    };
  }

  Map<String, Object?> _deviceStateJson(DeviceManagerState state) => {
    if (state.currentDevice != null)
      'currentDevice': state.currentDevice!.toJson(),
    'pairedDevices': state.pairedDevices.map((item) => item.toJson()).toList(),
    'scannedDevices': state.scannedDevices
        .map((item) => item.toJson())
        .toList(),
    'scanning': state.scanning,
    'connecting': state.connecting,
    'connectStatus': state.connectStatus,
    'protocolState': state.protocolState.name,
    if (state.battery != null) 'battery': state.battery!.toJson(),
    if (state.systemInfo != null) 'systemInfo': state.systemInfo!.toJson(),
    'apps': state.apps.map((item) => item.toJson()).toList(),
    'watchfaces': state.watchfaces.map((item) => item.toJson()).toList(),
    if (state.error != null) 'error': state.error,
  };

  Future<Object?> _connect(String? requestedAddress) async {
    final paired = _state.pairedDevices;
    if (paired.isEmpty) {
      throw const CommandFailure('no_device', 'No paired devices found');
    }
    final target = requestedAddress == null || requestedAddress.isEmpty
        ? paired.first
        : paired.where((device) => device.addr == requestedAddress).firstOrNull;
    if (target == null) {
      throw CommandFailure(
        'no_device',
        'Paired device not found: $requestedAddress',
      );
    }
    if (_state.protocolState == ProtocolState.ready &&
        _state.currentDevice?.addr == target.addr) {
      return _deviceJson(target);
    }
    final authKey = target.authkey ?? '';
    if (authKey.isEmpty) {
      throw CommandFailure(
        'connection',
        'Device has no authentication key: ${target.addr}',
      );
    }
    _events.add(CommandEvent('connecting', data: _deviceJson(target)));
    await _manager.connect(
      target.addr,
      target.name,
      authKey,
      connectType: target.connectType,
    );
    if (_state.protocolState != ProtocolState.ready) {
      final reason = _state.error;
      throw CommandFailure(
        'connection',
        reason == null || reason.isEmpty
            ? 'Device did not become ready: ${target.addr}'
            : 'Failed to connect ${target.addr}: $reason',
      );
    }
    _events.add(CommandEvent('connected', data: _deviceJson(target)));
    return _deviceJson(_state.currentDevice ?? target);
  }

  Future<Object?> _disconnect() async {
    await _manager.disconnect();
    _events.add(const CommandEvent('disconnected'));
    return const {'disconnected': true};
  }

  Future<Object?> _scan(Map<String, Object?> params) async {
    final seconds = int.tryParse(params['timeout']?.toString() ?? '') ?? 10;
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    await Future<void>.delayed(Duration(seconds: seconds.clamp(1, 15)));
    await _manager.stopBluetoothScan();
    return _state.scannedDevices
        .map(
          (device) => {
            'name': device.name,
            'address': device.addr,
            'connectType': device.connectType,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _scanStart(Map<String, Object?> params) async {
    final connectType = switch (params['connectType']?.toString()) {
      'spp' => ConnectType.spp,
      _ => ConnectType.ble,
    };
    await _manager.startBluetoothScan(connectType: connectType);
    return {'scanning': _state.scanning};
  }

  Future<Object?> _scanStop() async {
    await _manager.stopBluetoothScan();
    return _deviceStateJson(_state);
  }

  Future<Object?> _removeDevice(String? address) async {
    if (address == null || address.isEmpty) {
      throw const CommandFailure('usage', 'Missing device address');
    }
    await _manager.removeDevice(address);
    return _deviceStateJson(_state);
  }

  Future<Object?> _importDevice(Map<String, Object?> params) async {
    final raw = params['device'];
    if (raw is! Map) {
      throw const CommandFailure('usage', 'Missing device payload');
    }
    await _manager.importSharedDevice(
      MiWearState.fromJson(raw.cast<String, dynamic>()),
    );
    return _deviceStateJson(_state);
  }

  Future<Object?> _deviceInfo() async {
    await _ensureConnected(null);
    await _manager.refreshDeviceData();
    final device = _state.currentDevice;
    final info = _state.systemInfo;
    final battery = _state.battery;
    return {
      if (device != null)
        'device': {
          'name': device.name,
          'address': device.addr,
          if (device.authkey != null) 'authKey': device.authkey,
          'connectionType': device.connectType,
          if (device.codename != null) 'codename': device.codename,
        },
      if (info != null)
        'system': {
          'model': info.model,
          'imei': info.imei,
          'firmwareVersion': info.firmwareVersion,
          'serialNumber': info.serialNumber,
          if (info.storageInfo != null)
            'storage': {
              'used': info.storageInfo!.used,
              'total': info.storageInfo!.total,
              'free': info.storageInfo!.total - info.storageInfo!.used,
            },
        },
      if (battery != null)
        'status': {
          'battery': battery.capacity,
          'chargeStatus': battery.chargeStatus.name,
          if (battery.chargeInfo != null)
            'chargeInfo': {
              'state': battery.chargeInfo!.state,
              if (battery.chargeInfo!.timestamp != null)
                'timestamp': battery.chargeInfo!.timestamp,
            },
        },
    };
  }

  Future<Object?> _refreshBattery() async {
    await _ensureConnected(null);
    await _manager.refreshBattery();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshDeviceData() async {
    await _ensureConnected(null);
    await _manager.refreshDeviceData();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshSystem() async {
    await _ensureConnected(null);
    await _manager.fetchSystemInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _refreshStorage() async {
    await _ensureConnected(null);
    await _manager.fetchStorageInfo();
    return _deviceStateJson(_state);
  }

  Future<Object?> _setFindingZeppOsDevice(bool finding) async {
    await _ensureConnected(null);
    await _manager.setFindingZeppOsDevice(finding);
    return {'finding': finding};
  }

  Future<Object?> _listApps() async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    return _state.apps
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

  Future<Object?> _listWatchfaces() async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    return _state.watchfaces
        .map(
          (face) => {
            'id': face.id,
            'name': face.name,
            'current': face.isCurrent,
            'canRemove': face.canRemove,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _uninstallApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.uninstallApp(app);
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await _manager.fetchApps();
      if (_state.apps.every(
        (candidate) => candidate.packageName != packageName,
      )) {
        return {'removed': packageName};
      }
    }
    throw CommandFailure(
      'operation_failed',
      'App is still installed after removal request: $packageName',
    );
  }

  Future<Object?> _launchApp(String? packageName) async {
    await _ensureConnected(null);
    await _manager.fetchApps();
    final app = _state.apps
        .where((candidate) => candidate.packageName == packageName)
        .firstOrNull;
    if (app == null) {
      throw CommandFailure('not_found', 'App not found: $packageName');
    }
    await _manager.openApp(app);
    return {'launched': packageName};
  }

  Future<Object?> _removeWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.uninstallWatchface(face);
    return {'removed': id};
  }

  Future<Object?> _setWatchface(String? id) async {
    final face = await _watchface(id);
    await _manager.setWatchface(face);
    return {'current': id};
  }

  Future<WatchfaceInfo> _watchface(String? id) async {
    await _ensureConnected(null);
    await _manager.fetchWatchfaces();
    final face = _state.watchfaces
        .where((candidate) => candidate.id == id)
        .firstOrNull;
    if (face == null) {
      throw CommandFailure('not_found', 'Watchface not found: $id');
    }
    return face;
  }

  static const _settingKeys = <String>{
    'auto_reconnect',
    'auto_install',
    'disable_auto_clean',
    'community_source',
    'astrobox_cdn',
    'bandbbs_load_previews',
    'bandbbs_show_all_categories',
  };

  Map<String, Object?> _settingsList() => {
    for (final key in _settingKeys) key: _readSetting(key),
  };

  Object? _settingsGet(String? key) {
    _validateSettingKey(key);
    return {'key': key, 'value': _readSetting(key!)};
  }

  Future<Object?> _settingsSet(Map<String, Object?> params) async {
    final key = params['key']?.toString();
    _validateSettingKey(key);
    final raw = params['value'];
    final prefs = SharedPrefsService.instance;
    if (raw == null) {
      await prefs.remove(key!);
    } else if (raw is bool) {
      await prefs.setBool(key!, raw);
    } else if (raw is int) {
      await prefs.setInt(key!, raw);
    } else {
      await prefs.setString(key!, raw.toString());
    }
    container.invalidate(appSettingsProvider);
    return {'key': key, 'value': _readSetting(key)};
  }

  void _validateSettingKey(String? key) {
    if (key == null || !_settingKeys.contains(key)) {
      throw CommandFailure('usage', 'Unsupported setting key: $key');
    }
  }

  Object? _readSetting(String key) {
    final prefs = SharedPrefsService.instance;
    return switch (key) {
      'auto_reconnect' ||
      'auto_install' ||
      'disable_auto_clean' ||
      'bandbbs_load_previews' ||
      'bandbbs_show_all_categories' => prefs.getBool(key),
      'community_source' || 'astrobox_cdn' => prefs.getString(key),
      _ => null,
    };
  }

  Future<Object?> _installLocal(Map<String, Object?> params) async {
    final path = params['path']?.toString() ?? '';
    final typeName = params['type']?.toString() ?? '';
    if (path.isEmpty) {
      throw const CommandFailure('usage', 'Missing resource path');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw CommandFailure('file', 'File not found: $path');
    }
    var installed = false;
    try {
      final bytes = await file.readAsBytes();
      final service = container.read(resourceInstallServiceProvider);
      final type = switch (typeName) {
        'auto' => service.detectLocalInstallType(
          file.uri.pathSegments.last,
          bytes,
        ),
        'quickapp' || 'app' => LocalDeviceInstallType.app,
        'watchface' => LocalDeviceInstallType.watchface,
        'firmware' => LocalDeviceInstallType.firmware,
        _ => null,
      };
      if (type == null) {
        throw CommandFailure(
          'usage',
          'Unsupported or unrecognized install type: $typeName',
        );
      }
      _throwIfCancelled();
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      await service.installLocalPayload(
        type: type,
        fileName: file.uri.pathSegments.last,
        bytes: bytes,
        deviceManager: _manager,
        onProgress: (progress) => _events.add(
          CommandEvent('progress', data: {'progress': progress, 'path': path}),
        ),
      );
      installed = true;
      _events.add(CommandEvent('completed', data: {'path': path}));
      return {'installed': true, 'path': path, 'type': type.name};
    } finally {
      if (installed && params['deleteAfter'] == true && await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Object?> _resourceList(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final source = _source(params['source']?.toString());
    final catalog = container.read(
      localCommunityCatalogProviderForSource(source),
    );
    final type = _resourceType(params['type']?.toString(), required: false);
    final devices = params['devices'];
    final selectedDevices = devices is List
        ? devices.map((item) => item.toString()).toSet()
        : {
            if (params['device']?.toString().isNotEmpty == true)
              params['device'].toString(),
          };
    final page = await catalog.getPage(
      CommunityResourceQuery(
        page: int.tryParse(params['page']?.toString() ?? '') ?? 0,
        pageSize: int.tryParse(params['pageSize']?.toString() ?? '') ?? 30,
        query: params['query']?.toString() ?? '',
        sort: CommunitySortRule.values.firstWhere(
          (value) => value.name == params['sort']?.toString(),
          orElse: () => CommunitySortRule.time,
        ),
        type: type,
        hidePaid: params['hidePaid'] == true,
        hideForcePaid: params['hideForcePaid'] == true,
        selectedDevices: selectedDevices,
      ),
    );
    return {
      'page': page.page,
      'hasMore': page.hasMore,
      if (page.total != null) 'total': page.total,
      'items': page.items.map(_resourceJson).toList(growable: false),
    };
  }

  Future<Object?> _resourceDevices(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final source = _source(params['source']?.toString());
    final catalog = container.read(
      localCommunityCatalogProviderForSource(source),
    );
    final devices = await catalog.getDevices();
    return devices
        .map(
          (device) => {
            'codename': device.codename,
            'name': device.name,
            'description': device.description,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _resourceProbe(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final source = _source(params['source']?.toString());
    final catalog = container.read(
      localCommunityCatalogProviderForSource(source),
    );
    final raw = (params['file'] as Map).cast<String, Object?>();
    return catalog.probeDownloadSize(communityResourceFileFromJson(raw));
  }

  Future<Object?> _bandBbsCategories() async {
    _reloadPersistedAccounts();
    final catalog =
        container.read(
              localCommunityCatalogProviderForSource(CommunitySourceId.bandbbs),
            )
            as BandBbsCatalog;
    final tree = await catalog.getCategoryTree();
    Map<String, Object?> encode(BandBbsCategoryNode node) => {
      'id': node.id,
      'title': node.title,
      'resourceCount': node.resourceCount,
      'children': node.children.map(encode).toList(growable: false),
    };
    return tree.map(encode).toList(growable: false);
  }

  Future<Object?> _huamiPublisher(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final catalog =
        container.read(
              localCommunityCatalogProviderForSource(
                CommunitySourceId.huamiAppStore,
              ),
            )
            as HuamiAppStoreCatalog;
    final resources = await catalog.getPublisherResources(
      publisherName: params['publisher']?.toString() ?? '',
    );
    return resources.map(communityResourceToJson).toList(growable: false);
  }

  Future<Object?> _resourceInfo(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final ref = _resourceRef(params);
    final catalog = container.read(
      localCommunityCatalogProviderForSource(ref.source),
    );
    final detail = await catalog.getDetail(ref);
    _throwIfCancelled();
    return _resourceDetailJson(detail);
  }

  Future<Object?> _resourceDownload(
    Map<String, Object?> params, {
    required bool install,
  }) async {
    _reloadPersistedAccounts();
    final ref = _resourceRef(params);
    final catalog = container.read(
      localCommunityCatalogProviderForSource(ref.source),
    );
    final detail = await catalog.getDetail(ref);
    if (detail.files.isEmpty) {
      throw CommandFailure(
        'not_found',
        'Resource has no downloadable files: ${ref.key}',
      );
    }
    final requestedFile = params['file']?.toString();
    final file = requestedFile == null
        ? detail.files.first
        : detail.files
              .where((candidate) => candidate.id == requestedFile)
              .firstOrNull;
    if (file == null) {
      throw CommandFailure(
        'not_found',
        'Resource file not found: $requestedFile',
      );
    }
    final service = container.read(resourceInstallServiceProvider);
    final downloaded = await service.downloadResource(
      resource: detail,
      file: file,
      catalog: catalog,
      targetDevice: params['targetDevice']?.toString(),
      onUpdate: (status, progress, error) => _events.add(
        CommandEvent(
          status.name,
          data: {'progress': progress, if (error != null) 'error': error},
        ),
      ),
    );
    _throwIfCancelled();
    if (downloaded == null) {
      throw const CommandFailure('download', 'Resource download failed');
    }
    if (install) {
      await _ensureConnected(params['device']?.toString());
      _throwIfCancelled();
      await service.installLocalPayload(
        type: switch (detail.type) {
          CommunityResourceType.quickApp => LocalDeviceInstallType.app,
          CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
          CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
          _ => throw CommandFailure(
            'validation',
            'Resource type cannot be installed: ${detail.type.name}',
          ),
        },
        fileName: downloaded.fileName,
        bytes: downloaded.bytes ?? await File(downloaded.path).readAsBytes(),
        deviceManager: _manager,
        onProgress: (progress) =>
            _events.add(CommandEvent('progress', data: {'progress': progress})),
      );
    }
    return {
      'path': downloaded.path,
      'fileName': downloaded.fileName,
      'type': switch (detail.type) {
        CommunityResourceType.quickApp => 'quickapp',
        CommunityResourceType.watchface => 'watchface',
        CommunityResourceType.firmware => 'firmware',
        CommunityResourceType.fontpack => 'fontpack',
        CommunityResourceType.iconpack => 'iconpack',
      },
      'installed': install,
    };
  }

  CommunitySourceId _source(String? value) {
    final normalized = value ?? 'astrobox-repo';
    if (normalized == 'amazfit' || normalized == 'huami') {
      return CommunitySourceId.huamiAppStore;
    }
    final source = communitySourceIdByName(normalized);
    if (source == null) {
      throw CommandFailure('usage', 'Unknown resource source: $normalized');
    }
    return source;
  }

  CommunityResourceType? _resourceType(
    String? value, {
    required bool required,
  }) {
    if (value == null || value.isEmpty) {
      if (required) {
        throw const CommandFailure('usage', 'Missing resource type');
      }
      return null;
    }
    return switch (value) {
      'quickapp' || 'miniprogram' => CommunityResourceType.quickApp,
      'watchface' => CommunityResourceType.watchface,
      'firmware' => CommunityResourceType.firmware,
      'fontpack' => CommunityResourceType.fontpack,
      'iconpack' => CommunityResourceType.iconpack,
      _ => throw CommandFailure('usage', 'Unknown resource type: $value'),
    };
  }

  ResourceRef _resourceRef(Map<String, Object?> params) {
    final raw = params['ref']?.toString() ?? '';
    final separator = raw.indexOf(':');
    if (separator <= 0 || separator == raw.length - 1) {
      throw CommandFailure('usage', 'Resource ref must be <source>:<id>: $raw');
    }
    return ResourceRef(
      source: _source(raw.substring(0, separator)),
      id: raw.substring(separator + 1),
    );
  }

  Map<String, Object?> _resourceJson(CommunityResource resource) =>
      communityResourceToJson(resource);

  Map<String, Object?> _resourceDetailJson(CommunityResourceDetail detail) =>
      communityResourceDetailToJson(detail);

  List<Map<String, Object?>> _accountList() {
    _reloadPersistedAccounts();
    return [
      _accountStatus('xiaomi'),
      _accountStatus('amazfit'),
      _accountStatus('bandbbs'),
    ];
  }

  void _reloadPersistedAccounts() {
    container.invalidate(huamiAuthProvider);
    container.invalidate(bandBbsAuthProvider);
  }

  Map<String, Object?> _freshAccountStatus(String? provider) {
    _reloadPersistedAccounts();
    return _accountStatus(provider);
  }

  Map<String, Object?> _accountStatus(String? provider) {
    return switch (provider) {
      'xiaomi' => {
        'provider': 'xiaomi',
        'signedIn': _state.pairedDevices.isNotEmpty,
        'syncedDevices': _state.pairedDevices.length,
      },
      'amazfit' || 'huami' => () {
        final account = container.read(huamiAuthProvider);
        return {
          'provider': 'amazfit',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
        };
      }(),
      'bandbbs' => () {
        final account = container.read(bandBbsAuthProvider);
        return {
          'provider': 'bandbbs',
          'signedIn': account.isSignedIn,
          if (account.username != null) 'username': account.username,
          if (account.userId != null) 'userId': account.userId,
          if (account.avatarUrl != null) 'avatarUrl': account.avatarUrl,
        };
      }(),
      _ => throw CommandFailure('usage', 'Unknown account provider: $provider'),
    };
  }

  Map<String, Object?> _accountCredentials(String? provider) {
    final normalized = provider == 'huami' ? 'amazfit' : provider;
    if (normalized != 'xiaomi' && normalized != 'amazfit') {
      throw CommandFailure(
        'usage',
        'Credentials are not supported for provider: $provider',
      );
    }
    final prefs = SharedPrefsService.instance;
    final prefix = normalized == 'xiaomi' ? 'mi_account' : 'huami_account';
    final remember = prefs.getBool('$prefix.remember_credentials') ?? false;
    return {
      'provider': normalized,
      'remember': remember,
      if (remember) 'username': prefs.getString('$prefix.username') ?? '',
      if (remember) 'password': prefs.getString('$prefix.password') ?? '',
      if (normalized == 'xiaomi')
        'userId': prefs.getString('mi_account.user_id') ?? '',
    };
  }

  Future<Object?> _setAccountCredentials(Map<String, Object?> params) async {
    final provider = params['provider']?.toString();
    final normalized = provider == 'huami' ? 'amazfit' : provider;
    if (normalized != 'xiaomi' && normalized != 'amazfit') {
      throw CommandFailure(
        'usage',
        'Credentials are not supported for provider: $provider',
      );
    }
    final prefs = SharedPrefsService.instance;
    final prefix = normalized == 'xiaomi' ? 'mi_account' : 'huami_account';
    final remember = params['remember'] == true;
    await prefs.setBool('$prefix.remember_credentials', remember);
    if (normalized == 'xiaomi' &&
        params['userId']?.toString().isNotEmpty == true) {
      await prefs.setString('mi_account.user_id', params['userId'].toString());
    }
    if (!remember) {
      await prefs.remove('$prefix.username');
      await prefs.remove('$prefix.password');
    } else {
      await prefs.setString(
        '$prefix.username',
        params['username']?.toString() ?? '',
      );
      await prefs.setString(
        '$prefix.password',
        params['password']?.toString() ?? '',
      );
    }
    return _accountCredentials(normalized);
  }

  Future<Object?> _accountLogin(Map<String, Object?> params) async {
    final provider = params['provider']?.toString();
    final username = params['username']?.toString() ?? '';
    final password = params['password']?.toString() ?? '';
    switch (provider) {
      case 'amazfit':
      case 'huami':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Amazfit username and password are required',
          );
        }
        await container
            .read(huamiAuthProvider.notifier)
            .login(username: username, password: password);
        return _accountStatus('amazfit');
      case 'xiaomi':
        if (username.isEmpty || password.isEmpty) {
          throw const CommandFailure(
            'usage',
            'Xiaomi username and password are required',
          );
        }
        final service = container.read(miAccountServiceProvider);
        late final MiAccountToken token;
        try {
          token = await service.login(username: username, password: password);
        } on MiAccountTwoFactorRequired catch (error) {
          throw CommandFailure(
            'two_factor_required',
            'Xiaomi account requires two-factor verification',
            details: {'url': error.url, 'deviceId': error.deviceId},
          );
        }
        final devices = await service.fetchBoundDevices(token: token);
        final imported = await _manager.importMiCloudDevices(devices);
        return {
          'provider': 'xiaomi',
          'signedIn': true,
          'importedDevices': imported,
          'userId': token.userId,
        };
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).startLogin();
        return const {'provider': 'bandbbs', 'authorizationStarted': true};
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<Object?> _completeXiaomiLogin(Map<String, Object?> params) async {
    final service = container.read(miAccountServiceProvider);
    final token = await service.completeTwoFactorLogin(
      challenge: MiAccountTwoFactorRequired(
        url: params['url']?.toString() ?? '',
        deviceId: params['deviceId']?.toString() ?? '',
      ),
      cookieHeader: params['cookieHeader']?.toString() ?? '',
    );
    final devices = await service.fetchBoundDevices(token: token);
    final imported = await _manager.importMiCloudDevices(devices);
    return {
      'provider': 'xiaomi',
      'signedIn': true,
      'importedDevices': imported,
      'userId': token.userId,
    };
  }

  Future<Object?> _bandBbsCallback(Map<String, Object?> params) async {
    final uri = Uri.tryParse(params['uri']?.toString() ?? '');
    if (uri == null) {
      throw const CommandFailure('usage', 'Invalid BandBBS callback URI');
    }
    final handled = await container
        .read(bandBbsAuthProvider.notifier)
        .handleCallback(uri);
    if (!handled) {
      throw const CommandFailure('usage', 'Unsupported BandBBS callback URI');
    }
    return _accountStatus('bandbbs');
  }

  Future<Object?> _accountLogout(String? provider) async {
    switch (provider) {
      case 'amazfit':
      case 'huami':
        await container.read(huamiAuthProvider.notifier).signOut();
        return {'provider': 'amazfit', 'signedIn': false};
      case 'bandbbs':
        await container.read(bandBbsAuthProvider.notifier).signOut();
        return {'provider': 'bandbbs', 'signedIn': false};
      case 'xiaomi':
        throw const CommandFailure(
          'unsupported',
          'Xiaomi credentials are not persisted as a login session',
        );
      default:
        throw CommandFailure('usage', 'Unknown account provider: $provider');
    }
  }

  Future<void> _ensureConnected(String? address) async {
    if (_state.protocolState == ProtocolState.ready &&
        (address == null || _state.currentDevice?.addr == address)) {
      return;
    }
    await _connect(address);
  }

  Map<String, Object?> _deviceJson(MiWearState device) => {
    'name': device.name,
    'address': device.addr,
    'connectType': device.connectType,
    if (device.codename != null) 'codename': device.codename,
    'disconnected': device.disconnected,
  };

  @override
  Future<void> close() async {
    _deviceManagerSubscription.close();
    await _logSubscription.cancel();
    await _events.close();
  }
}

class CommandFailure implements Exception {
  const CommandFailure(this.code, this.message, {this.details});
  final String code;
  final String message;
  final Object? details;
}
