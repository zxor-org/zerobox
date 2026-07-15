import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/core/providers/bluetooth_platform_provider.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/device/core/ble_requirement.dart';
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
import 'package:zerobox/src/device/xiaomi/components/resource_system.dart';
import 'package:zerobox/src/device/xiaomi/components/thirdparty_app_system.dart';
import 'package:zerobox/src/device/xiaomi/components/xiaomi_device_component.dart';
import 'package:zerobox/src/device/xiaomi/xiaomi_device_factory.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_auth_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_apps_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_app_install_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_app_side_system.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';
import 'package:zerobox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_battery_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_device_info_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_find_device_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_services_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_screenshot_system.dart';
import 'package:zerobox/src/device/zeppos/systems/zeppos_xiao_ai_system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_catalog.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_factory.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart'
    hide ChargeStatus, BatteryInfo, DeviceInfo;
import 'package:zerobox/src/protocols/generated/xiaomi/wear.pb.dart' as pb;
import 'package:zerobox/src/protocols/generated/xiaomi/wear_watch_face.pb.dart'
    as pb_watchface;

class ZeppOsMessageRecord {
  const ZeppOsMessageRecord({
    required this.timestamp,
    required this.endpoint,
    required this.payload,
  });

  final DateTime timestamp;
  final int endpoint;
  final List<int> payload;

  Map<String, Object?> toJson() => {
    'timestamp': timestamp.toIso8601String(),
    'endpoint': endpoint,
    'payload': payload,
  };

  factory ZeppOsMessageRecord.fromJson(Map<String, dynamic> json) {
    return ZeppOsMessageRecord(
      timestamp:
          DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      endpoint: (json['endpoint'] as num?)?.toInt() ?? 0,
      payload:
          (json['payload'] as List?)
              ?.whereType<num>()
              .map((value) => value.toInt() & 0xff)
              .toList(growable: false) ??
          const [],
    );
  }
}

class DeviceManagerState {
  const DeviceManagerState({
    this.currentDevice,
    this.pairedDevices = const [],
    this.scannedDevices = const [],
    this.scanning = false,
    this.connecting = false,
    this.connectionTargetAddr,
    this.connectionTargetName,
    this.connectionPhase,
    this.connectStatus = 0,
    this.protocolState = ProtocolState.disconnected,
    this.battery,
    this.systemInfo,
    this.apps = const [],
    this.watchfaces = const [],
    this.zeppOsMessages = const [],
    this.xiaoAiActive = false,
    this.xiaoAiFrameCount = 0,
    this.xiaoAiCapabilities = const {},
    this.error,
  });

  final MiWearState? currentDevice;
  final List<MiWearState> pairedDevices;
  final List<BTDeviceInfo> scannedDevices;
  final bool scanning;
  final bool connecting;
  final String? connectionTargetAddr;
  final String? connectionTargetName;
  final DeviceConnectionPhase? connectionPhase;
  final int connectStatus;
  final ProtocolState protocolState;
  final BatteryStatus? battery;
  final SystemInfo? systemInfo;
  final List<AppInfo> apps;
  final List<WatchfaceInfo> watchfaces;
  final List<ZeppOsMessageRecord> zeppOsMessages;
  final bool xiaoAiActive;
  final int xiaoAiFrameCount;
  final Map<String, Object?> xiaoAiCapabilities;
  final String? error;

