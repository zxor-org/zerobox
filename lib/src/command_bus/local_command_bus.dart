import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';
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
import 'package:zerobox/src/features/debug/application/debug_environment.dart';
import 'package:zerobox/src/features/plugins/application/plugin_community_catalog.dart';
import 'package:zerobox/src/features/plugins/application/plugin_manager.dart';
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
    _logSubscription = zeroBoxDiagnosticStream.listen(
      (event) => _events.add(
        CommandEvent('debug.log', data: {'record': event.toJson()}),
      ),
    );
    _xiaoAiSubscription = _manager.xiaoAiOpusFrames.listen(
      (frame) => _events.add(
        CommandEvent(
          'device.zeppos.xiaoai.opus',
          data: {'frame': frame.toList(growable: false)},
        ),
      ),
    );
    _pluginManager = PluginManager(
      deviceManager: _manager,
      readDeviceState: () => _state,
      emitEvent: _events.add,
    );
    unawaited(_pluginManager.initialize());
  }

  final ProviderContainer container;
  final _events = StreamController<CommandEvent>.broadcast();
  final _externalDiagnostics = <Map<String, Object?>>[];
  String? _debugSessionId;
  DateTime? _debugSessionStartedAt;
  late final ProviderSubscription<DeviceManagerState>
  _deviceManagerSubscription;
  late final StreamSubscription<DiagnosticEvent> _logSubscription;
  late final StreamSubscription<Uint8List> _xiaoAiSubscription;
  bool _activeCommandCancelled = false;
  Future<void> _commandTail = Future<void>.value();
  late final PluginManager _pluginManager;

  DeviceManager get _manager => container.read(deviceManagerProvider.notifier);
  DeviceManagerState get _state => container.read(deviceManagerProvider);

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    if (command.method == 'debug.session.start') {
      final sessionId = command.params['sessionId']?.toString() ?? '';
      if (sessionId.isEmpty) {
        return const CommandResult.failure(
          CommandError('usage', 'Diagnostic session ID is required'),
        );
      }
      _debugSessionId = sessionId;
      _debugSessionStartedAt =
          DateTime.tryParse(command.params['startedAt']?.toString() ?? '') ??
          DateTime.now();
      _externalDiagnostics.clear();
      return CommandResult.success({
        'sessionId': sessionId,
        'startedAt': _debugSessionStartedAt!.toIso8601String(),
      });
    }
    if (command.method == 'debug.publish') {
      final record = (command.params['record'] as Map?)
          ?.cast<String, Object?>();
      if (record == null) {
        return const CommandResult.failure(
          CommandError('usage', 'Diagnostic record is required'),
        );
      }
      final sessionId = command.params['sessionId']?.toString();
      final process = record['process']?.toString();
      if (process == DiagnosticProcess.frontend.name &&
          _debugSessionId != null &&
          sessionId != _debugSessionId) {
        return const CommandResult.success({'accepted': false, 'stale': true});
      }
      _externalDiagnostics.add(record);
      if (_externalDiagnostics.length > 1000) {
        _externalDiagnostics.removeAt(0);
      }
      _events.add(CommandEvent('debug.log', data: {'record': record}));
      return const CommandResult.success({'accepted': true});
    }
    if (command.method == 'plugin.host.respond') {
      try {
        await _pluginManager.respondToHostRequest(
          command.params['requestId']?.toString() ?? '',
          (command.params['response'] as Map?)?.cast<String, Object?>() ??
              const {},
        );
        return const CommandResult.success({'accepted': true});
      } catch (error, stackTrace) {
        return CommandResult.failure(
          CommandError('internal', error.toString(), details: '$stackTrace'),
        );
      }
    }
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
    } on PluginExecutionException catch (error) {
      return CommandResult.failure(
        CommandError(
          'plugin_error',
          error.message,
          details: {'pluginId': error.pluginId, 'pluginName': error.pluginName},
        ),
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
    'device.connect.cancel' => _cancelConnect(),
    'device.disconnect' => _disconnect(command.params['device']?.toString()),
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
    'device.zeppos.messages.clear' => Future.value(_clearZeppOsMessages()),
    'device.zeppos.screenshot' => _manager.requestZeppOsScreenshot(),
    'device.zeppos.appside.list' => _manager.listZeppOsAppSides(),
    'device.zeppos.appside.observed' => _manager.observedZeppOsAppSideIds(),
    'device.zeppos.appside.sessions' => _appSideSessions(),
    'device.zeppos.appside.events' => _appSideEvents(command.params),
    'device.zeppos.appside.events.clear' => _appSideEventsClear(command.params),
    'device.zeppos.appside.start' => _appSideStart(command.params),
    'device.zeppos.appside.stop' => _appSideStop(command.params),
    'device.zeppos.appside.inject' => _appSideMessage(
      command.params,
      inject: true,
    ),
    'device.zeppos.appside.send' => _appSideMessage(
      command.params,
      inject: false,
    ),
    'device.zeppos.xiaoai.reply' => _sendXiaoAiReply(
      command.params['text']?.toString(),
    ),
    'device.zeppos.xiaoai.continuous' => _setXiaoAiContinuousCapture(
      command.params['enabled'] == true,
    ),
    'device.zeppos.xiaoai.endpoint' => _setXiaoAiEndpoint(
      (command.params['endpoint'] as num?)?.toInt(),
    ),
    'device.interconnect.send' => _sendInterconnectMessage(command.params),
    'device.raw.send' => _sendRaw(command.params),
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
    'resource.sources' => _resourceSources(),
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
    'debug.snapshot' => _debugSnapshot(),
    'debug.sources' => _debugSources(),
    'debug.plugin.snapshot' => _debugPluginSnapshot(command.params),
    'debug.runtime' => collectDebugRuntimeEnvironment(),
    'debug.storage.roots' => debugHostStorageRoots(),
    'debug.storage.list' => _debugStorageList(command.params),
    'debug.storage.read' => _debugStorageRead(command.params),
    'plugin.list' => _pluginManager.list(
      includeIcons: command.params['includeIcons'] != false,
    ),
    'plugin.failures' => Future.value(_pluginManager.failures()),
    'plugin.safeMode.get' => Future.value({'enabled': _pluginManager.safeMode}),
    'plugin.safeMode.set' => _pluginManager.setSafeMode(
      command.params['enabled'] == true,
    ),
    'plugin.install' => _installPlugin(command.params),
    'plugin.get' => _pluginManager.get(command.params['id']?.toString() ?? ''),
    'plugin.open' => _pluginManager.open(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.invoke' => _pluginManager.invoke(
      command.params['id']?.toString() ?? '',
      command.params['callback']?.toString() ?? '',
      command.params['value']?.toString(),
    ),
    'plugin.close' => _pluginManager.closePlugin(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.remove' => _removePlugin(command.params),
    'plugin.data.clear' => _pluginManager.clearData(
      command.params['id']?.toString() ?? '',
    ),
    'plugin.provider.list' => _pluginManager.providers(),
    'plugin.provider.call' => _pluginManager.callProvider(
      command.params['provider']?.toString() ?? '',
      command.params['operation']?.toString() ?? '',
      (command.params['arguments'] as List?)?.cast<Object?>() ?? const [],
    ),
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

  Future<Map<String, Object?>> _debugSnapshot() async {
    await _pluginManager.initialize();
    final records =
        [
            ...recentZeroBoxDiagnostics.map((event) => event.toJson()),
            ..._externalDiagnostics,
          ].where((record) {
            final startedAt = _debugSessionStartedAt;
            if (startedAt == null) return true;
            final time = DateTime.tryParse(record['time']?.toString() ?? '');
            return time != null && !time.isBefore(startedAt);
          }).toList()
          ..sort(
            (a, b) => a['time'].toString().compareTo(b['time'].toString()),
          );
    return {'records': records, 'plugins': _pluginManager.diagnostics()};
  }

  Future<Map<String, Object?>> _debugSources() async {
    await _pluginManager.initialize();
    return {
      'processes': const ['frontend', 'backend'],
      'plugins': _pluginManager.diagnosticSources(),
    };
  }

  Future<Map<String, Object?>> _debugPluginSnapshot(
    Map<String, Object?> params,
  ) async {
    await _pluginManager.initialize();
    return _pluginManager.diagnosticSnapshot(params['id']?.toString() ?? '');
  }

  Future<List<Map<String, Object?>>> _debugStorageList(
    Map<String, Object?> params,
  ) async {
    final pluginId = params['pluginId']?.toString();
    final path = params['path']?.toString() ?? '';
    if (pluginId != null && pluginId.isNotEmpty) {
      return _pluginManager.diagnosticStorageDirectory(pluginId, path);
    }
    return listDebugHostDirectory(params['root']?.toString() ?? '', path);
  }

  Future<Map<String, Object?>> _debugStorageRead(
    Map<String, Object?> params,
  ) async {
    final pluginId = params['pluginId']?.toString();
    final path = params['path']?.toString() ?? '';
    if (pluginId != null && pluginId.isNotEmpty) {
      return _pluginManager.diagnosticStorageFile(pluginId, path);
    }
    return readDebugHostFile(params['root']?.toString() ?? '', path);
  }

  Future<Object?> _installPlugin(Map<String, Object?> params) async {
    final raw = params['bytes'];
    final bytes = switch (raw) {
      Uint8List value => value,
      List value => Uint8List.fromList(
        value.whereType<num>().map((item) => item.toInt() & 0xff).toList(),
      ),
      String value => base64Decode(value),
      _ => throw const CommandFailure('usage', 'Plugin bytes are required'),
    };
    return _pluginManager.install(
      bytes,
      fileName: params['fileName']?.toString(),
      includeIcon: params['includeIcon'] != false,
    );
  }

  Future<Object?> _removePlugin(Map<String, Object?> params) async {
    final id = params['id']?.toString() ?? '';
    final removedSources = (await _pluginManager.providers())
        .where((provider) => provider['pluginId']?.toString() == id)
        .map(
          (provider) => CommunitySourceId.plugin(
            provider['name']?.toString() ?? '',
          ).storageKey,
        )
        .toSet();
    await _pluginManager.remove(id);
    final prefs = SharedPrefsService.instance;
    if (removedSources.contains(prefs.getString('community_source'))) {
      await prefs.setString(
        'community_source',
        CommunitySourceId.astroboxRepo.storageKey,
      );
      container.invalidate(appSettingsProvider);
      _events.add(
        CommandEvent('settings.state', data: {'state': _settingsList()}),
      );
    }
    return {'removed': id};
  }

  Future<Object?> _sendInterconnectMessage(Map<String, Object?> params) async {
    final packageName = params['package']?.toString() ?? '';
    final payload = (params['payload'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt() & 0xff)
        .toList(growable: false);
    if (packageName.isEmpty || payload == null) {
      throw const CommandFailure('usage', 'package and payload are required');
    }
    await _manager.sendInterconnectMessage(
      packageName,
      Uint8List.fromList(payload),
    );
    return {'sent': true};
  }

  Future<Object?> _sendRaw(Map<String, Object?> params) async {
    final payload = (params['payload'] as List?)
        ?.whereType<num>()
        .map((value) => value.toInt() & 0xff)
        .toList(growable: false);
    if (payload == null) {
      throw const CommandFailure('usage', 'payload is required');
    }
    await _manager.sendRaw(Uint8List.fromList(payload));
    return {'sent': true};
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
    if (state.connectionTargetAddr != null)
      'connectionTargetAddr': state.connectionTargetAddr,
    if (state.connectionTargetName != null)
      'connectionTargetName': state.connectionTargetName,
    if (state.connectionPhase != null)
      'connectionPhase': state.connectionPhase!.name,
    'connectStatus': state.connectStatus,
    'protocolState': state.protocolState.name,
    if (state.battery != null) 'battery': state.battery!.toJson(),
    if (state.systemInfo != null) 'systemInfo': state.systemInfo!.toJson(),
    'apps': state.apps.map((item) => item.toJson()).toList(),
    'watchfaces': state.watchfaces.map((item) => item.toJson()).toList(),
    'zeppOsMessages': state.zeppOsMessages
        .map((item) => item.toJson())
        .toList(growable: false),
    'xiaoAiActive': state.xiaoAiActive,
    'xiaoAiFrameCount': state.xiaoAiFrameCount,
    'xiaoAiCapabilities': state.xiaoAiCapabilities,
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

  Future<Object?> _disconnect(String? address) async {
    final disconnectedActiveDevice =
        address == null || address == _state.currentDevice?.addr;
    await _manager.disconnect(address);
    if (disconnectedActiveDevice) {
      _events.add(const CommandEvent('disconnected'));
    }
    return const {'disconnected': true};
  }

  Future<Object?> _cancelConnect() async {
    await _manager.cancelConnect();
    return const {'cancelled': true};
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

  Object _clearZeppOsMessages() {
    _manager.clearZeppOsMessages();
    return const {'cleared': true};
  }

  int _appSideId(Map<String, Object?> params) {
    final id = (params['appId'] as num?)?.toInt();
    if (id == null) {
      throw const CommandFailure('invalid_argument', 'appId is required');
    }
    return id;
  }

  Uint8List _appSidePayload(Map<String, Object?> params) {
    final raw = params['payload'];
    if (raw is! List) {
      throw const CommandFailure('invalid_argument', 'payload is required');
    }
    return Uint8List.fromList(
      raw.map((value) => (value as num).toInt()).toList(),
    );
  }

  Future<Object?> _appSideSessions() async {
    final sessions = await _manager.zeppOsAppSideSessions();
    return sessions
        .map(
          (session) => {
            'appId': session.appId,
            'version': session.version,
            'port1': session.port1,
            'port2': session.port2,
            'extra': session.extra,
            'watchSessionOpen': session.watchSessionOpen,
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _appSideEvents(Map<String, Object?> params) async {
    final events = await _manager.zeppOsAppSideEvents(_appSideId(params));
    return events
        .map(
          (event) => {
            'timestamp': event.timestamp.toIso8601String(),
            'type': event.type,
            'message': event.message,
            if (event.direction != null) 'direction': event.direction,
            if (event.source != null) 'source': event.source,
            if (event.payload != null)
              'payload': event.payload!.toList(growable: false),
          },
        )
        .toList(growable: false);
  }

  Future<Object?> _appSideEventsClear(Map<String, Object?> params) async {
    final id = _appSideId(params);
    await _manager.clearZeppOsAppSideEvents(id);
    return {'appId': id, 'cleared': true};
  }

  Future<Object?> _appSideStart(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    await _manager.startZeppOsAppSide(id);
    return {'appId': id, 'running': true};
  }

  Future<Object?> _appSideStop(Map<String, Object?> params) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    await _manager.stopZeppOsAppSide(id);
    return {'appId': id, 'running': false};
  }

  Future<Object?> _appSideMessage(
    Map<String, Object?> params, {
    required bool inject,
  }) async {
    await _ensureConnected(null);
    final id = _appSideId(params);
    final payload = _appSidePayload(params);
    if (inject) {
      await _manager.injectZeppOsAppSideMessage(id, payload);
    } else {
      await _manager.sendZeppOsAppSideMessage(id, payload);
    }
    return {'appId': id, 'bytes': payload.length};
  }

  Future<Object?> _sendXiaoAiReply(String? text) async {
    await _ensureConnected(null);
    if (text == null || text.trim().isEmpty) {
      throw const CommandFailure('invalid_argument', 'Reply cannot be empty');
    }
    await _manager.sendXiaoAiReply(text);
    return const {'sent': true};
  }

  Future<Object?> _setXiaoAiContinuousCapture(bool enabled) async {
    await _ensureConnected(null);
    await _manager.setXiaoAiContinuousCapture(enabled);
    return {'enabled': enabled};
  }

  Future<Object?> _setXiaoAiEndpoint(int? endpoint) async {
    await _ensureConnected(null);
    if (endpoint == null) {
      throw const CommandFailure('invalid_argument', 'Endpoint is required');
    }
    await _manager.setXiaoAiEndpoint(endpoint);
    return {'endpoint': endpoint};
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
    final rawBytes = params['bytes'];
    final memoryPayload = params['payloadMode'] == 'memory';
    final typeName = params['type']?.toString() ?? '';
    if (path.isEmpty && !memoryPayload) {
      throw const CommandFailure('usage', 'Missing resource payload');
    }
    if (kIsWeb && !memoryPayload) {
      throw const CommandFailure(
        'unsupported',
        'Web installs require an in-memory resource payload',
      );
    }
    final file = memoryPayload ? null : File(path);
    if (file != null && !await file.exists()) {
      throw CommandFailure('file', 'File not found: $path');
    }
    final Uint8List bytes;
    if (memoryPayload) {
      bytes = switch (rawBytes) {
        Uint8List value => value,
        List value => Uint8List.fromList(
          value.map((item) => (item as num).toInt()).toList(),
        ),
        _ => throw const CommandFailure(
          'usage',
          'Missing in-memory resource bytes',
        ),
      };
    } else {
      bytes = await file!.readAsBytes();
    }
    final fileName = params['fileName']?.toString().isNotEmpty == true
        ? params['fileName'].toString()
        : file!.uri.pathSegments.last;
    final installMode = ResourceInstallMode.values.firstWhere(
      (mode) => mode.name == params['installMode']?.toString(),
      orElse: () => ResourceInstallMode.automatic,
    );
    var installed = false;
    try {
      final service = container.read(resourceInstallServiceProvider);
      final type = switch (typeName) {
        'auto' => service.detectLocalInstallType(fileName, bytes),
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
      void onProgress(double progress) => _events.add(
        CommandEvent('progress', data: {'progress': progress, 'path': path}),
      );
      switch (installMode) {
        case ResourceInstallMode.automatic:
          await service.installLocalPayload(
            type: type,
            fileName: fileName,
            bytes: bytes,
            deviceManager: _manager,
            onProgress: onProgress,
          );
        case ResourceInstallMode.forceType:
          await service.installForcedPayload(
            type: type,
            fileName: fileName,
            bytes: bytes,
            deviceManager: _manager,
            onProgress: onProgress,
          );
        case ResourceInstallMode.forcePlatform:
          final analysis = service.analyzePayload(
            fileName: fileName,
            bytes: bytes,
            hint: type,
            source: 'daemon-queue-force-platform',
          );
          if (analysis == null) {
            throw CommandFailure(
              'validation',
              'Unrecognized resource: $fileName',
            );
          }
          await service.installAnalyzedPayload(
            analysis: analysis,
            fileName: fileName,
            deviceManager: _manager,
            forcePlatform: true,
            onProgress: onProgress,
          );
      }
      installed = true;
      _events.add(CommandEvent('completed', data: {'path': path}));
      return {'installed': true, 'path': path, 'type': type.name};
    } finally {
      if (installed &&
          params['deleteAfter'] == true &&
          file != null &&
          await file.exists()) {
        await file.delete();
      }
    }
  }

  Future<Object?> _resourceList(Map<String, Object?> params) async {
    _reloadPersistedAccounts();
    final source = _source(params['source']?.toString());
    final catalog = _resourceCatalog(source);
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
    final catalog = _resourceCatalog(source);
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
    final catalog = _resourceCatalog(source);
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
    final catalog = _resourceCatalog(ref.source);
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
    final catalog = _resourceCatalog(ref.source);
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

  Future<List<Map<String, Object?>>> _resourceSources() async {
    final pluginProviders = await _pluginManager.providers();
    return [
      ...CommunitySourceId.values.map(
        (source) => {'id': source.storageKey, 'name': source.displayName},
      ),
      ...pluginProviders.map((provider) {
        final id = provider['id']?.toString() ?? '';
        final source = CommunitySourceId.plugin(id);
        return {
          'id': source.storageKey,
          'name': provider['name']?.toString() ?? id,
          'pluginId': provider['pluginId'],
        };
      }),
    ];
  }

  CommunityResourceCatalog _resourceCatalog(CommunitySourceId source) {
    if (source.isPlugin) {
      return PluginCommunityCatalog(manager: _pluginManager, sourceId: source);
    }
    return container.read(localCommunityCatalogProviderForSource(source));
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
    try {
      await _manager.disconnect().timeout(const Duration(seconds: 3));
    } catch (error, stackTrace) {
      getLogger(
        'LocalCommandBus',
      ).warning('Device disconnect during shutdown failed', error, stackTrace);
    }
    await _pluginManager.close();
    _deviceManagerSubscription.close();
    await _logSubscription.cancel();
    await _xiaoAiSubscription.cancel();
    await _events.close();
  }
}

class CommandFailure implements Exception {
  const CommandFailure(this.code, this.message, {this.details});
  final String code;
  final String message;
  final Object? details;
}
