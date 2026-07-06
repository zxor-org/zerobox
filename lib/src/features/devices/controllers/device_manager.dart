import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/providers/bluetooth_platform_provider.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/device/core/ble_transport.dart';
import 'package:zerobox/src/device/core/bluetooth_platform.dart';
import 'package:zerobox/src/device/core/connect_type.dart';
import 'package:zerobox/src/device/core/device_kind.dart';
import 'package:zerobox/src/device/core/device_profile.dart';
import 'package:zerobox/src/device/core/entity.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/runtime.dart';
import 'package:zerobox/src/device/core/spp_transport.dart';
import 'package:zerobox/src/device/core/transport.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/device/xiaomi/components/auth_system.dart';
import 'package:zerobox/src/device/xiaomi/components/info_system.dart';
import 'package:zerobox/src/device/xiaomi/components/install_system.dart';
import 'package:zerobox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:zerobox/src/device/xiaomi/xiaomi_device_factory.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart'
    hide ChargeStatus, BatteryInfo, DeviceInfo;
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_thirdparty_app.pb.dart'
    as pb_thirdparty;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;

class DeviceManagerState {
  const DeviceManagerState({
    this.currentDevice,
    this.pairedDevices = const [],
    this.scannedDevices = const [],
    this.scanning = false,
    this.connecting = false,
    this.connectStatus = 0,
    this.protocolState = ProtocolState.disconnected,
    this.battery,
    this.systemInfo,
    this.apps = const [],
    this.watchfaces = const [],
    this.error,
  });

  final MiWearState? currentDevice;
  final List<MiWearState> pairedDevices;
  final List<BTDeviceInfo> scannedDevices;
  final bool scanning;
  final bool connecting;
  final int connectStatus;
  final ProtocolState protocolState;
  final BatteryStatus? battery;
  final SystemInfo? systemInfo;
  final List<AppInfo> apps;
  final List<WatchfaceInfo> watchfaces;
  final String? error;