  DeviceManagerState copyWith({
    MiWearState? currentDevice,
    List<MiWearState>? pairedDevices,
    List<BTDeviceInfo>? scannedDevices,
    bool? scanning,
    bool? connecting,
    String? connectionTargetAddr,
    String? connectionTargetName,
    DeviceConnectionPhase? connectionPhase,
    int? connectStatus,
    ProtocolState? protocolState,
    BatteryStatus? battery,
    SystemInfo? systemInfo,
    List<AppInfo>? apps,
    List<WatchfaceInfo>? watchfaces,
    List<ZeppOsMessageRecord>? zeppOsMessages,
    bool? xiaoAiActive,
    int? xiaoAiFrameCount,
    Map<String, Object?>? xiaoAiCapabilities,
    String? error,
    bool clearCurrentDevice = false,
    bool clearBattery = false,
    bool clearSystemInfo = false,
    bool clearError = false,
    bool clearConnectionTarget = false,
    bool clearConnectionPhase = false,
  }) {
    return DeviceManagerState(
      currentDevice: clearCurrentDevice
          ? null
          : (currentDevice ?? this.currentDevice),
      pairedDevices: pairedDevices ?? this.pairedDevices,
      scannedDevices: scannedDevices ?? this.scannedDevices,
      scanning: scanning ?? this.scanning,
      connecting: connecting ?? this.connecting,
      connectionTargetAddr: clearConnectionTarget
          ? null
          : (connectionTargetAddr ?? this.connectionTargetAddr),
      connectionTargetName: clearConnectionTarget
          ? null
          : (connectionTargetName ?? this.connectionTargetName),
      connectionPhase: clearConnectionPhase
          ? null
          : (connectionPhase ?? this.connectionPhase),
      connectStatus: connectStatus ?? this.connectStatus,
      protocolState: protocolState ?? this.protocolState,
      battery: clearBattery ? null : (battery ?? this.battery),
      systemInfo: clearSystemInfo ? null : (systemInfo ?? this.systemInfo),
      apps: apps ?? this.apps,
      watchfaces: watchfaces ?? this.watchfaces,
      zeppOsMessages: zeppOsMessages ?? this.zeppOsMessages,
      xiaoAiActive: xiaoAiActive ?? this.xiaoAiActive,
      xiaoAiFrameCount: xiaoAiFrameCount ?? this.xiaoAiFrameCount,
      xiaoAiCapabilities: xiaoAiCapabilities ?? this.xiaoAiCapabilities,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

enum DeviceConnectionPhase {
  preparing,
  connectingTransport,
  initializingProtocol,
  authenticating,
  fetchingDeviceStatus,
}

class _DeviceConnectCancelled implements Exception {
  const _DeviceConnectCancelled();
}

abstract class DeviceManager extends Notifier<DeviceManagerState> {
  static const errorBluetoothUnavailable = 'bluetooth_unavailable';
  final _xiaoAiOpusFrames = StreamController<Uint8List>.broadcast();
  final _interconnectMessages =
      StreamController<InterconnectMessage>.broadcast();
  final _rawProtocolFrames = StreamController<Uint8List>.broadcast();

  Stream<Uint8List> get xiaoAiOpusFrames => _xiaoAiOpusFrames.stream;
  Stream<InterconnectMessage> get interconnectMessages =>
      _interconnectMessages.stream;
  Stream<Uint8List> get rawProtocolFrames => _rawProtocolFrames.stream;

  @protected
  void emitXiaoAiOpusFrame(Uint8List frame) {
    _xiaoAiOpusFrames.add(frame);
  }

  @protected
  void emitInterconnectMessage(InterconnectMessage message) {
    _interconnectMessages.add(message);
  }

  Future<void> startBluetoothScan({ConnectType connectType = ConnectType.ble});
  Future<void> stopBluetoothScan();
  Future<void> connect(
    String addr,
    String name,
    String authKey, {
    DeviceKind kind = DeviceKind.xiaomi,
    String connectType = 'ble',
  });
  Future<void> disconnect();
  Future<void> cancelConnect();
  Future<void> removeDevice(String addr);
  Future<void> refreshBattery();
  Future<void> refreshDeviceData();
  Future<void> setFindingZeppOsDevice(bool finding);
  Future<void> sendXiaoAiReply(String text);
  Future<void> setXiaoAiContinuousCapture(bool enabled);
  Future<void> setXiaoAiEndpoint(int endpoint);
  Future<Uint8List> requestZeppOsScreenshot();
  void clearZeppOsMessages();
  Future<List<int>> listZeppOsAppSides();
  Future<List<int>> observedZeppOsAppSideIds();
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions();
  Future<List<ZeppOsAppSideDebugEvent>> zeppOsAppSideEvents(int appId);
  Future<void> clearZeppOsAppSideEvents(int appId);
  Future<void> startZeppOsAppSide(int appId);
  Future<void> stopZeppOsAppSide(int appId);
  Future<void> injectZeppOsAppSideMessage(int appId, Uint8List payload);
  Future<void> sendZeppOsAppSideMessage(int appId, Uint8List payload);
  Future<void> fetchSystemInfo();
  Future<void> fetchStorageInfo();
  Future<void> fetchApps();
  Future<void> fetchWatchfaces();
  Future<void> openApp(AppInfo app, {String page = ''});
  Future<void> sendRaw(Uint8List payload);
  Future<void> sendInterconnectMessage(String packageName, Uint8List payload);
  Future<void> uninstallApp(AppInfo app);
  Future<void> uninstallWatchface(WatchfaceInfo watchface);
  Future<void> setWatchface(WatchfaceInfo watchface);
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  });
  Future<void> installWatchface(
    Uint8List watchfaceBytes, {
    required String watchfaceId,
    void Function(double progress)? onProgress,
  });
  Future<void> installFirmware(
    Uint8List firmwareBytes, {
    void Function(double progress)? onProgress,
  });
  Future<void> importSharedDevice(MiWearState device);
  Future<int> importMiCloudDevices(List<MiCloudDevice> devices);
}

class LocalDeviceManager extends DeviceManager {
  static const errorBluetoothUnavailable =
      DeviceManager.errorBluetoothUnavailable;

