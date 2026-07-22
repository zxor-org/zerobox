import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

/// Zepp OS application management, ported from Gadgetbridge's
/// `ZeppOsAppsService`.
class ZeppOsAppsSystem extends System {
  static const endpoint = 0x00a0;
  static const launchEndpoint = 0x0023;

  static const _appsCommand = 0x02;
  static const _incoming = 0x00;
  static const _outgoing = 0x01;
  static const _list = 0x01;
  static const _delete = 0x03;
  static const _setApp = 0x07;

  Completer<List<AppInfo>>? _pendingList;
  List<AppInfo> _apps = const [];

  bool encrypted = false;
  bool launchEncrypted = true;

  List<AppInfo> get apps => List.unmodifiable(_apps);

  Future<List<AppInfo>> fetchApps() async {
    final pending = _pendingList;
    if (pending != null) {
      return pending.future.timeout(const Duration(seconds: 8));
    }

    final completer = Completer<List<AppInfo>>();
    _pendingList = completer;
    try {
      final request = Uint8List(16)
        ..[0] = _appsCommand
        ..[1] = _outgoing
        ..[2] = _list;
      await _component.sendToEndpoint(endpoint, request, encrypted: encrypted);
      return await completer.future.timeout(const Duration(seconds: 8));
    } finally {
      if (identical(_pendingList, completer)) _pendingList = null;
    }
  }

  Future<void> launchApp(String appId) {
    final id = _parseAppId(appId);
    final payload = Uint8List(5)..[0] = _setApp;
    _writeUint32Le(payload, 1, id);
    return _component.sendToEndpoint(
      launchEndpoint,
      payload,
      encrypted: launchEncrypted,
    );
  }

  Future<void> uninstallApp(String appId) async {
    final id = _parseAppId(appId);
    final payload = Uint8List(20)
      ..[0] = _appsCommand
      ..[1] = _outgoing
      ..[2] = _delete;
    _writeUint32Le(payload, 16, id);
    await _component.sendToEndpoint(endpoint, payload, encrypted: encrypted);
  }

  void handlePayload(Uint8List payload) {
    if (payload.length < 3 ||
        payload[0] != _appsCommand ||
        payload[1] != _incoming ||
        payload[2] != _list) {
      return;
    }

    final apps = _parseAppList(payload);
    _apps = List.unmodifiable(apps);
    final pending = _pendingList;
    if (pending != null && !pending.isCompleted) pending.complete(_apps);
  }

  List<AppInfo> _parseAppList(Uint8List payload) {
    if (payload.length <= 16) return const [];
    var end = 16;
    while (end < payload.length && payload[end] != 0) {
      end += 1;
    }
    final encoded = String.fromCharCodes(payload.sublist(16, end));
    final apps = <AppInfo>[];
    for (final entry in encoded.split(';')) {
      if (entry.isEmpty) continue;
      final separator = entry.indexOf('-');
      if (separator <= 0 || separator == entry.length - 1) continue;
      final id = int.tryParse(entry.substring(0, separator), radix: 16);
      if (id == null) continue;
      final appId = _formatAppId(id);
      final version = entry.substring(separator + 1);
      apps.add(
        AppInfo(
          packageName: appId,
          versionCode: _versionCode(version),
          canRemove: true,
          appName: 'Zepp OS App $appId ($version)',
        ),
      );
    }
    return apps;
  }

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  static int _parseAppId(String value) {
    final normalized = value.trim().toLowerCase();
    final digits = normalized.startsWith('0x')
        ? normalized.substring(2)
        : normalized;
    final id = int.tryParse(digits, radix: 16);
    if (id == null || id < 0 || id > 0xffffffff) {
      throw FormatException('Invalid Zepp OS app ID: $value');
    }
    return id;
  }

  static String _formatAppId(int id) =>
      '0x${id.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static int _versionCode(String version) {
    final parts = RegExp(r'\d+')
        .allMatches(version)
        .take(3)
        .map((match) => int.tryParse(match.group(0)!) ?? 0);
    final values = [...parts, 0, 0, 0];
    return values[0] * 1000000 + values[1] * 1000 + values[2];
  }

  static void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  @override
  void onData(Uint8List data) {}
}