  DeviceManagerState copyWith({
    MiWearState? currentDevice,
    List<MiWearState>? pairedDevices,
    List<BTDeviceInfo>? scannedDevices,
    bool? scanning,
    bool? connecting,
    int? connectStatus,
    ProtocolState? protocolState,
    BatteryStatus? battery,
    SystemInfo? systemInfo,
    List<AppInfo>? apps,
    List<WatchfaceInfo>? watchfaces,
    String? error,
    bool clearCurrentDevice = false,
    bool clearBattery = false,
    bool clearSystemInfo = false,
    bool clearError = false,
  }) {
    return DeviceManagerState(
      currentDevice: clearCurrentDevice
          ? null
          : (currentDevice ?? this.currentDevice),
      pairedDevices: pairedDevices ?? this.pairedDevices,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      scanning: scanning ?? this.scanning,
      connecting: connecting ?? this.connecting,
      connectStatus: connectStatus ?? this.connectStatus,
      protocolState: protocolState ?? this.protocolState,
      battery: clearBattery ? null : (battery ?? this.battery),
      systemInfo: clearSystemInfo ? null : (systemInfo ?? this.systemInfo),
      apps: apps ?? this.apps,
      watchfaces: watchfaces ?? this.watchfaces,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeviceManager extends Notifier<DeviceManagerState> {
  @override
  DeviceManagerState build() {
    final bluetooth = ref.watch(bluetoothPlatformProvider);

    _bluetooth = bluetooth;
    _runtime = DeviceRuntime();
    _scanSubscription = _bluetooth.scanStream.listen(_onBluetoothEndpoint);
    _eventSubscription = _runtime.eventStream.listen(_onDeviceEvent);

    ref.onDispose(() {
      _log.info('DeviceManager disposed');
      _scanTimer?.cancel();
      _stopConnectionWatchdog();
      _scanSubscription?.cancel();
      _bluetooth.stopScan();
      _eventSubscription?.cancel();
      _cleanupConnection();
      _runtime.dispose();
    });

    _log.info('DeviceManager created');
    final initialState = _loadStateSync();

    if (initialState.pairedDevices.isNotEmpty &&
        _shouldAutoReconnect() &&
        !kIsWeb) {
      final last = initialState.pairedDevices.first;
      final authKey = last.authkey;
      if (authKey != null && authKey.isNotEmpty) {
        _log.info(
          'auto reconnect enabled, attempting reconnect to ${last.addr}',
        );
        Future.microtask(() {
          connect(
            last.addr,
            last.name,
            authKey,
            connectType: last.connectType,
          ).catchError((Object e, StackTrace st) {
            _log.warning('auto reconnect to ${last.addr} failed', e, st);
            return;
          });
        });
      } else {
        _log.warning('auto reconnect skipped: no auth key for ${last.addr}');
      }
    }

    return initialState;
  }

  static final _log = getLogger('DeviceManager');
  late BluetoothPlatform _bluetooth;
  late DeviceRuntime _runtime;
  StreamSubscription<BluetoothEndpoint>? _scanSubscription;
  StreamSubscription<DeviceEvent>? _eventSubscription;
  Timer? _scanTimer;
  Timer? _connectionWatchdogTimer;
  BluetoothConnection? _bluetoothConnection;
  DeviceEntity? _currentEntity;
  bool _connectionProbeRunning = false;
  bool _installBusy = false;
  int _connectionProbeFailures = 0;

  static const String _keyPairedDevices = 'paired_devices';
  static const String _keyAutoReconnect = 'auto_reconnect';

  DeviceManagerState _loadStateSync() {
    final prefs = SharedPrefsService.instance;
    final saved = prefs.getStringList(_keyPairedDevices) ?? [];
    final paired = saved
        .map((e) {
          try {
            return _normalizeDeviceIdentity(
              MiWearState.fromJson(jsonDecode(e) as Map<String, dynamic>),
            );
          } catch (e, st) {
            _log.warning('failed to parse paired device', e, st);
            return null;
          }
        })
        .whereType<MiWearState>()
        .toList();

    _log.info('loaded ${paired.length} paired devices');
    return DeviceManagerState(
      pairedDevices: paired,
      currentDevice: null,
      protocolState: ProtocolState.disconnected,
    );
  }

  bool _shouldAutoReconnect() {
    try {
      return SharedPrefsService.instance.getBool(_keyAutoReconnect) ?? false;
    } catch (e) {
      return false;
    }
  }

  Future<void> _savePairedDevices() async {
    final jsonList = state.pairedDevices
        .map((d) => jsonEncode(d.toJson()))
        .toList();
    final saved = await SharedPrefsService.instance.setStringList(
      _keyPairedDevices,
      jsonList,
    );
    _log.info(
      'saved ${jsonList.length} paired devices '
      'to $_keyPairedDevices result=$saved',
    );
  }

  Future<void> startBluetoothScan({
    ConnectType connectType = ConnectType.ble,
  }) async {
    if (state.scanning) return;
    state = state.copyWith(
      scanning: true,
      scannedDevices: const [],
      clearError: true,
    );

    final available = await _bluetooth.isAvailable();
    if (!available) {
      _log.warning('bluetooth not available');
      state = state.copyWith(
        scanning: false,
        error: 'Bluetooth is not available',
      );
      return;
    }

    try {
      await _bluetooth.requestPermissions();
      await _bluetooth.startScan(
        BluetoothScanOptions(
          connectTypes: {connectType},
          timeout: const Duration(seconds: 15),
        ),
      );

      _scanTimer?.cancel();
      _scanTimer = Timer(const Duration(seconds: 15), () {
        stopBluetoothScan();
      });
    } catch (e, st) {
      _log.severe('start scan failed', e, st);
      state = state.copyWith(scanning: false, error: e.toString());
    }
  }

  Future<void> stopBluetoothScan() async {
    _log.info('stopping scan');
    _scanTimer?.cancel();
    await _bluetooth.stopScan();
    state = state.copyWith(scanning: false);
  }

  void _onBluetoothEndpoint(BluetoothEndpoint endpoint) {
    final exists = state.scannedDevices.any((d) => d.addr == endpoint.address);
    if (exists) return;

    final savedAddrs = state.pairedDevices.map((d) => d.addr).toSet();
    if (savedAddrs.contains(endpoint.address)) return;

    final displayName = xiaomiDisplayNameForIdentity(name: endpoint.name);
    final resolvedProfile = DeviceRegistry.resolveIdentity(name: endpoint.name);
    _log.fine(
      'scan add ${endpoint.address} "$displayName" '
      'via ${resolvedProfile.preferredConnectType.name}',
    );
    state = state.copyWith(
      scannedDevices: [
        ...state.scannedDevices,
        BTDeviceInfo(
          name: displayName,
          addr: endpoint.address,
          connectType: resolvedProfile.preferredConnectType.name,
        ),
      ],
    );
  }

  MiWearState _normalizeDeviceIdentity(MiWearState device) {
    final identity =
        xiaomiWearableIdentityForCodename(device.codename) ??
        normalizeXiaomiWearableIdentity(device.name);
    return device.copyWith(
      name: xiaomiDisplayNameForIdentity(
        name: device.name,
        codename: identity?.codename ?? device.codename,
      ),
      codename: identity?.codename ?? device.codename,
    );
  }

  Future<BluetoothConnection> _connectBluetoothWithRetry(
    String addr,
    String name,
    DeviceProfile profile,
    ConnectType connectType,
  ) async {
    final maxAttempts = connectType == ConnectType.spp ? 2 : 3;
    final timeout = connectType == ConnectType.spp
        ? const Duration(seconds: 12)
        : const Duration(seconds: 10);
    Exception? lastError;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _log.info(
        '${connectType.name.toUpperCase()} connect attempt '
        '$attempt/$maxAttempts to $addr',
      );
      try {
        final connection = await _bluetooth
            .connect(
              addr,
              name,
              BluetoothConnectOptions(
                connectType: connectType,
                bleRequiredCharacteristics: profile.bleRequiredCharacteristics,
                bleDesiredMtu: profile.bleDesiredMtu,
                sppServiceUuid: profile.classicServiceUuid,
                sppFallbackChannels: profile.classicFallbackChannels,
              ),
            )
            .timeout(timeout);
        _log.info(
          '${connectType.name.toUpperCase()} connected on attempt $attempt',
        );
        return connection;
      } on TimeoutException catch (e) {
        lastError = e;
        _log.warning(
          '${connectType.name.toUpperCase()} connect attempt $attempt timed out',
        );
        await _resetBluetoothAfterFailedConnect(connectType);
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        _log.warning(
          '${connectType.name.toUpperCase()} connect attempt $attempt failed: $e',
        );
        await _resetBluetoothAfterFailedConnect(connectType);
      }

      if (attempt < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }

    throw lastError ??
        Exception(
          '${connectType.name} connect failed after $maxAttempts attempts',
        );
  }

  Future<void> _resetBluetoothAfterFailedConnect(
    ConnectType connectType,
  ) async {
    try {
      await _bluetooth.disconnect().timeout(const Duration(seconds: 2));
    } catch (e) {
      _log.fine(
        '${connectType.name.toUpperCase()} disconnect after failed connect ignored: $e',
      );
    }

    if (connectType == ConnectType.spp) {
      await Future.delayed(const Duration(milliseconds: 300));
    }
  }

  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  }) async {
    final existingDevice = state.pairedDevices
        .where((d) => d.addr == addr)
        .firstOrNull;
    final identity =
        xiaomiWearableIdentityForCodename(existingDevice?.codename) ??
        normalizeXiaomiWearableIdentity(name);
    final effectiveCodename = identity?.codename ?? existingDevice?.codename;
    final displayName = xiaomiDisplayNameForIdentity(
      name: name,
      codename: effectiveCodename,
    );
    final profile = DeviceRegistry.resolveIdentity(
      name: displayName,
      codename: effectiveCodename,
    );
    final profileSource = identity != null
        ? 'codename:${identity.codename}'
        : 'name';
    final effectiveKind = kind == DeviceKind.xiaomi ? profile.kind : kind;
    final requestedConnectType = connectType.toLowerCase().isEmpty
        ? profile.preferredConnectType.name
        : connectType.toLowerCase();
    final effectiveConnectType = kIsWeb
        ? ConnectType.spp.name
        : requestedConnectType;
    _log.info(
      'connect request $addr rawName="$name" displayName="$displayName" '
      'codename="$effectiveCodename" via=$effectiveConnectType '
      'profile=${profile.id} source=$profileSource authkey="$authKey"',
    );
    _log.info('connecting to $displayName @ $addr via $effectiveConnectType');
    state = state.copyWith(
      connecting: true,
      connectStatus: 1,
      protocolState: ProtocolState.connecting,
      clearError: true,
    );
    try {
      await stopBluetoothScan();
      await _cleanupConnection();

      if (effectiveKind != DeviceKind.xiaomi) {
        throw UnsupportedError(
          '${deviceKindLabel(effectiveKind)} protocol is not implemented yet',
        );
      }

      final transportType = effectiveConnectType == ConnectType.spp.name
          ? ConnectType.spp
          : ConnectType.ble;
      _bluetoothConnection = await _connectBluetoothWithRetry(
        addr,
        displayName,
        profile,
        transportType,
      );

      final Transport transport;
      if (transportType == ConnectType.spp) {
        final sppTransport = SppTransport.xiaomiBluetooth(
          _bluetoothConnection!,
        );
        await sppTransport.start();
        transport = sppTransport;
      } else {
        final bleTransport = BleTransport.xiaomiBluetooth(
          _bluetoothConnection!,
        );
        await bleTransport.start();
        transport = bleTransport;
      }

      final entity = _runtime.spawnDevice(
        id: addr,
        kind: deviceKindString(kind),
        transport: transport,
        factory: XiaomiDeviceFactory(),
      );
      _currentEntity = entity;

      final component = entity.get<XiaomiDeviceComponent>()!;
      await component
          .startSession(
            spp: effectiveConnectType.toLowerCase() == ConnectType.spp.name,
          )
          .timeout(const Duration(seconds: 10));

      final authSystem = entity.system<XiaomiAuthSystem>()!;
      _log.info('starting authentication');
      await authSystem
          .authenticate(authKey)
          .timeout(const Duration(seconds: 10));
      _log.info('authentication succeeded');

      final connected = MiWearState(
        name: displayName,
        addr: addr,
        connectType: effectiveConnectType,
        authkey: authKey,
        codename: effectiveCodename,
        disconnected: false,
      );
      final existingIndex = state.pairedDevices.indexWhere(
        (d) => d.addr == addr,
      );
      final updatedPaired = List<MiWearState>.from(state.pairedDevices);
      if (existingIndex >= 0) {
        updatedPaired[existingIndex] = connected;
      } else {
        updatedPaired.add(connected);
      }

      state = state.copyWith(
        currentDevice: connected,
        pairedDevices: updatedPaired,
        connecting: false,
        connectStatus: 2,
        protocolState: ProtocolState.ready,
      );
      _startConnectionWatchdog(addr);
      await _savePairedDevices();
      unawaited(_loadInitialDeviceData(entity));
    } catch (e, st) {
      _log.severe('connect to $addr failed', e, st);
      state = state.copyWith(
        connecting: false,
        connectStatus: 3,
        protocolState: ProtocolState.error,
        error: e.toString(),
      );
      await _cleanupConnection();
    }
  }

  Future<void> _loadInitialDeviceData(DeviceEntity entity) async {
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) return;
    try {
      await infoSystem.fetchBatteryInfo();
    } catch (e, st) {
      _log.warning('initial battery fetch failed', e, st);
    }
    try {
      await infoSystem.fetchDeviceInfo();
    } catch (e, st) {
      _log.warning('initial device info fetch failed', e, st);
    }
  }

