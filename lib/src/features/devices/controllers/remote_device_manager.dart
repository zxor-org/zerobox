import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/daemon/daemon_client.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart';

class RemoteDeviceManager extends DeviceManager {
  static final _log = getLogger('RemoteDeviceManager');

  ZeroBoxDaemonClient? _client;
  StreamSubscription<CommandEvent>? _eventSubscription;
  Future<ZeroBoxDaemonClient>? _connecting;
  bool _disposed = false;

  @override
  DeviceManagerState build() {
    ref.onDispose(() {
      _disposed = true;
      unawaited(_eventSubscription?.cancel());
      unawaited(_client?.close());
    });
    scheduleMicrotask(_refreshSnapshot);
    return DeviceManagerState(pairedDevices: _loadSavedDevices());
  }

  List<MiWearState> _loadSavedDevices() {
    final rows =
        SharedPrefsService.instance.getStringList('paired_devices') ?? const [];
    return rows
        .map((row) {
          try {
            return MiWearState.fromJson(
              (jsonDecode(row) as Map).cast<String, dynamic>(),
            );
          } catch (_) {
            return null;
          }
        })
        .whereType<MiWearState>()
        .toList();
  }

  Future<ZeroBoxDaemonClient> _ensureClient() {
    final current = _client;
    if (current != null) return Future.value(current);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<ZeroBoxDaemonClient> _connect() async {
    try {
      return await _attach(await ZeroBoxDaemonClient.connect());
    } catch (_) {
      await Process.start(Platform.resolvedExecutable, const [
        '--nogui',
        'daemon',
        'run',
      ], mode: ProcessStartMode.detached);
      Object? lastError;
      for (var attempt = 0; attempt < 50; attempt += 1) {
        try {
          return await _attach(
            await ZeroBoxDaemonClient.connect(
              timeout: const Duration(milliseconds: 250),
            ),
          );
        } catch (error) {
          lastError = error;
          await Future<void>.delayed(const Duration(milliseconds: 100));
        }
      }
      throw StateError('Unable to start ZeroBox daemon: $lastError');
    }
  }

  Future<ZeroBoxDaemonClient> _attach(ZeroBoxDaemonClient client) async {
    await _eventSubscription?.cancel();
    _client = client;
    _eventSubscription = client.events.listen(_handleEvent, onDone: _detach);
    return client;
  }

  void _detach() {
    _client = null;
    if (!_disposed) {
      state = state.copyWith(
        connecting: false,
        protocolState: ProtocolState.disconnected,
        error: 'daemon_disconnected',
      );
    }
  }

  void _handleEvent(CommandEvent event) {
    if (event.event != 'device.state') return;
    final raw = event.data['state'];
    if (raw is Map) _applyState(raw.cast<String, Object?>());
  }

  Future<CommandResult> _execute(ZeroBoxCommand command) async {
    var client = await _ensureClient();
    var result = await client.execute(command);
    if (result.error?.code == 'daemon_disconnected') {
      _client = null;
      client = await _ensureClient();
      result = await client.execute(command);
    }
    if (!result.ok) {
      throw StateError('${result.error!.code}: ${result.error!.message}');
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
    state = state.copyWith(
      connecting: true,
      protocolState: ProtocolState.connecting,
      clearError: true,
    );
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
      await _execute(
        ZeroBoxCommand(method: 'device.connect', params: {'device': addr}),
      );
      await _refreshSnapshot();
    } catch (error, stackTrace) {
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
    await _execute(const ZeroBoxCommand(method: 'device.disconnect'));
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
    final directory = await getTemporaryDirectory();
    final file = File(
      '${directory.path}/zerobox_gui_${DateTime.now().microsecondsSinceEpoch}.$extension',
    );
    await file.writeAsBytes(bytes, flush: true);
    final client = await _ensureClient();
    final progressSubscription = client.events.listen((event) {
      if (event.event != 'progress') return;
      final value = event.data['progress'];
      if (value is num) onProgress?.call(value.toDouble());
    });
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
      await progressSubscription.cancel();
    }
  }

  @override
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
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