  @override
  DeviceManagerState build() {
    final bluetooth = ref.read(bluetoothPlatformProvider);

    _bluetooth = bluetooth;
    _runtime = DeviceRuntime();
    _scanSubscription = _bluetooth.scanStream.listen(_onBluetoothEndpoint);
    _eventSubscription = _runtime.eventStream.listen(_onDeviceEvent);

    ref.onDispose(() {
      _log.info('DeviceManager disposed');
      unawaited(_xiaoAiOpusFrames.close());
      unawaited(_interconnectMessages.close());
      unawaited(_rawProtocolFrames.close());
      _scanTimer?.cancel();
      _batteryRefreshTimer?.cancel();
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
  static const _defaultConnectMaxAttempts = 1;
  static const _macOsSppConnectMaxAttempts = 2;
  static const _defaultConnectRetryDelay = Duration(milliseconds: 300);
  static const _macOsSppConnectRetryDelay = Duration(seconds: 4);
  static const _sppFailedConnectSettleDelay = Duration(milliseconds: 500);
  static const _zeppOsBleServiceUuid = '00001530-0000-3512-2118-0009af100700';

  late BluetoothPlatform _bluetooth;
  late DeviceRuntime _runtime;
  StreamSubscription<BluetoothEndpoint>? _scanSubscription;
  StreamSubscription<DeviceEvent>? _eventSubscription;
  StreamSubscription<Uint8List>? _rawProtocolSubscription;
  Timer? _scanTimer;
  Timer? _batteryRefreshTimer;
  bool _batteryRefreshInProgress = false;
  BluetoothConnection? _bluetoothConnection;
  DeviceEntity? _currentEntity;
  final _scannedProfiles = <String, DeviceProfile>{};
  var _connectGeneration = 0;

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

  @override
  Future<void> startBluetoothScan({
    ConnectType connectType = ConnectType.ble,
  }) async {
    if (state.scanning) return;
    state = state.copyWith(
      scanning: true,
      scannedDevices: const [],
      clearError: true,
    );
    _scannedProfiles.clear();

    if (!kIsWeb) {
      final available = await _bluetooth.isAvailable();
      if (!available) {
        _log.warning('bluetooth not available');
        state = state.copyWith(
          scanning: false,
          error: errorBluetoothUnavailable,
        );
        return;
      }
    }

    try {
      await _bluetooth.requestPermissions();
      await _bluetooth.startScan(
        BluetoothScanOptions(
          connectTypes: _scanConnectTypes(connectType),
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

  Set<ConnectType> _scanConnectTypes(ConnectType connectType) {
    if (kIsWeb) return const {ConnectType.spp};
    if (connectType == ConnectType.ble) {
      return const {ConnectType.ble, ConnectType.spp};
    }
    return {connectType};
  }

  @override
  Future<void> stopBluetoothScan() async {
    _log.info('stopping scan');
    _scanTimer?.cancel();
    await _bluetooth.stopScan();
    state = state.copyWith(scanning: false);
  }

  void _onBluetoothEndpoint(BluetoothEndpoint endpoint) {
    final endpointName = endpoint.name.trim();
    if (endpointName.isEmpty || endpointName == 'Unknown device') return;

    final savedAddrs = state.pairedDevices.map((d) => d.addr).toSet();
    if (savedAddrs.contains(endpoint.address)) return;

    final resolvedProfile = _resolveEndpointProfile(endpoint);
    if (resolvedProfile.id != DeviceRegistry.unknown.id &&
        endpoint.connectType != resolvedProfile.preferredConnectType) {
      _log.fine(
        'scan ignore ${endpoint.connectType.name} endpoint '
        '${endpoint.address} for ${resolvedProfile.id}; expected '
        '${resolvedProfile.preferredConnectType.name}',
      );
      return;
    }
    // A discovered endpoint must retain its real transport. Previously a
    // ZeppOS Classic/RFCOMM result was relabelled with the profile's preferred
    // BLE transport, causing its Classic address to be passed to GATT. BTBR is
    // not protocol-ready yet, so do not offer those endpoints as connectable.
    if (resolvedProfile.kind == DeviceKind.zepp &&
        endpoint.connectType != ConnectType.ble) {
      _log.fine(
        'scan ignore ZeppOS ${endpoint.connectType.name} endpoint '
        '${endpoint.address}; BTBR is not implemented',
      );
      return;
    }
    _scannedProfiles[endpoint.address] = resolvedProfile;
    final rawDisplayName = xiaomiDisplayNameForIdentity(name: endpointName);
    final displayName = _scanDisplayName(endpoint, rawDisplayName);
    final existingIndex = state.scannedDevices.indexWhere(
      (d) => d.addr == endpoint.address,
    );
    if (existingIndex >= 0) {
      final existing = state.scannedDevices[existingIndex];
      final existingProfile = DeviceRegistry.resolveIdentity(
        name: existing.name,
      );
      if (existingProfile.kind == DeviceKind.zepp ||
          resolvedProfile.kind != DeviceKind.zepp) {
        return;
      }
      final updated = List<BTDeviceInfo>.from(state.scannedDevices);
      updated[existingIndex] = BTDeviceInfo(
        name: displayName,
        addr: endpoint.address,
        connectType: endpoint.connectType.name,
      );
      state = state.copyWith(scannedDevices: _sortScannedDevices(updated));
      return;
    }
    _log.fine(
      'scan add ${endpoint.address} "$displayName" '
      'via ${endpoint.connectType.name}',
    );
    state = state.copyWith(
      scannedDevices: _sortScannedDevices([
        ...state.scannedDevices,
        BTDeviceInfo(
          name: displayName,
          addr: endpoint.address,
          connectType: endpoint.connectType.name,
        ),
      ]),
    );
  }

  List<BTDeviceInfo> _sortScannedDevices(List<BTDeviceInfo> devices) {
    final sorted = List<BTDeviceInfo>.from(devices);
    sorted.sort((left, right) {
      final leftKnown =
          DeviceRegistry.resolveIdentity(name: left.name).id !=
          DeviceRegistry.unknown.id;
      final rightKnown =
          DeviceRegistry.resolveIdentity(name: right.name).id !=
          DeviceRegistry.unknown.id;
      if (leftKnown != rightKnown) return leftKnown ? -1 : 1;
      return left.name.toLowerCase().compareTo(right.name.toLowerCase());
    });
    return sorted;
  }

  DeviceProfile _resolveEndpointProfile(BluetoothEndpoint endpoint) {
    final profile = DeviceRegistry.resolveIdentity(name: endpoint.name);
    if (profile.kind == DeviceKind.zepp) return profile;

    final hasZeppService = endpoint.serviceUuids.any(_isZeppOsServiceUuid);
    if (!hasZeppService) return profile;

    return DeviceRegistry.profiles.firstWhere(
      (candidate) => candidate.id == 'zeppos',
      orElse: () => profile,
    );
  }

  bool _isZeppOsServiceUuid(String uuid) {
    final compact = uuid.toLowerCase().replaceAll('-', '');
    final target = _zeppOsBleServiceUuid.replaceAll('-', '');
    return compact == target || compact == '1530' || compact == '00001530';
  }

  String _scanDisplayName(BluetoothEndpoint endpoint, String rawDisplayName) {
    final profile = _resolveEndpointProfile(endpoint);
    if (profile.kind != DeviceKind.zepp ||
        DeviceRegistry.resolveIdentity(name: endpoint.name).kind ==
            DeviceKind.zepp) {
      return rawDisplayName;
    }
    final name = rawDisplayName.trim().isEmpty ? 'Device' : rawDisplayName;
    return 'ZeppOS $name';
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
    int generation,
  ) async {
    Exception? lastError;
    final isMacOsSpp =
        defaultTargetPlatform == TargetPlatform.macOS &&
        connectType == ConnectType.spp;
    final maxAttempts = isMacOsSpp
        ? _macOsSppConnectMaxAttempts
        : _defaultConnectMaxAttempts;
    final retryDelay = isMacOsSpp
        ? _macOsSppConnectRetryDelay
        : _defaultConnectRetryDelay;

    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      _throwIfConnectCancelled(generation);
      _log.info(
        '${connectType.name.toUpperCase()} connect attempt '
        '$attempt/$maxAttempts to $addr',
      );
      try {
        final connection = await _bluetooth.connect(
          addr,
          name,
          BluetoothConnectOptions(
            connectType: connectType,
            bleRequiredCharacteristics: profile.bleRequiredCharacteristics,
            bleDesiredMtu: profile.bleDesiredMtu,
            bleAttemptPair: profile.bleAttemptPair,
            sppServiceUuid: profile.classicServiceUuid,
            sppFallbackChannels: profile.classicFallbackChannels,
          ),
        );
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
        await Future.delayed(retryDelay);
        _throwIfConnectCancelled(generation);
      }
    }

    throw lastError ??
        Exception(
          '${connectType.name} connect failed after $maxAttempts attempts',
        );
  }

  void _throwIfConnectCancelled(int generation) {
    if (generation != _connectGeneration) {
      throw const _DeviceConnectCancelled();
    }
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
      await Future.delayed(_sppFailedConnectSettleDelay);
    }
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
    final existingDevice = state.pairedDevices
        .where((d) => d.addr == addr)
        .firstOrNull;
    final identity =
        xiaomiWearableIdentityForCodename(existingDevice?.codename) ??
        normalizeXiaomiWearableIdentity(name);
    var effectiveCodename = identity?.codename ?? existingDevice?.codename;
    final zeppCatalogDevice = zeppOsDeviceForBluetoothName(name);
    if (zeppCatalogDevice != null) {
      effectiveCodename = 'zepp:${zeppCatalogDevice.id}';
    }
    final displayName = xiaomiDisplayNameForIdentity(
      name: name,
      codename: effectiveCodename,
    );
    final profile =
        _scannedProfiles[addr] ??
        DeviceRegistry.resolveIdentity(
          name: displayName,
          codename: effectiveCodename,
        );
    final profileSource = identity != null
        ? 'codename:${identity.codename}'
        : 'name';
    var effectiveKind = kind == DeviceKind.xiaomi ? profile.kind : kind;
    final requestedConnectType = connectType.toLowerCase().isEmpty
        ? profile.preferredConnectType.name
        : connectType.toLowerCase();
    final effectiveConnectType = requestedConnectType;
    _log.info(
      'connect request $addr rawName="$name" displayName="$displayName" '
      'codename="$effectiveCodename" via=$effectiveConnectType '
      'profile=${profile.id} source=$profileSource '
      'authkeyPresent=${authKey.trim().isNotEmpty}',
    );
    _log.info('connecting to $displayName @ $addr via $effectiveConnectType');
    state = state.copyWith(
      connecting: true,
      connectionTargetAddr: addr,
      connectionTargetName: displayName,
      connectionPhase: DeviceConnectionPhase.preparing,
      connectStatus: 1,
      protocolState: ProtocolState.connecting,
      clearError: true,
    );
    try {
      await stopBluetoothScan();
      _throwIfConnectCancelled(generation);
      await _cleanupConnection();
      _throwIfConnectCancelled(generation);

      final transportType = effectiveConnectType == ConnectType.spp.name
          ? ConnectType.spp
          : ConnectType.ble;
      state = state.copyWith(
        connectionPhase: DeviceConnectionPhase.connectingTransport,
      );
      _bluetoothConnection = await _connectBluetoothWithRetry(
        addr,
        displayName,
        profile,
        transportType,
        generation,
      );
      _throwIfConnectCancelled(generation);
      state = state.copyWith(
        connectionPhase: DeviceConnectionPhase.initializingProtocol,
        protocolState: ProtocolState.connected,
      );

      if (transportType == ConnectType.ble &&
          _supportsZeppOsGatt(_bluetoothConnection!)) {
        effectiveKind = DeviceKind.zepp;
        _log.info(
          'identified $addr as ZeppOS from discovered GATT characteristics',
        );
      }

      final Transport transport;
      if (transportType == ConnectType.spp) {
        final sppTransport = effectiveKind == DeviceKind.zepp
            ? SppTransport.zeppBtbrBluetooth(_bluetoothConnection!)
            : SppTransport.xiaomiBluetooth(_bluetoothConnection!);
        await sppTransport.start();
        _throwIfConnectCancelled(generation);
        transport = sppTransport;
      } else {
        final bleTransport = effectiveKind == DeviceKind.zepp
            ? BleTransport.zeppBluetooth(_bluetoothConnection!)
            : BleTransport.xiaomiBluetooth(_bluetoothConnection!);
        await bleTransport.start();
        _throwIfConnectCancelled(generation);
        transport = bleTransport;
      }

      final entity = _runtime.spawnDevice(
        id: addr,
        kind: deviceKindString(effectiveKind),
        transport: transport,
        factory: effectiveKind == DeviceKind.zepp
            ? ZeppOsDeviceFactory()
            : XiaomiDeviceFactory(),
      );
      _currentEntity = entity;
      await _rawProtocolSubscription?.cancel();
      _rawProtocolSubscription = entity.rawIncomingData.listen(
        _rawProtocolFrames.add,
      );

      if (effectiveKind == DeviceKind.zepp) {
        if (transportType == ConnectType.spp) {
          throw UnsupportedError(
            'ZeppOS BTBR transport is discovered but channel/session auth is not implemented yet',
          );
        }
        state = state.copyWith(
          connectionPhase: DeviceConnectionPhase.authenticating,
          protocolState: ProtocolState.authenticating,
        );
        final authSystem = entity.system<ZeppOsAuthSystem>()!;
        _log.info('starting ZeppOS authentication');
        await authSystem.authenticate(authKey);
        _throwIfConnectCancelled(generation);
        _log.info('ZeppOS authentication succeeded');
      } else {
        final component = entity.get<XiaomiDeviceComponent>()!;
        await component
            .startSession(
              spp: effectiveConnectType.toLowerCase() == ConnectType.spp.name,
            )
            .timeout(const Duration(seconds: 10));
        _throwIfConnectCancelled(generation);

        state = state.copyWith(
          connectionPhase: DeviceConnectionPhase.authenticating,
          protocolState: ProtocolState.authenticating,
        );
        final authSystem = entity.system<XiaomiAuthSystem>()!;
        _log.info('starting authentication');
        await authSystem
            .authenticate(authKey)
            .timeout(const Duration(seconds: 10));
        _throwIfConnectCancelled(generation);
        _log.info('authentication succeeded');
      }

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
        updatedPaired.removeAt(existingIndex);
      }
      updatedPaired.insert(0, connected);

      state = state.copyWith(
        currentDevice: connected,
        pairedDevices: updatedPaired,
        connectionPhase: DeviceConnectionPhase.fetchingDeviceStatus,
        protocolState: ProtocolState.ready,
      );
      try {
        await refreshBattery();
      } catch (e, st) {
        _log.warning('initial battery refresh failed', e, st);
      }
      _throwIfConnectCancelled(generation);
      state = state.copyWith(
        connecting: false,
        connectStatus: 2,
        clearConnectionPhase: true,
      );
      await _savePairedDevices();
      _startBatteryRefreshLoop();
      unawaited(_loadInitialDeviceData(entity));
    } on _DeviceConnectCancelled {
      _log.info('connect to $addr cancelled');
    } catch (e, st) {
      if (generation != _connectGeneration) {
        _log.info('connect to $addr cancelled after error: $e');
        return;
      }
      _log.severe('connect to $addr failed', e, st);
      state = state.copyWith(
        connecting: false,
        connectStatus: 3,
        protocolState: ProtocolState.error,
        error: e.toString(),
        clearConnectionPhase: true,
      );
      await _cleanupConnection();
    }
  }

  bool _supportsZeppOsGatt(BluetoothConnection connection) {
    const service = '00001530-0000-3512-2118-0009af100700';
    return connection.supportsCharacteristic(
          BleRequiredCharacteristic(
            serviceUuid: service,
            characteristicUuid: '00000016-0000-3512-2118-0009af100700',
          ),
        ) &&
        connection.supportsCharacteristic(
          BleRequiredCharacteristic(
            serviceUuid: service,
            characteristicUuid: '00000017-0000-3512-2118-0009af100700',
          ),
        );
  }

  Future<void> _loadInitialDeviceData(DeviceEntity entity) async {
    if (_currentEntity != entity) return;
    for (final operation in <(String, Future<void> Function())>[
      ('device data', refreshDeviceData),
      ('app list', fetchApps),
      ('watchface list', fetchWatchfaces),
    ]) {
      if (_currentEntity != entity) return;
      try {
        await operation.$2();
      } catch (e, st) {
        _log.warning('initial ${operation.$1} refresh failed', e, st);
      }
    }
  }

  void _startBatteryRefreshLoop() {
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => unawaited(_refreshBatteryInBackground()),
    );
  }

  Future<void> _refreshBatteryInBackground() async {
    if (_batteryRefreshInProgress ||
        _currentEntity == null ||
        state.protocolState != ProtocolState.ready) {
      return;
    }
    _batteryRefreshInProgress = true;
    try {
      await refreshBattery();
    } catch (e, st) {
      if (_currentEntity != null &&
          state.protocolState == ProtocolState.ready) {
        _log.warning('periodic battery refresh failed', e, st);
      }
    } finally {
      _batteryRefreshInProgress = false;
    }
  }

  Future<SystemInfo> _fetchDeviceInfoWithEuiccFallback(
    XiaomiInfoSystem infoSystem,
  ) async {
    var info = await infoSystem.fetchDeviceInfo();
    final storageInfo = state.systemInfo?.storageInfo;
    if (storageInfo != null) {
      info = info.copyWith(storageInfo: storageInfo);
    }
    if (!_shouldFetchEuiccImei(state.currentDevice, info)) {
      return info;
    }

    try {
      final imei = await infoSystem.fetchEuiccImei();
      if (imei == null) {
        _log.info(
          'eUICC IMEI unavailable for ${state.currentDevice?.addr ?? info.model}',
        );
        return info;
      }
      final updatedInfo = info.copyWith(
        imei: imei,
        storageInfo: state.systemInfo?.storageInfo ?? info.storageInfo,
      );
      state = state.copyWith(systemInfo: updatedInfo);
      _log.info(
        'device info ${state.currentDevice?.addr ?? info.model}: '
        'eUICC IMEI loaded',
      );
      return updatedInfo;
    } catch (e, st) {
      _log.warning('eUICC info fetch failed', e, st);
      return info;
    }
  }

  bool _shouldFetchEuiccImei(MiWearState? device, SystemInfo info) {
    if (info.imei.trim().isNotEmpty) return false;

    final identity =
        xiaomiWearableIdentityForCodename(device?.codename) ??
        normalizeXiaomiWearableIdentity(info.model) ??
        normalizeXiaomiWearableIdentity(device?.name ?? '');
    final tokens = [
      device?.name,
      device?.codename,
      info.model,
      identity?.codename,
      identity?.displayName,
    ].whereType<String>().map((value) => value.toLowerCase()).join(' ');

    return tokens.contains('esim') ||
        tokens.contains('lte') ||
        tokens.contains('o65m');
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
        state = state.copyWith(battery: battery);
      case DeviceInfoUpdated(:final info):
        _log.info(
          'device info ${event.deviceId}: model=${info.model}, '
          'fw=${info.firmwareVersion}',
        );
        state = state.copyWith(
          systemInfo: info.copyWith(storageInfo: state.systemInfo?.storageInfo),
        );
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
        _log.info(
          'storage info ${event.deviceId}: used=${info.used}, total=${info.total}',
        );
        final currentInfo = state.systemInfo;
        state = state.copyWith(
          systemInfo:
              currentInfo?.copyWith(storageInfo: info) ??
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
      case ZeppOsEndpointMessageReceived(:final endpoint, :final payload):
        final messages = [
          ...state.zeppOsMessages,
          ZeppOsMessageRecord(
            timestamp: DateTime.now(),
            endpoint: endpoint,
            payload: List<int>.unmodifiable(payload),
          ),
        ];
        state = state.copyWith(
          zeppOsMessages: messages.length > 200
              ? messages.sublist(messages.length - 200)
              : messages,
        );
      case XiaoAiSessionStarted(:final capabilities):
        state = state.copyWith(
          xiaoAiActive: true,
          xiaoAiFrameCount: 0,
          xiaoAiCapabilities: Map<String, Object?>.unmodifiable(capabilities),
        );
      case XiaoAiSessionEnded _:
        state = state.copyWith(xiaoAiActive: false);
      case XiaoAiOpusFrameReceived(:final frame):
        state = state.copyWith(xiaoAiFrameCount: state.xiaoAiFrameCount + 1);
        emitXiaoAiOpusFrame(Uint8List.fromList(frame));
      case InterconnectMessage _:
        emitInterconnectMessage(event);
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
    if (state.connecting) {
      _log.fine('ignoring disconnect state transition during connect attempt');
      return;
    }
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

  @override
  Future<void> disconnect() async {
    _connectGeneration += 1;
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
        clearConnectionTarget: true,
        clearConnectionPhase: true,
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
      clearConnectionTarget: true,
      clearConnectionPhase: true,
    );
    await _savePairedDevices();
  }

  @override
  Future<void> cancelConnect() async {
    if (!state.connecting) return;
    await disconnect();
  }

  Future<void> _cleanupConnection() async {
    _batteryRefreshTimer?.cancel();
    _batteryRefreshTimer = null;
    final connection = _bluetoothConnection;
    final entity = _currentEntity;
    _bluetoothConnection = null;
    _currentEntity = null;
    await _rawProtocolSubscription?.cancel();
    _rawProtocolSubscription = null;

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

  @override
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

  @override
  Future<void> refreshBattery() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppBatterySystem = entity.system<ZeppOsBatterySystem>();
    if (zeppBatterySystem != null) {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) return;
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(ZeppOsBatterySystem.endpoint)) {
        _log.info('ZeppOS device does not advertise battery endpoint 0x0029');
        return;
      }
      zeppBatterySystem.encrypted =
          services[ZeppOsBatterySystem.endpoint] ?? true;
      final battery = await zeppBatterySystem.fetchBatteryInfo();
      state = state.copyWith(battery: battery);
      return;
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    final battery = await infoSystem.fetchBatteryInfo();
    state = state.copyWith(battery: battery);
  }

  @override
  Future<void> refreshDeviceData() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<ZeppOsBatterySystem>() != null) {
      await refreshBattery();
      return;
    }
    await refreshBattery();
    await fetchSystemInfo();
    await fetchStorageInfo();
  }

  @override
  Future<void> setFindingZeppOsDevice(bool finding) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsFindDeviceSystem>();
    if (system == null) {
      throw UnsupportedError('Find device is only available for ZeppOS');
    }
    await system.setFinding(finding);
  }

