import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_app_side_system.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/host/application_host_provider.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';

class HostDeviceManager extends DeviceManager {
  static final _log = getLogger('HostDeviceManager');

  StreamSubscription<CommandEvent>? _eventSubscription;
  bool _disposed = false;
  var _connectGeneration = 0;
  String? _pendingConnectionAddr;

  @override
  DeviceManagerState build() {
    final host = ref.watch(applicationHostProvider);
    ref.onDispose(() {
      _disposed = true;
      unawaited(_eventSubscription?.cancel());
    });
    _eventSubscription = host.events.listen(_handleEvent);
    scheduleMicrotask(_refreshSnapshot);
    return const DeviceManagerState();
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'device.zeppos.xiaoai.opus') {
      final raw = event.data['frame'];
      if (raw is List) {
        emitXiaoAiOpusFrame(
          Uint8List.fromList(
            raw.whereType<num>().map((value) => value.toInt() & 0xff).toList(),
          ),
        );
      }
      return;
    }
    if (event.event == 'host.disconnected') {
      if (!_disposed) {
        state = state.copyWith(
          connecting: false,
          protocolState: ProtocolState.disconnected,
          error: 'daemon_disconnected',
        );
      }
      return;
    }
    if (event.event == 'host.connected') {
      unawaited(_refreshSnapshot());
      return;
    }
    if (event.event != 'device.state') return;
    final raw = event.data['state'];
    if (raw is Map) _applyState(raw.cast<String, Object?>());
  }

  Future<CommandResult> _execute(ZeroBoxCommand command) async {
    final result = await ref.read(applicationHostProvider).execute(command);
    if (!result.ok) {
      final error = result.error;
      if (error == null) {
        throw StateError('Daemon command failed without error details');
      }
      final details = error.details;
      throw StateError(
        '${error.code}: ${error.message}'
        '${details == null || details.toString().isEmpty ? '' : '\n$details'}',
      );
    }
    return result;
  }

  Future<void> _refreshSnapshot() async {
    try {
      final result = await _execute(
        const ZeroBoxCommand(method: 'device.snapshot'),
      );
      final raw = result.value;
      if (raw is Map) _applyState(raw.cast<String, Object?>());
    } catch (error) {
      if (!_disposed) state = state.copyWith(error: error.toString());
    }
  }

  void _applyState(Map<String, Object?> raw) {
    if (_disposed) return;
    final rawConnectionTarget = raw['connectionTargetAddr']?.toString();
    final pendingConnectionAddr = _pendingConnectionAddr;
    if (pendingConnectionAddr != null &&
        state.connecting &&
        rawConnectionTarget != pendingConnectionAddr) {
      return;
    }
    final current = raw['currentDevice'];
    final battery = raw['battery'];
    final systemInfo = raw['systemInfo'];
    state = DeviceManagerState(
      currentDevice: current is Map
          ? MiWearState.fromJson(current.cast<String, dynamic>())
          : null,
      pairedDevices: _modelList(raw['pairedDevices'], MiWearState.fromJson),
      scannedDevices: _modelList(raw['scannedDevices'], BTDeviceInfo.fromJson),
      scanning: raw['scanning'] == true,
      connecting: raw['connecting'] == true,
      connectionTargetAddr: rawConnectionTarget,
      connectionTargetName: raw['connectionTargetName']?.toString(),
      connectionPhase: DeviceConnectionPhase.values
          .where((value) => value.name == raw['connectionPhase']?.toString())
          .firstOrNull,
      connectStatus: (raw['connectStatus'] as num?)?.toInt() ?? 0,
      protocolState: ProtocolState.values.firstWhere(
        (value) => value.name == raw['protocolState']?.toString(),
        orElse: () => ProtocolState.disconnected,
      ),
      battery: battery is Map
          ? BatteryStatus.fromJson(battery.cast<String, dynamic>())
          : null,
      systemInfo: systemInfo is Map
          ? SystemInfo.fromJson(systemInfo.cast<String, dynamic>())
          : null,
      apps: _modelList(raw['apps'], AppInfo.fromJson),
      watchfaces: _modelList(raw['watchfaces'], WatchfaceInfo.fromJson),
      zeppOsMessages: _modelList(
        raw['zeppOsMessages'],
        ZeppOsMessageRecord.fromJson,
      ),
      xiaoAiActive: raw['xiaoAiActive'] == true,
      xiaoAiFrameCount: (raw['xiaoAiFrameCount'] as num?)?.toInt() ?? 0,
      xiaoAiCapabilities: raw['xiaoAiCapabilities'] is Map
          ? (raw['xiaoAiCapabilities'] as Map).cast<String, Object?>()
          : const {},
      error: raw['error']?.toString(),
    );
  }

  List<T> _modelList<T>(
    Object? raw,
    T Function(Map<String, dynamic>) fromJson,
  ) => raw is List
      ? raw
            .whereType<Map>()
            .map((item) => fromJson(item.cast<String, dynamic>()))
            .toList()
      : <T>[];

  Future<Map<String, Object?>> _executeState(String method) async {
    final result = await _execute(ZeroBoxCommand(method: method));
    final raw = (result.value as Map).cast<String, Object?>();
    _applyState(raw);
    return raw;
  }

  @override
  Future<void> startBluetoothScan({
    ConnectType connectType = ConnectType.ble,
  }) async {
    state = state.copyWith(
      scanning: true,
      scannedDevices: const [],
      clearError: true,
    );
    try {
      await _execute(
        ZeroBoxCommand(
          method: 'device.scan.start',
          params: {'connectType': connectType.name},
        ),
      );
    } catch (error, stackTrace) {
      _log.severe('start remote scan failed', error, stackTrace);
      if (!_disposed) {
        state = state.copyWith(scanning: false, error: error.toString());
      }
    }
  }

  @override
  Future<void> stopBluetoothScan() async {
    await _executeState('device.scan.stop');
  }

  @override
  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  }) async {
    final generation = ++_connectGeneration;
    try {
      await importSharedDevice(
        MiWearState(
          name: name,
          addr: addr,
          connectType: connectType,
          authkey: authKey,
          disconnected: true,
        ),
      );
      if (generation != _connectGeneration) return;
      _pendingConnectionAddr = addr;
      state = state.copyWith(
        connecting: true,
        connectionTargetAddr: addr,
        connectionTargetName: name,
        connectionPhase: DeviceConnectionPhase.preparing,
        protocolState: ProtocolState.connecting,
        clearError: true,
      );
      await _execute(
        ZeroBoxCommand(method: 'device.connect', params: {'device': addr}),
      );
      if (generation != _connectGeneration) return;
      await _refreshSnapshot();
      if (generation == _connectGeneration) _pendingConnectionAddr = null;
    } catch (error, stackTrace) {
      if (generation != _connectGeneration) return;
      _pendingConnectionAddr = null;
      _log.severe('remote connect to $addr failed', error, stackTrace);
      if (!_disposed) {
        state = state.copyWith(
          connecting: false,
          connectStatus: 3,
          protocolState: ProtocolState.error,
          error: error.toString(),
        );
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _connectGeneration += 1;
    _pendingConnectionAddr = null;
    await _execute(const ZeroBoxCommand(method: 'device.disconnect'));
    await _refreshSnapshot();
  }

  @override
  Future<void> cancelConnect() async {
    if (!state.connecting) return;
    _connectGeneration += 1;
    _pendingConnectionAddr = null;
    await _execute(const ZeroBoxCommand(method: 'device.connect.cancel'));
    await _refreshSnapshot();
  }

  @override
  Future<void> removeDevice(String addr) async {
    await _execute(
      ZeroBoxCommand(method: 'device.remove', params: {'device': addr}),
    );
    await _refreshSnapshot();
  }

  @override
  Future<void> refreshBattery() async {
    await _executeState('device.refresh.battery');
  }

  @override
  Future<void> refreshDeviceData() async {
    await _executeState('device.refresh.all');
  }

  @override
  Future<void> setFindingZeppOsDevice(bool finding) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.zeppos.find',
        params: {'finding': finding},
      ),
    );
  }

  @override
  Future<void> sendXiaoAiReply(String text) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.zeppos.xiaoai.reply',
        params: {'text': text},
      ),
    );
  }

  @override
  Future<void> setXiaoAiContinuousCapture(bool enabled) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.zeppos.xiaoai.continuous',
        params: {'enabled': enabled},
      ),
    );
  }

  @override
  Future<void> setXiaoAiEndpoint(int endpoint) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.zeppos.xiaoai.endpoint',
        params: {'endpoint': endpoint},
      ),
    );
  }

  @override
  void clearZeppOsMessages() {
    unawaited(
      _execute(
        const ZeroBoxCommand(method: 'device.zeppos.messages.clear'),
      ).then((_) => _refreshSnapshot()),
    );
  }

  @override
  Future<void> fetchSystemInfo() async {
    await _executeState('device.refresh.system');
  }

  @override
  Future<void> fetchStorageInfo() async {
    await _executeState('device.refresh.storage');
  }

  @override
  Future<void> fetchApps() async {
    await _execute(const ZeroBoxCommand(method: 'app.list'));
    await _refreshSnapshot();
  }

  @override
  Future<void> fetchWatchfaces() async {
    await _execute(const ZeroBoxCommand(method: 'watchface.list'));
    await _refreshSnapshot();
  }

  @override
  Future<void> openApp(AppInfo app, {String page = ''}) async {
    await _execute(
      ZeroBoxCommand(
        method: 'app.launch',
        params: {'package': app.packageName, if (page.isNotEmpty) 'page': page},
      ),
    );
  }

  @override
  Future<void> sendInterconnectMessage(
    String packageName,
    Uint8List payload,
  ) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.interconnect.send',
        params: {
          'package': packageName,
          'payload': payload.toList(growable: false),
        },
      ),
    );
  }

  @override
  Future<void> sendRaw(Uint8List payload) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.raw.send',
        params: {'payload': payload.toList(growable: false)},
      ),
    );
  }

  @override
  Future<Uint8List> requestZeppOsScreenshot() async {
    final result = await _execute(
      const ZeroBoxCommand(method: 'device.zeppos.screenshot'),
    );
    return Uint8List.fromList(
      (result.value as List).map((value) => (value as num).toInt()).toList(),
    );
  }

  @override
  Future<List<int>> listZeppOsAppSides() async {
    final result = await _execute(
      const ZeroBoxCommand(method: 'device.zeppos.appside.list'),
    );
    return (result.value as List)
        .map((value) => (value as num).toInt())
        .toList();
  }

  @override
  Future<List<int>> observedZeppOsAppSideIds() async {
    final result = await _execute(
      const ZeroBoxCommand(method: 'device.zeppos.appside.observed'),
    );
    return (result.value as List)
        .map((value) => (value as num).toInt())
        .toList();
  }

  @override
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions() async {
    final result = await _execute(
      const ZeroBoxCommand(method: 'device.zeppos.appside.sessions'),
    );
    return (result.value as List)
        .whereType<Map>()
        .map((raw) {
          final value = raw.cast<String, Object?>();
          return ZeppOsAppSideSessionInfo(
            appId: (value['appId'] as num).toInt(),
            version: (value['version'] as num).toInt(),
            port1: (value['port1'] as num).toInt(),
            port2: (value['port2'] as num).toInt(),
            extra: (value['extra'] as num).toInt(),
            watchSessionOpen: value['watchSessionOpen'] == true,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<List<ZeppOsAppSideDebugEvent>> zeppOsAppSideEvents(int appId) async {
    final result = await _execute(
      ZeroBoxCommand(
        method: 'device.zeppos.appside.events',
        params: {'appId': appId},
      ),
    );
    return (result.value as List)
        .whereType<Map>()
        .map((raw) {
          final value = raw.cast<String, Object?>();
          final payload = value['payload'];
          return ZeppOsAppSideDebugEvent(
            timestamp: DateTime.parse(value['timestamp'].toString()),
            type: value['type'].toString(),
            message: value['message'].toString(),
            direction: value['direction']?.toString(),
            source: value['source']?.toString(),
            payload: payload is List
                ? Uint8List.fromList(
                    payload
                        .whereType<num>()
                        .map((byte) => byte.toInt())
                        .toList(),
                  )
                : null,
          );
        })
        .toList(growable: false);
  }

  @override
  Future<void> clearZeppOsAppSideEvents(int appId) => _execute(
    ZeroBoxCommand(
      method: 'device.zeppos.appside.events.clear',
      params: {'appId': appId},
    ),
  );

  @override
  Future<void> startZeppOsAppSide(int appId) => _execute(
    ZeroBoxCommand(
      method: 'device.zeppos.appside.start',
      params: {'appId': appId},
    ),
  );

  @override
  Future<void> stopZeppOsAppSide(int appId) => _execute(
    ZeroBoxCommand(
      method: 'device.zeppos.appside.stop',
      params: {'appId': appId},
    ),
  );

  @override
  Future<void> injectZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _execute(
        ZeroBoxCommand(
          method: 'device.zeppos.appside.inject',
          params: {'appId': appId, 'payload': payload.toList()},
        ),
      );

  @override
  Future<void> sendZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _execute(
        ZeroBoxCommand(
          method: 'device.zeppos.appside.send',
          params: {'appId': appId, 'payload': payload.toList()},
        ),
      );

  @override
  Future<void> uninstallApp(AppInfo app) async {
    await _execute(
      ZeroBoxCommand(
        method: 'app.uninstall',
        params: {'package': app.packageName},
      ),
    );
    await _refreshSnapshot();
  }

  @override
  Future<void> uninstallWatchface(WatchfaceInfo watchface) async {
    await _execute(
      ZeroBoxCommand(method: 'watchface.remove', params: {'id': watchface.id}),
    );
    await _refreshSnapshot();
  }

  @override
  Future<void> setWatchface(WatchfaceInfo watchface) async {
    await _execute(
      ZeroBoxCommand(method: 'watchface.set', params: {'id': watchface.id}),
    );
    await _refreshSnapshot();
  }

  Future<void> _installBytes(
    Uint8List bytes,
    String type,
    String extension,
    void Function(double progress)? onProgress,
  ) async {
    if (kIsWeb) {
      StreamSubscription<CommandEvent>? progressSubscription;
      try {
        progressSubscription = ref.read(applicationHostProvider).events.listen((
          event,
        ) {
          if (event.event != 'progress') return;
          final value = event.data['progress'];
          if (value is num) onProgress?.call(value.toDouble());
        });
        await _execute(
          ZeroBoxCommand(
            method: 'install.local',
            params: {
              'type': type,
              'payloadMode': 'memory',
              'bytes': bytes,
              'fileName': 'zerobox_web.$extension',
            },
          ),
        );
        await _refreshSnapshot();
      } finally {
        await progressSubscription?.cancel();
      }
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/zerobox_gui_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    StreamSubscription<CommandEvent>? progressSubscription;
    try {
      final queued = await _execute(
        ZeroBoxCommand(
          method: 'task.enqueue',
          params: {
            'command': ZeroBoxCommand(
              method: 'install.local',
              params: {'type': type, 'path': file.path, 'deleteAfter': true},
            ).toJson(),
          },
        ),
      );
      final taskId = (queued.value as Map)['taskId']?.toString();
      if (taskId == null) throw StateError('Daemon did not return a task ID');
      progressSubscription = ref.read(applicationHostProvider).events.listen((
        event,
      ) {
        if (event.event != 'task' || event.data['id']?.toString() != taskId) {
          return;
        }
        final value = event.data['progress'];
        if (value is num) onProgress?.call(value.toDouble());
      });
      final completed = await _execute(
        ZeroBoxCommand(method: 'queue.wait', params: {'id': taskId}),
      );
      final task = (completed.value as Map).cast<String, Object?>();
      final nested = task['result'];
      if (nested is Map) {
        final result = CommandResult.fromJson(nested.cast<String, Object?>());
        if (!result.ok) {
          throw StateError('${result.error!.code}: ${result.error!.message}');
        }
      }
      await _refreshSnapshot();
    } finally {
      await progressSubscription?.cancel();
    }
  }

  @override
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  }) => _installBytes(packageBytes, 'quickapp', 'rpk', onProgress);

  @override
  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) => _installBytes(watchfaceBytes, 'watchface', 'bin', onProgress);

  @override
  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) => _installBytes(firmwareBytes, 'firmware', 'bin', onProgress);

  @override
  Future<void> importSharedDevice(MiWearState device) async {
    await _execute(
      ZeroBoxCommand(
        method: 'device.import',
        params: {'device': device.toJson()},
      ),
    );
    await _refreshSnapshot();
  }

  @override
  Future<int> importMiCloudDevices(List<MiCloudDevice> devices) async {
    var imported = 0;
    for (final device in devices.where((item) => item.hasAuthKey)) {
      await importSharedDevice(
        MiWearState(
          name: device.name.trim().isEmpty ? device.model : device.name.trim(),
          addr: device.mac.trim(),
          connectType: ConnectType.spp.name,
          authkey: device.authKey.trim(),
          disconnected: true,
        ),
      );
      imported += 1;
    }
    return imported;
  }
}