  void _startConnectionWatchdog(String deviceId) {
    _stopConnectionWatchdog();
    _connectionProbeFailures = 0;
    _connectionWatchdogTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      unawaited(_probeConnection(deviceId));
    });
  }

  void _stopConnectionWatchdog() {
    _connectionWatchdogTimer?.cancel();
    _connectionWatchdogTimer = null;
    _connectionProbeRunning = false;
    _connectionProbeFailures = 0;
  }

  Future<void> _probeConnection(String deviceId) async {
    if (_connectionProbeRunning || _installBusy) return;

    final entity = _currentEntity;
    if (entity == null ||
        entity.id != deviceId ||
        state.currentDevice?.addr != deviceId ||
        state.protocolState != ProtocolState.ready) {
      return;
    }

    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) return;

    _connectionProbeRunning = true;
    try {
      await infoSystem.fetchBatteryInfo().timeout(const Duration(seconds: 4));
      _connectionProbeFailures = 0;
    } catch (e, st) {
      _connectionProbeFailures += 1;
      _log.warning(
        'connection probe failed ($_connectionProbeFailures/2) for $deviceId',
        e,
        st,
      );
      if (_connectionProbeFailures >= 2 &&
          _currentEntity?.id == deviceId &&
          state.currentDevice?.addr == deviceId &&
          state.protocolState == ProtocolState.ready) {
        _log.warning('connection probe marked $deviceId as disconnected');
        _onDisconnected();
      }
    } finally {
      _connectionProbeRunning = false;
    }
  }

  void _onDeviceEvent(DeviceEvent event) {
    if (event.deviceId != state.currentDevice?.addr) return;

    switch (event) {
      case DeviceAuthenticated _:
        _log.info('event: authenticated');
        state = state.copyWith(protocolState: ProtocolState.ready);
      case AuthFailed(:final error):
        _log.warning('event: auth failed: $error');
        state = state.copyWith(
          protocolState: ProtocolState.error,
          error: error,
        );
      case TransportDisconnected _:
        _log.warning('event: transport disconnected');
        _onDisconnected();
      case BatteryUpdated(:final battery):
        _log.info('event: battery ${battery.capacity}%');
        state = state.copyWith(battery: battery);
      case DeviceInfoUpdated(:final info):
        _log.info(
          'device info ${event.deviceId}: model=${info.model}, '
          'fw=${info.firmwareVersion}',
        );
        state = state.copyWith(systemInfo: info);
        final current = state.currentDevice;
        final identity = normalizeXiaomiWearableIdentity(info.model);
        if (current != null && identity != null) {
          final normalized = current.copyWith(
            name: identity.displayName,
            codename: identity.codename,
          );
          final updatedPaired = state.pairedDevices.map((device) {
            return device.addr == current.addr ? normalized : device;
          }).toList();
          state = state.copyWith(
            currentDevice: normalized,
            pairedDevices: updatedPaired,
          );
          _log.info(
            'normalized ${current.addr}: ${info.model} -> '
            '${identity.codename} (${identity.displayName})',
          );
          unawaited(_savePairedDevices());
        }
      case AppListUpdated(:final apps):
        _log.info('event: app list ${apps.length}');
        state = state.copyWith(apps: apps);
      case StorageInfoUpdated(:final info):
        _log.info('storage info ${event.deviceId}: used=${info.used}, total=${info.total}');
        final currentInfo = state.systemInfo;
        state = state.copyWith(
          systemInfo: currentInfo?.copyWith(storageInfo: info) ??
              SystemInfo(
                serialNumber: '',
                firmwareVersion: '',
                imei: '',
                model: '',
                storageInfo: info,
              ),
        );
      case WatchfaceListUpdated(:final watchfaces):
        _log.info('event: watchface list ${watchfaces.length}');
        state = state.copyWith(watchfaces: watchfaces);
      case InstallProgress _:
        // Progress is consumed via callback in install UI.
        break;
      case InstallCompleted _:
        _log.info('event: install completed');
      case InstallFailed(:final error):
        _log.warning('event: install failed: $error');
        state = state.copyWith(error: error);
      case DeviceError(:final error):
        _log.warning('event: device error: $error');
        state = state.copyWith(error: error);
      default:
        break;
    }
  }

  void _onDisconnected() {
    final current = state.currentDevice;
    if (current == null) {
      state = state.copyWith(
        connecting: false,
        connectStatus: 0,
        protocolState: ProtocolState.disconnected,
        clearBattery: true,
        clearSystemInfo: true,
        clearError: true,
      );
      unawaited(_cleanupConnection());
      return;
    }
    final disconnected = current.copyWith(disconnected: true);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      connecting: false,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearSystemInfo: true,
      clearError: true,
    );
    _savePairedDevices();
    _cleanupConnection();
  }

  Future<void> disconnect() async {
    final current = state.currentDevice;
    if (current == null) {
      await _cleanupConnection();
      state = state.copyWith(
        connecting: false,
        connectStatus: 0,
        protocolState: ProtocolState.disconnected,
        clearBattery: true,
        clearSystemInfo: true,
        clearError: true,
      );
      return;
    }
    final disconnected = current.copyWith(disconnected: true);
    final updatedPaired = state.pairedDevices.map((d) {
      return d.addr == current.addr ? disconnected : d;
    }).toList();
    await _cleanupConnection();
    state = state.copyWith(
      currentDevice: disconnected,
      pairedDevices: updatedPaired,
      connecting: false,
      connectStatus: 0,
      protocolState: ProtocolState.disconnected,
      clearBattery: true,
      clearSystemInfo: true,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<void> _cleanupConnection() async {
    _stopConnectionWatchdog();
    final connection = _bluetoothConnection;
    final entity = _currentEntity;
    _bluetoothConnection = null;
    _currentEntity = null;

    if (entity != null) {
      _log.info('cleaning up connection to ${entity.id}');
      await _runtime.removeDevice(entity.id);
    }

    final futures = <Future<void>>[];
    if (connection != null && entity == null) {
      futures.add(
        connection.dispose().catchError((Object e, StackTrace st) {
          _log.warning('Bluetooth connection dispose failed', e, st);
        }),
      );
    }
    await Future.wait(futures);
  }

  Future<void> removeDevice(String addr) async {
    final updatedPaired = state.pairedDevices
        .where((d) => d.addr != addr)
        .toList();
    final removedCurrent = state.currentDevice?.addr == addr;
    if (removedCurrent) {
      await _cleanupConnection();
    }
    state = state.copyWith(
      pairedDevices: updatedPaired,
      currentDevice: removedCurrent ? null : state.currentDevice,
      connecting: removedCurrent ? false : state.connecting,
      connectStatus: removedCurrent ? 0 : state.connectStatus,
      protocolState: removedCurrent
          ? ProtocolState.disconnected
          : state.protocolState,
      clearBattery: removedCurrent,
      clearSystemInfo: removedCurrent,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<void> refreshBattery() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchBatteryInfo();
  }

  Future<void> fetchSystemInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchDeviceInfo();
  }

  Future<void> fetchStorageInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchStorageInfo();
  }

  Future<void> fetchApps() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    await infoSystem.fetchInstalledApps();
  }

  Future<void> fetchWatchfaces() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    final watchfaces = await infoSystem.fetchInstalledWatchfaces();
    state = state.copyWith(watchfaces: watchfaces);
  }

  Future<void> uninstallApp(AppInfo app) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('uninstalling app ${app.packageName}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.THIRDPARTY_APP,
      id: pb_thirdparty.ThirdpartyApp_ThirdpartyAppID.REMOVE_APP.value,
      thirdpartyApp: pb_thirdparty.ThirdpartyApp(
        basicInfo: pb_thirdparty.BasicInfo(packageName: app.packageName),
      ),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      apps: state.apps.where((a) => a.packageName != app.packageName).toList(),
    );
  }

  Future<void> uninstallWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('uninstalling watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.REMOVE_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.where((w) => w.id != watchface.id).toList(),
    );
  }

  Future<void> setWatchface(WatchfaceInfo watchface) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('setting watchface ${watchface.id}');
    final packet = pb.WearPacket(
      type: pb.WearPacket_Type.WATCH_FACE,
      id: pb_watchface.WatchFace_WatchFaceID.SET_WATCH_FACE.value,
      watchFace: pb_watchface.WatchFace(id: watchface.id),
    );
    await entity.get<XiaomiDeviceComponent>()!.sendPbPacket(packet);
    state = state.copyWith(
      watchfaces: state.watchfaces.map((w) {
        return w.id == watchface.id
            ? w.copyWith(isCurrent: true)
            : w.copyWith(isCurrent: false);
      }).toList(),
    );
  }

  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('installing app $packageName (${packageBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    _installBusy = true;
    try {
      await installSystem.installApp(
        packageBytes,
        packageName: packageName,
        onProgress: onProgress,
      );
    } finally {
      _installBusy = false;
    }
  }

  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info(
      'installing watchface $watchfaceId (${watchfaceBytes.length} bytes)',
    );
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    _installBusy = true;
    try {
      await installSystem.installWatchface(
        watchfaceBytes,
        watchfaceId: watchfaceId,
        onProgress: onProgress,
      );
    } finally {
      _installBusy = false;
    }
  }

  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    _log.info('installing firmware (${firmwareBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    _installBusy = true;
    try {
      await installSystem.installFirmware(
        firmwareBytes,
        onProgress: onProgress,
      );
    } finally {
      _installBusy = false;
    }
  }

  Future<void> importSharedDevice(MiWearState device) async {
    final normalized = _normalizeDeviceIdentity(device).copyWith(
      connectType: device.connectType.toLowerCase().isEmpty
          ? ConnectType.spp.name
          : device.connectType.toLowerCase(),
      disconnected: true,
    );
    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    final existingIndex = updatedPaired.indexWhere(
      (d) => d.addr == normalized.addr,
    );
    if (existingIndex >= 0) {
      updatedPaired[existingIndex] = normalized;
    } else {
      updatedPaired.add(normalized);
    }
    state = state.copyWith(
      currentDevice:
          state.currentDevice == null ||
              state.currentDevice?.addr == normalized.addr
          ? normalized
          : state.currentDevice,
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
  }

  Future<int> importMiCloudDevices(List<MiCloudDevice> devices) async {
    final importable = devices.where((device) => device.hasAuthKey).toList();
    _log.info(
      'importing ${importable.length}/${devices.length} Mi Cloud devices',
    );
    if (importable.isEmpty) return 0;

    final updatedPaired = List<MiWearState>.from(state.pairedDevices);
    for (final device in importable) {
      final identity = normalizeXiaomiWearableIdentity(device.model);
      final importedRaw = _normalizeDeviceIdentity(
        MiWearState(
          name: device.name.trim().isNotEmpty
              ? device.name.trim()
              : (identity?.displayName ?? device.model),
          addr: device.mac.trim(),
          connectType: ConnectType.spp.name,
          authkey: device.authKey.trim(),
          codename: identity?.codename,
          disconnected: true,
        ),
      );
      final existingIndex = updatedPaired.indexWhere(
        (d) => d.addr == importedRaw.addr,
      );
      final existing = existingIndex >= 0 ? updatedPaired[existingIndex] : null;
      final isCurrentReady =
          state.currentDevice?.addr == importedRaw.addr &&
          state.protocolState == ProtocolState.ready;
      final imported = importedRaw.copyWith(
        disconnected: isCurrentReady ? false : (existing?.disconnected ?? true),
      );
      if (existingIndex >= 0) {
        updatedPaired[existingIndex] = imported;
      } else {
        updatedPaired.add(imported);
      }
    }

    final current = state.currentDevice;
    state = state.copyWith(
      currentDevice: current == null
          ? updatedPaired.firstWhere(
              (d) => d.addr == importable.first.mac.trim(),
            )
          : updatedPaired.firstWhere(
              (d) => d.addr == current.addr,
              orElse: () => current,
            ),
      pairedDevices: updatedPaired,
      clearError: true,
    );
    await _savePairedDevices();
    return importable.length;
  }
}

final deviceManagerProvider =
    NotifierProvider<DeviceManager, DeviceManagerState>(
      DeviceManager.new,
      isAutoDispose: true,
    );