  @override
  Future<void> sendXiaoAiReply(String text) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) {
      throw UnsupportedError('XiaoAI is only available for ZeppOS');
    }
    await system.sendTextReply(text);
  }

  @override
  Future<void> setXiaoAiContinuousCapture(bool enabled) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) {
      throw UnsupportedError('XiaoAI is only available for ZeppOS');
    }
    system.setContinuousCapture(enabled);
  }

  @override
  Future<void> setXiaoAiEndpoint(int endpoint) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsXiaoAiSystem>();
    if (system == null) {
      throw UnsupportedError('Assistant is only available for ZeppOS');
    }
    system.selectEndpoint(endpoint);
  }

  @override
  void clearZeppOsMessages() {
    state = state.copyWith(zeppOsMessages: const []);
  }

  ZeppOsAppSideSystem _appSideSystem() {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsAppSideSystem>();
    if (system == null)
      throw UnsupportedError('Zepp OS app-side is unavailable');
    return system;
  }

  @override
  Future<List<int>> listZeppOsAppSides() => _appSideSystem().cachedAppIds();

  @override
  Future<List<int>> observedZeppOsAppSideIds() =>
      _appSideSystem().observedAppIds();

  @override
  Future<List<ZeppOsAppSideSessionInfo>> zeppOsAppSideSessions() async =>
      _appSideSystem().sessions;

  @override
  Future<List<ZeppOsAppSideDebugEvent>> zeppOsAppSideEvents(int appId) async =>
      _appSideSystem().eventsFor(appId);

  @override
  Future<void> clearZeppOsAppSideEvents(int appId) async =>
      _appSideSystem().clearEvents(appId);

  @override
  Future<void> startZeppOsAppSide(int appId) => _appSideSystem().start(appId);

  @override
  Future<void> stopZeppOsAppSide(int appId) => _appSideSystem().stop(appId);

  @override
  Future<void> injectZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _appSideSystem().injectMessage(appId, payload);

  @override
  Future<void> sendZeppOsAppSideMessage(int appId, Uint8List payload) =>
      _appSideSystem().sendMessageToWatch(appId, payload);

  @override
  Future<Uint8List> requestZeppOsScreenshot() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final system = entity.system<ZeppOsScreenshotSystem>();
    if (system == null) throw UnsupportedError('Screenshot service unavailable');
    return system.requestScreenshot();
  }

  @override
  Future<void> fetchSystemInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppInfoSystem = entity.system<ZeppOsDeviceInfoSystem>();
    if (zeppInfoSystem != null) {
      final servicesSystem = entity.system<ZeppOsServicesSystem>();
      if (servicesSystem == null) {
        throw StateError('Zepp OS services discovery is unavailable');
      }
      final services = await servicesSystem.fetchSupportedServices();
      if (!services.containsKey(ZeppOsDeviceInfoSystem.endpoint)) {
        throw UnsupportedError(
          'This Zepp OS device does not advertise Device Info',
        );
      }
      zeppInfoSystem.encrypted =
          services[ZeppOsDeviceInfoSystem.endpoint] ?? false;
      final info = await zeppInfoSystem.fetchDeviceInfo();
      state = state.copyWith(systemInfo: info);
      return;
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      throw UnsupportedError('Device information is unavailable');
    }
    final info = await _fetchDeviceInfoWithEuiccFallback(infoSystem);
    state = state.copyWith(systemInfo: info);
  }

  @override
  Future<void> fetchStorageInfo() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>();
    if (infoSystem == null) {
      return;
    }
    final info = await infoSystem.fetchStorageInfo();
    final currentInfo = state.systemInfo;
    state = state.copyWith(
      systemInfo:
          currentInfo?.copyWith(storageInfo: info) ??
          SystemInfo(
            serialNumber: '',
            firmwareVersion: '',
            imei: '',
            model: '',
            storageInfo: info,
          ),
    );
  }

  @override
  Future<void> fetchApps() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(entity, zeppAppsSystem);
      final apps = await zeppAppsSystem.fetchApps();
      _log.info('event: ZeppOS app list ${apps.length}');
      state = state.copyWith(apps: apps);
      return;
    }
    final resourceSystem = entity.system<XiaomiResourceSystem>();
    if (resourceSystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    final items = await resourceSystem.fetchInstalledQuickApps();
    final apps = items
        .map(
          (item) => AppInfo(
            packageName: item.packageName,
            fingerprint: item.fingerprint,
            versionCode: item.versionCode,
            canRemove: item.canRemove,
            appName: item.appName,
          ),
        )
        .toList();
    _log.info('event: quick app list ${apps.length}');
    state = state.copyWith(apps: apps);
  }

  @override
  Future<void> fetchWatchfaces() async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final infoSystem = entity.system<XiaomiInfoSystem>()!;
    final watchfaces = await infoSystem.fetchInstalledWatchfaces();
    state = state.copyWith(watchfaces: watchfaces);
  }

  @override
  Future<void> openApp(AppInfo app, {String page = ''}) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(
        entity,
        zeppAppsSystem,
        requireLaunch: true,
      );
      _log.info('opening ZeppOS app ${app.packageName}');
      await zeppAppsSystem.launchApp(app.packageName);
      return;
    }
    _log.info('opening app ${app.packageName} page="$page"');
    final thirdpartySystem = entity.system<XiaomiThirdpartyAppSystem>();
    if (thirdpartySystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    await thirdpartySystem.launchApp(_thirdpartyAppInfo(app), page);
  }

  @override
  Future<void> sendInterconnectMessage(
    String packageName,
    Uint8List payload,
  ) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    var app = state.apps.cast<AppInfo?>().firstWhere(
      (candidate) => candidate?.packageName == packageName,
      orElse: () => null,
    );
    if (app == null) {
      await fetchApps();
      app = state.apps.cast<AppInfo?>().firstWhere(
        (candidate) => candidate?.packageName == packageName,
        orElse: () => null,
      );
    }
    if (app == null) {
      throw StateError('Quick app is not installed: $packageName');
    }
    final system = entity.system<XiaomiThirdpartyAppSystem>();
    if (system == null) {
      throw UnsupportedError(
        'Interconnect messaging is only available for Xiaomi wearables',
      );
    }
    _log.info(
      'sending interconnect message to $packageName (${payload.length} bytes)',
    );
    await system.sendPhoneMessage(packageName, payload);
    _log.info('interconnect message queued for $packageName');
  }

  @override
  Future<void> sendRaw(Uint8List payload) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    await entity.transport.send(payload);
  }

  @override
  Future<void> uninstallApp(AppInfo app) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    final zeppAppsSystem = entity.system<ZeppOsAppsSystem>();
    if (zeppAppsSystem != null) {
      await _configureZeppOsAppsSystem(entity, zeppAppsSystem);
      _log.info('uninstalling ZeppOS app ${app.packageName}');
      await zeppAppsSystem.uninstallApp(app.packageName);
      state = state.copyWith(
        apps: state.apps
            .where((candidate) => candidate.packageName != app.packageName)
            .toList(),
      );
      return;
    }
    _log.info('uninstalling app ${app.packageName}');
    final thirdpartySystem = entity.system<XiaomiThirdpartyAppSystem>();
    if (thirdpartySystem == null) {
      throw StateError(
        'Zepp OS app management was added after this device session started. '
        'Reconnect the device once to load it.',
      );
    }
    await thirdpartySystem.uninstallApp(_thirdpartyAppInfo(app));
    state = state.copyWith(
      apps: state.apps.where((a) => a.packageName != app.packageName).toList(),
    );
  }

  ThirdpartyAppInfo _thirdpartyAppInfo(AppInfo app) {
    return ThirdpartyAppInfo(
      packageName: app.packageName,
      fingerprint: Uint8List.fromList(app.fingerprint),
    );
  }

  Future<void> _configureZeppOsAppsSystem(
    DeviceEntity entity,
    ZeppOsAppsSystem appsSystem, {
    bool requireLaunch = false,
  }) async {
    final servicesSystem = entity.system<ZeppOsServicesSystem>();
    if (servicesSystem == null) {
      throw StateError(
        'Zepp OS services discovery is unavailable in this device session. '
        'Reconnect the device once to reload its protocol systems.',
      );
    }
    final services = await servicesSystem.fetchSupportedServices();
    if (!services.containsKey(ZeppOsAppsSystem.endpoint)) {
      throw UnsupportedError(
        'This Zepp OS device does not support app management',
      );
    }
    // Gadgetbridge's ZeppOsAppsService explicitly returns false from
    // isEncrypted(). Endpoint 0x00a0 must stay clear-text even if a device's
    // advertised services flags are ambiguous.
    appsSystem.encrypted = false;
    if (requireLaunch &&
        !services.containsKey(ZeppOsAppsSystem.launchEndpoint)) {
      throw UnsupportedError(
        'This Zepp OS device does not support launching apps',
      );
    }
    if (services.containsKey(ZeppOsAppsSystem.launchEndpoint)) {
      appsSystem.launchEncrypted =
          services[ZeppOsAppsSystem.launchEndpoint] ?? true;
    }
  }

  @override
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

  @override
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

  @override
  Future<void> installApp(
    Uint8List packageBytes, {
    required String packageName,
    void Function(double progress)? onProgress,
    void Function()? onAppSideMissing,
  }) async {
    final entity = _currentEntity;
    if (entity == null || state.protocolState != ProtocolState.ready) {
      throw ProtocolException('Device not ready');
    }
    if (entity.system<ZeppOsAppsSystem>() != null) {
      final installer = entity.system<ZeppOsAppInstallSystem>();
      if (installer == null) {
        throw StateError('Zepp OS installer was not loaded for this session');
      }
      final info = entity.system<ZeppOsDeviceInfoSystem>();
      final source = info?.deviceSource;
      final package = const ZeppOsPackageParser().parse(
        packageBytes,
        deviceSources: source == null ? const {} : {source},
      );
      if (package.type != ZeppOsPackageType.app) {
        throw FormatException(
          'Selected package is ${package.type.name}, not a Zepp OS app',
        );
      }
      _log.info(
        'installing Zepp OS app ${package.name ?? packageName} '
        '(${package.bytes.length} bytes)',
      );
      await installer.install(package, onProgress: onProgress);
      final appId = package.appId;
      if (appId != null) {
        final storage = ZeppOsAppSideStorage();
        final appSideJs = package.appSideJs;
        if (appSideJs != null) {
          await storage.save(appId, appSideJs);
          _log.info(
            'cached Zepp OS app-side.js for '
            '0x${appId.toRadixString(16).padLeft(8, '0')}',
          );
        }
        if (appSideJs == null) onAppSideMissing?.call();
        final settingJs = package.settingJs;
        if (settingJs != null) {
          await storage.saveSetting(
            appId,
            settingJs,
            assets: package.settingAssets,
            appName: package.name,
          );
          _log.info(
            'cached Zepp OS setting.js for '
            '0x${appId.toRadixString(16).padLeft(8, '0')}',
          );
        }
        if (appSideJs == null && settingJs == null) {
          _log.info(
            'installed Zepp OS app 0x${appId.toRadixString(16).padLeft(8, '0')} '
            'without app-side or settings',
          );
        }
      }
      // D5/D6 are the completion acknowledgement. Do not hold the completed
      // queue item open while the watch indexes the newly installed app.
      return;
    }
    _log.info('installing app $packageName (${packageBytes.length} bytes)');
    final installSystem = entity.system<XiaomiInstallSystem>()!;
    await installSystem.installApp(
      packageBytes,
      packageName: packageName,
      onProgress: onProgress,
    );
  }

  @override
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
    await installSystem.installWatchface(
      watchfaceBytes,
      watchfaceId: watchfaceId,
      onProgress: onProgress,
    );
  }

  @override
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
    await installSystem.installFirmware(firmwareBytes, onProgress: onProgress);
  }

  @override
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

  @override
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
    NotifierProvider<DeviceManager, DeviceManagerState>(LocalDeviceManager.new);
