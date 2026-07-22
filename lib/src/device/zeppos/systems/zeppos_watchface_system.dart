import 'dart:async';
import 'dart:typed_data';

import 'package:zerobox/src/core/models/bt_models.dart';
import 'package:zerobox/src/device/core/event_bus.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';

/// Zepp OS watchface discovery and activation, using endpoint 0x0023.
class ZeppOsWatchfaceSystem extends System {
  static const endpoint = 0x0023;
  static const _listGet = 0x05;
  static const _listRet = 0x06;
  static const _set = 0x07;
  static const _currentGet = 0x09;
  static const _currentRet = 0x0a;
  static const _changed = 0xff;

  bool encrypted = true;
  List<int> _ids = const [];
  int? _currentId;
  String? _lastEmittedSnapshot;
  Completer<List<int>>? _pendingList;

  Future<List<WatchfaceInfo>> fetchWatchfaces() async {
    final pending = _pendingList;
    if (pending != null) {
      await pending.future.timeout(const Duration(seconds: 8));
      return _snapshot();
    }
    final list = Completer<List<int>>();
    _pendingList = list;
    try {
      await _send(Uint8List.fromList(const [_listGet]));
      // Some Zepp OS devices, including Xiaomi Smart Band 7, return the
      // watchface list but never answer the current-watchface request.
      // Current state is optional and may arrive asynchronously.
      await _send(Uint8List.fromList(const [_currentGet]));
      await list.future.timeout(const Duration(seconds: 8));
      return _snapshot();
    } finally {
      if (identical(_pendingList, list)) _pendingList = null;
    }
  }

  Future<void> setWatchface(String value) async {
    final id = _parseId(value);
    final payload = Uint8List(5)..[0] = _set;
    _writeUint32Le(payload, 1, id);
    await _send(payload);
    _currentId = id;
    _emitSnapshot();
  }

  void handlePayload(Uint8List payload) {
    if (payload.isEmpty) return;
    switch (payload[0]) {
      case _listRet:
        if (payload.length < 3 || payload[1] != 1) return;
        final count = payload[2];
        if (payload.length < 3 + count * 4) return;
        _ids = List<int>.generate(
          count,
          (index) => _readUint32Le(payload, 3 + index * 4),
          growable: false,
        );
        final pending = _pendingList;
        if (pending != null && !pending.isCompleted) pending.complete(_ids);
        _emitSnapshot();
      case _currentRet:
        if (payload.length < 5) return;
        _currentId = _readUint32Le(payload, 1);
        _emitSnapshot();
      case _changed:
        unawaited(_requestCurrent());
    }
  }

  List<WatchfaceInfo> _snapshot() => _ids
      .map(
        (id) => WatchfaceInfo(
          id: _formatId(id),
          name: 'Zepp OS Watchface ${_formatId(id)}',
          isCurrent: id == _currentId,
          canRemove: true,
        ),
      )
      .toList(growable: false);

  void _emitSnapshot() {
    final signature = '${_currentId ?? -1}:${_ids.join(',')}';
    if (_lastEmittedSnapshot == signature) return;
    _lastEmittedSnapshot = signature;
    entity.emit(
      WatchfaceListUpdated(deviceId: entity.id, watchfaces: _snapshot()),
    );
  }

  Future<void> _requestCurrent() =>
      _send(Uint8List.fromList(const [_currentGet]));

  Future<void> _send(Uint8List payload) =>
      _component.sendToEndpoint(endpoint, payload, encrypted: encrypted);

  ZeppOsDeviceComponent get _component =>
      entity.getRequired<ZeppOsDeviceComponent>();

  static int _parseId(String value) {
    final normalized = value.trim().toLowerCase();
    final digits = normalized.startsWith('0x')
        ? normalized.substring(2)
        : normalized;
    final id = int.tryParse(digits, radix: 16);
    if (id == null || id < 0 || id > 0xffffffff) {
      throw FormatException('Invalid Zepp OS watchface ID: $value');
    }
    return id;
  }

  static String _formatId(int id) =>
      '0x${id.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  static int _readUint32Le(Uint8List bytes, int offset) =>
      bytes[offset] |
      (bytes[offset + 1] << 8) |
      (bytes[offset + 2] << 16) |
      (bytes[offset + 3] << 24);

  static void _writeUint32Le(Uint8List bytes, int offset, int value) {
    bytes[offset] = value & 0xff;
    bytes[offset + 1] = (value >> 8) & 0xff;
    bytes[offset + 2] = (value >> 16) & 0xff;
    bytes[offset + 3] = (value >> 24) & 0xff;
  }

  @override
  void onData(Uint8List data) {}
}
