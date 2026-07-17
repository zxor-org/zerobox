import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/core/system.dart';
import 'package:zerobox/src/device/zeppos/app_side/zeppos_app_side_storage.dart';
import 'package:zerobox/src/device/zeppos/zeppos_device_component.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime.dart';
import 'package:zerobox/src/features/plugins/runtime/plugin_runtime_factory.dart';

class ZeppOsAppSideSessionInfo {
  const ZeppOsAppSideSessionInfo({
    required this.appId,
    required this.version,
    required this.port1,
    required this.port2,
    required this.extra,
    required this.watchSessionOpen,
  });

  final int appId;
  final int version;
  final int port1;
  final int port2;
  final int extra;
  final bool watchSessionOpen;
}

class ZeppOsAppSideDebugEvent {
  const ZeppOsAppSideDebugEvent({
    required this.timestamp,
    required this.type,
    required this.message,
    this.direction,
    this.source,
    this.payload,
  });

  final DateTime timestamp;
  final String type;
  final String message;
  final String? direction;
  final String? source;
  final Uint8List? payload;
}

class ZeppOsAppSideSystem extends System {
  ZeppOsAppSideSystem({ZeppOsAppSideStorage? storage})
    : _storage = storage ?? ZeppOsAppSideStorage();

  static const endpoint = 0x00a0;
  static const _cmdJs = 0x01;
  static const _typeOpen = 0x01;
  static const _typeClose = 0x02;
  static const _typeMessage = 0x04;
  static const _maxDebugEvents = 500;

  final ZeppOsAppSideStorage _storage;
  final Dio _dio = Dio();
  final _sessions = <int, _AppSideSession>{};
  final _watchHeaders = <int, _WatchSessionHeader>{};
  final _debugEvents = <int, List<ZeppOsAppSideDebugEvent>>{};
  final _log = getLogger('ZeppOsAppSideSystem');

  List<ZeppOsAppSideSessionInfo> get sessions => _sessions.values
      .map(
        (session) => ZeppOsAppSideSessionInfo(
          appId: session.appId,
          version: session.version,
          port1: session.port1,
          port2: session.port2,
          extra: session.extra,
          watchSessionOpen: session.watchSessionOpen,
        ),
      )
      .toList(growable: false);

  List<ZeppOsAppSideDebugEvent> eventsFor(int appId) =>
      List.unmodifiable(_debugEvents[appId] ?? const []);

  void clearEvents(int appId) => _debugEvents.remove(appId);

  Future<List<int>> cachedAppIds() => _storage.listAppIds();

  Future<List<int>> observedAppIds() async {
    final ids = <int>{
      ...await _storage.listAppIds(),
      ..._sessions.keys,
      ..._watchHeaders.keys,
      ..._debugEvents.keys,
    }.toList()..sort();
    return ids;
  }

  Future<void> handlePayload(Uint8List payload) async {
    if (payload.length < 16 || payload[0] != _cmdJs) return;
    final data = ByteData.sublistView(payload);
    final version = payload[1];
    final type = data.getUint16(2, Endian.little);
    final port1 = data.getUint16(4, Endian.little);
    final port2 = data.getUint16(6, Endian.little);
    final appId = data.getUint32(8, Endian.little);
    final extra = data.getUint32(12, Endian.little);
    final message = Uint8List.sublistView(payload, 16);
    switch (type) {
      case _typeOpen:
        final header = _WatchSessionHeader(
          version: version,
          port1: port1,
          port2: port2,
          extra: extra,
        );
        _watchHeaders[appId] = header;
        _addEvent(
          appId,
          type: 'open',
          source: 'watch',
          message:
              '收到手表启动请求（version $version，port1 $port1，'
              'port2 $port2，extra $extra）',
        );
        try {
          await start(
            appId,
            version: version,
            port1: port1,
            port2: port2,
            extra: extra,
            watchSessionOpen: true,
          );
        } catch (error) {
          _addEvent(
            appId,
            type: 'error',
            source: 'watch',
            message: '自动启动失败：$error',
          );
        }
        try {
          await _sendHeader(
            appId: appId,
            version: version,
            type: _typeOpen,
            port1: port1,
            port2: port2,
            extra: extra,
            body: Uint8List.fromList(const [0]),
          );
          _addEvent(
            appId,
            type: 'open_ack',
            direction: 'out',
            source: 'watch',
            message: 'open ACK 已发送',
            payload: Uint8List.fromList(const [0]),
          );
        } catch (error) {
          _addEvent(
            appId,
            type: 'error',
            direction: 'out',
            source: 'watch',
            message: 'open ACK 发送失败：$error',
          );
        }
      case _typeClose:
        _addEvent(appId, type: 'close', source: 'watch', message: '收到手表关闭会话');
        _watchHeaders.remove(appId);
        await stop(appId);
      case _typeMessage:
        if (_sessions[appId] == null) {
          final header = _watchHeaders[appId];
          if (header == null) {
            _addEvent(
              appId,
              type: 'error',
              direction: 'in',
              source: 'watch',
              message: '收到手表消息，但没有真实 open 会话，未启动 runtime',
              payload: message,
            );
            return;
          }
          try {
            _addEvent(
              appId,
              type: 'start',
              source: 'watch',
              message: '收到手表消息时 runtime 未运行，尝试按最近 open 信息恢复',
            );
            await start(
              appId,
              version: header.version,
              port1: header.port1,
              port2: header.port2,
              extra: header.extra,
              watchSessionOpen: true,
            );
          } catch (error) {
            _addEvent(
              appId,
              type: 'error',
              source: 'watch',
              message: '消息触发自动启动失败：$error',
              payload: message,
            );
            return;
          }
        }
        await injectMessage(appId, message, source: 'watch');
      default:
        _log.warning('Unknown app-side JS message type $type for $appId');
    }
  }

  Future<void> start(
    int appId, {
    int version = 1,
    int port1 = 20,
    int port2 = 1004,
    int extra = 0,
    bool watchSessionOpen = false,
  }) async {
    if (_sessions.containsKey(appId)) {
      _addEvent(
        appId,
        type: 'stop',
        message: watchSessionOpen
            ? '真实 open 到达，停止现有本地 runtime 并按真实 header 重建'
            : '重新启动前停止现有本地 runtime',
      );
      await stop(appId);
    }
    String? source;
    try {
      source = await _storage.read(appId);
    } catch (error) {
      _addEvent(appId, type: 'error', message: '脚本加载失败：$error');
      rethrow;
    }
    if (source == null) {
      final error = StateError(
        '没有缓存 app-side.js：0x${appId.toRadixString(16).padLeft(8, '0')}',
      );
      _addEvent(appId, type: 'error', message: '脚本加载失败：$error');
      throw error;
    }
    Map<String, String> settings;
    try {
      settings = await _storage.readSettings(appId);
    } catch (error) {
      settings = {};
      _addEvent(appId, type: 'error', message: 'settingsStorage 加载失败：$error');
    }
    _addEvent(appId, type: 'start', message: '脚本加载成功（${source.length} 字符）');
    final runtime = createJavaScriptPluginRuntime();
    final session = _AppSideSession(
      appId: appId,
      version: version,
      port1: port1,
      port2: port2,
      extra: extra,
      watchSessionOpen: watchSessionOpen,
      runtime: runtime,
      settings: settings,
    );
    session.settingsSubscription = ZeppOsSettingsCoordinator.instance
        .changesFor(appId)
        .where((change) => !identical(change.origin, session))
        .listen((change) {
          final values = Map<String, String>.from(change.values);
          session.settingsDispatch = session.settingsDispatch
              .catchError((_) {})
              .then((_) async {
                session.settings
                  ..clear()
                  ..addAll(values);
                await runtime.dispatchEvent(
                  'appside.settings.external',
                  jsonEncode(values),
                );
              })
              .catchError((error, stackTrace) {
                _addEvent(
                  appId,
                  type: 'error',
                  source: 'settingsStorage',
                  message: 'settingsStorage 事件派发失败：$error',
                );
                _log.warning(
                  'Failed to dispatch app-side settings for '
                  '0x${appId.toRadixString(16)}',
                  error,
                  stackTrace,
                );
              });
        });
    _sessions[appId] = session;
    try {
      await runtime.start(
        pluginId: 'zepp-app-side-${appId.toRadixString(16)}',
        pluginName: 'Zepp OS app-side',
        pluginVersion: '1',
        runtimeVersion: '1',
        entryBytes: Uint8List.fromList(
          utf8.encode('${_appSideBootstrap(jsonEncode(settings))}\n$source'),
        ),
        bootstrap: '',
        hostCall: (method, arguments) => _hostCall(session, method, arguments),
      );
      session.runtimeStarted = true;
      await runtime.dispatchEvent('appside.lifecycle.start', '');
      _addEvent(
        appId,
        type: 'start',
        message: watchSessionOpen ? 'QuickJS 自动启动成功' : 'QuickJS 手动启动成功',
      );
      _log.info('Started app-side runtime for 0x${appId.toRadixString(16)}');
    } catch (error) {
      _sessions.remove(appId);
      _addEvent(appId, type: 'error', message: 'QuickJS 启动失败：$error');
      await _closeSession(session);
      rethrow;
    }
  }

  Future<void> stop(int appId) async {
    final session = _sessions.remove(appId);
    if (session == null) return;
    await _closeSession(session);
    _addEvent(appId, type: 'stop', message: '本地 QuickJS 已停止');
  }

  Future<void> _closeSession(_AppSideSession session) async {
    try {
      await session.destroy();
      await session.settingsWrite;
      await _storage.writeSettings(session.appId, session.settings);
    } catch (error, stackTrace) {
      _addEvent(session.appId, type: 'error', message: error.toString());
      _log.warning(
        'Failed to destroy app-side 0x${session.appId.toRadixString(16)}',
        error,
        stackTrace,
      );
    } finally {
      await session.runtime.close();
    }
  }

  Future<void> injectMessage(
    int appId,
    Uint8List message, {
    String source = 'simulated',
  }) async {
    final session = _sessions[appId];
    if (session == null) throw StateError('App-side $appId is not running');
    final fromWatch = source == 'watch';
    _addEvent(
      appId,
      type: 'message',
      direction: 'in',
      source: source,
      message: fromWatch ? '手表 → app-side' : '模拟入站 → app-side',
      payload: message,
    );
    try {
      await session.runtime.dispatchEvent('appside.peer', _hex(message));
    } catch (error) {
      _addEvent(appId, type: 'error', message: error.toString());
      rethrow;
    }
  }

  Future<void> sendMessageToWatch(int appId, Uint8List message) async {
    final session = _sessions[appId];
    if (session == null) throw StateError('App-side $appId is not running');
    if (!session.watchSessionOpen) {
      throw StateError('手表尚未为该 appId 打开真实 app-side 会话');
    }
    _addEvent(
      appId,
      type: 'message',
      direction: 'out',
      source: 'watch',
      message: 'app-side → 手表',
      payload: message,
    );
    try {
      await _sendHeader(
        appId: appId,
        version: session.version,
        type: _typeMessage,
        port1: session.port1,
        port2: session.port2,
        extra: session.extra,
        body: message,
      );
    } catch (error) {
      _addEvent(appId, type: 'error', message: error.toString());
      rethrow;
    }
  }

  Object? _hostCall(
    _AppSideSession session,
    String method,
    List<Object?> arguments,
  ) {
    if (method.startsWith('console.') || method.startsWith('log.')) {
      final level = method.substring(method.indexOf('.') + 1);
      final message = arguments.join(' ');
      _addEvent(session.appId, type: 'console', message: '$level: $message');
      _log.info('[0x${session.appId.toRadixString(16)}] $level: $message');
      return null;
    }
    if (method == 'permission.require') return null;
    if (method == 'appside.peer.send') {
      final value = arguments.firstOrNull?.toString() ?? '';
      return sendMessageToWatch(session.appId, _decodeHex(value));
    }
    if (method == 'appside.fetch') return _fetch(session, arguments);
    if (method == 'appside.settings.write') {
      return _persistSettings(
        session,
        arguments.firstOrNull?.toString() ?? '{}',
      );
    }
    throw UnsupportedError('Unsupported app-side host method: $method');
  }

  Future<Map<String, Object?>> _fetch(
    _AppSideSession session,
    List<Object?> arguments,
  ) async {
    final request = jsonDecode(arguments.firstOrNull?.toString() ?? '{}');
    if (request is! Map) throw const FormatException('Invalid fetch request');
    final values = request.cast<String, Object?>();
    final url = Uri.parse(values['url']?.toString() ?? '');
    if (url.scheme != 'http' && url.scheme != 'https') {
      throw UnsupportedError('fetch only supports http(s) URLs');
    }
    final rawHeaders = values['headers'];
    final headers = rawHeaders is Map
        ? rawHeaders.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          )
        : <String, String>{};
    try {
      final response = await _dio.request<List<int>>(
        url.toString(),
        data: values['body'],
        options: Options(
          method: values['method']?.toString().toUpperCase() ?? 'GET',
          headers: headers,
          responseType: ResponseType.bytes,
          validateStatus: (_) => true,
        ),
      );
      final bytes = response.data ?? const <int>[];
      final contentType =
          response.headers.value(Headers.contentTypeHeader) ?? '';
      final charset = RegExp(
        r'charset\s*=\s*["\x27]?([^;"\x27\s]+)',
        caseSensitive: false,
      ).firstMatch(contentType)?.group(1)?.toLowerCase();
      final textual =
          contentType.isEmpty ||
          contentType.toLowerCase().startsWith('text/') ||
          contentType.toLowerCase().contains('json') ||
          contentType.toLowerCase().contains('xml') ||
          contentType.toLowerCase().contains('javascript');
      final body = charset == 'latin1' || charset == 'iso-8859-1' || !textual
          ? latin1.decode(bytes)
          : utf8.decode(bytes, allowMalformed: true);
      final responseUrl = response.realUri.toString();
      return {
        'url': responseUrl,
        'status': response.statusCode ?? 0,
        'statusText': response.statusMessage ?? '',
        'headers': response.headers.map.map(
          (key, values) => MapEntry(key, values.join(', ')),
        ),
        'body': body,
        'bodyBase64': base64Encode(bytes),
        'redirected': responseUrl != url.toString(),
        'type': 'basic',
      };
    } catch (error, stackTrace) {
      _addEvent(
        session.appId,
        type: 'error',
        source: 'fetch',
        message: 'fetch $url 失败：$error',
      );
      _log.warning('App-side fetch failed for $url', error, stackTrace);
      rethrow;
    }
  }

  Future<void> _persistSettings(_AppSideSession session, String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map) {
      throw const FormatException('Invalid settings payload');
    }
    final operation = decoded['operation']?.toString();
    final key = decoded['key']?.toString();
    return session.settingsWrite = session.settingsWrite.then((_) async {
      try {
        final coordinator = ZeppOsSettingsCoordinator.instance;
        if (operation == 'set' && key != null) {
          await coordinator.set(
            session.appId,
            key,
            decoded['value']?.toString() ?? '',
            origin: session,
          );
        } else if (operation == 'remove' && key != null) {
          await coordinator.remove(session.appId, key, origin: session);
        } else if (operation == 'clear') {
          await coordinator.clear(session.appId, origin: session);
        } else {
          final values = decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          );
          await coordinator.replace(session.appId, values, origin: session);
        }
        final latest = await coordinator.read(session.appId);
        session.settings
          ..clear()
          ..addAll(latest);
      } catch (error, stackTrace) {
        _addEvent(
          session.appId,
          type: 'error',
          source: 'settingsStorage',
          message: 'settingsStorage 持久化失败：$error',
        );
        _log.warning(
          'Failed to persist app-side settings for 0x${session.appId.toRadixString(16)}',
          error,
          stackTrace,
        );
      }
    });
  }

  void _addEvent(
    int appId, {
    required String type,
    required String message,
    String? direction,
    String? source,
    Uint8List? payload,
  }) {
    final events = _debugEvents.putIfAbsent(appId, () => []);
    events.add(
      ZeppOsAppSideDebugEvent(
        timestamp: DateTime.now(),
        type: type,
        message: message,
        direction: direction,
        source: source,
        payload: payload == null ? null : Uint8List.fromList(payload),
      ),
    );
    if (events.length > _maxDebugEvents) {
      events.removeRange(0, events.length - _maxDebugEvents);
    }
  }

  Future<void> _sendHeader({
    required int appId,
    required int version,
    required int type,
    required int port1,
    required int port2,
    required int extra,
    required Uint8List body,
  }) {
    final payload = Uint8List(16 + body.length);
    final data = ByteData.sublistView(payload);
    payload[0] = _cmdJs;
    payload[1] = version;
    data.setUint16(2, type, Endian.little);
    data.setUint16(4, port1, Endian.little);
    data.setUint16(6, port2, Endian.little);
    data.setUint32(8, appId, Endian.little);
    data.setUint32(12, extra, Endian.little);
    payload.setRange(16, payload.length, body);
    return entity.getRequired<ZeppOsDeviceComponent>().sendToEndpoint(
      endpoint,
      payload,
    );
  }

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _decodeHex(String value) {
    if (value.length.isOdd || !RegExp(r'^[0-9a-fA-F]*$').hasMatch(value)) {
      throw const FormatException('Invalid hex');
    }
    return Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
  }

  @override
  void onData(Uint8List data) {}

  @override
  Future<void> dispose() async {
    final sessions = _sessions.values.toList();
    _sessions.clear();
    for (final session in sessions) {
      await _closeSession(session);
      _addEvent(session.appId, type: 'stop', message: '本地 QuickJS 已停止');
    }
  }
}

class _WatchSessionHeader {
  const _WatchSessionHeader({
    required this.version,
    required this.port1,
    required this.port2,
    required this.extra,
  });

  final int version;
  final int port1;
  final int port2;
  final int extra;
}

class _AppSideSession {
  _AppSideSession({
    required this.appId,
    required this.version,
    required this.port1,
    required this.port2,
    required this.extra,
    required this.watchSessionOpen,
    required this.runtime,
    required this.settings,
  });

  final int appId;
  final int version;
  final int port1;
  final int port2;
  final int extra;
  final bool watchSessionOpen;
  final PluginRuntime runtime;
  final Map<String, String> settings;
  Future<void> settingsWrite = Future.value();
  Future<void> settingsDispatch = Future.value();
  StreamSubscription<ZeppOsSettingsChange>? settingsSubscription;
  bool runtimeStarted = false;
  bool _destroyed = false;

  Future<void> destroy() async {
    if (_destroyed) return;
    _destroyed = true;
    await settingsSubscription?.cancel();
    await settingsDispatch.catchError((_) {});
    if (runtimeStarted) {
      await runtime.dispatchEvent('appside.lifecycle.destroy', '');
    }
  }
}

String _appSideBootstrap(String initialSettings) =>
    'const __zbInitialSettings = $initialSettings;\n'
    r'''
(() => {
  const listeners = [];
  const runtimeEvents = new Map();
  const eventApi = {
    addEventListener(name, callback) {
      if (typeof callback !== 'function') throw new TypeError('event listener must be a function');
      const callbacks = runtimeEvents.get(name) || [];
      if (!callbacks.includes(callback)) callbacks.push(callback);
      runtimeEvents.set(name, callbacks);
    },
    removeEventListener(name, callback) {
      const callbacks = runtimeEvents.get(name);
      if (!callbacks) return;
      if (typeof callback !== 'function') {
        runtimeEvents.delete(name);
        return;
      }
      const index = callbacks.indexOf(callback);
      if (index !== -1) callbacks.splice(index, 1);
      if (!callbacks.length) runtimeEvents.delete(name);
    }
  };
  globalThis.AstroBox = Object.freeze({event: Object.freeze(eventApi)});
  globalThis.__zbDispatchEvent = async (name, payload) => {
    for (const callback of [...(runtimeEvents.get(name) || [])]) {
      await callback(payload);
    }
  };
  globalThis.__zbStartPlugin = async () => {};
  const initialSettings = __zbInitialSettings;
  if (typeof globalThis.ValueError !== 'function') {
    globalThis.ValueError = class ValueError extends Error {
      constructor(message = '') {
        super(message);
        this.name = 'ValueError';
      }
    };
  }
  const utf8Encode = value => {
    const bytes = [];
    for (const char of String(value)) {
      const code = char.codePointAt(0);
      if (code <= 0x7f) bytes.push(code);
      else if (code <= 0x7ff) bytes.push(0xc0 | code >> 6, 0x80 | code & 0x3f);
      else if (code <= 0xffff) bytes.push(0xe0 | code >> 12, 0x80 | code >> 6 & 0x3f, 0x80 | code & 0x3f);
      else bytes.push(0xf0 | code >> 18, 0x80 | code >> 12 & 0x3f, 0x80 | code >> 6 & 0x3f, 0x80 | code & 0x3f);
    }
    return bytes;
  };
  const utf8Decode = bytes => {
    let result = '';
    for (let i = 0; i < bytes.length;) {
      const first = bytes[i++];
      let code;
      if (first < 0x80) code = first;
      else if ((first & 0xe0) === 0xc0 && i < bytes.length) code = (first & 0x1f) << 6 | bytes[i++] & 0x3f;
      else if ((first & 0xf0) === 0xe0 && i + 1 < bytes.length) code = (first & 0x0f) << 12 | (bytes[i++] & 0x3f) << 6 | bytes[i++] & 0x3f;
      else if ((first & 0xf8) === 0xf0 && i + 2 < bytes.length) code = (first & 7) << 18 | (bytes[i++] & 0x3f) << 12 | (bytes[i++] & 0x3f) << 6 | bytes[i++] & 0x3f;
      else code = 0xfffd;
      result += String.fromCodePoint(code);
    }
    return result;
  };
  class ZbBuffer extends Uint8Array {
    static from(value, encoding = 'utf8') {
      if (typeof value === 'string') {
        if (encoding === 'hex') {
          if (value.length % 2 || !/^[0-9a-f]*$/i.test(value)) throw new TypeError('Invalid hex string');
          return new ZbBuffer(value.match(/../g)?.map(byte => parseInt(byte, 16)) ?? []);
        }
        if (encoding !== 'utf8' && encoding !== 'utf-8') throw new TypeError(`Unknown encoding: ${encoding}`);
        return new ZbBuffer(utf8Encode(value));
      }
      if (value instanceof ArrayBuffer) return new ZbBuffer(value);
      if (ArrayBuffer.isView(value)) return new ZbBuffer(value.buffer, value.byteOffset, value.byteLength);
      return new ZbBuffer(value || []);
    }
    static alloc(size, fill = 0, encoding) {
      const value = new ZbBuffer(size);
      value.fill(fill, 0, value.length, encoding);
      return value;
    }
    static allocUnsafe(size) { return new ZbBuffer(size); }
    static concat(values, length) {
      const buffers = Array.from(values, value => ZbBuffer.from(value));
      const size = length === undefined ? buffers.reduce((sum, value) => sum + value.length, 0) : Number(length);
      const result = ZbBuffer.alloc(size);
      let offset = 0;
      for (const value of buffers) {
        result.set(value.subarray(0, Math.max(0, size - offset)), offset);
        offset += value.length;
        if (offset >= size) break;
      }
      return result;
    }
    static isBuffer(value) { return value instanceof ZbBuffer; }
    static byteLength(value, encoding) { return typeof value === 'string' ? ZbBuffer.from(value, encoding).length : ZbBuffer.from(value).length; }
    toString(encoding = 'utf8') {
      if (encoding === 'hex') return Array.from(this, byte => byte.toString(16).padStart(2, '0')).join('');
      if (encoding !== 'utf8' && encoding !== 'utf-8') throw new TypeError(`Unknown encoding: ${encoding}`);
      return utf8Decode(this);
    }
    slice(start = 0, end = this.length) { return this.subarray(start, end); }
    subarray(start = 0, end = this.length) {
      const view = Uint8Array.prototype.subarray.call(this, start, end);
      return new ZbBuffer(view.buffer, view.byteOffset, view.byteLength);
    }
    copy(target, targetStart = 0, sourceStart = 0, sourceEnd = this.length) {
      if (!ArrayBuffer.isView(target)) throw new TypeError('target must be a Buffer or Uint8Array');
      targetStart = Math.max(0, Number(targetStart) || 0);
      sourceStart = Math.max(0, Number(sourceStart) || 0);
      sourceEnd = Math.min(this.length, Math.max(0, Number(sourceEnd)));
      const count = Math.max(0, Math.min(sourceEnd - sourceStart, target.length - targetStart));
      if (!count) return 0;
      target.set(Uint8Array.prototype.slice.call(this, sourceStart, sourceStart + count), targetStart);
      return count;
    }
    fill(value, start = 0, end = this.length, encoding) {
      start = Math.max(0, Number(start) || 0);
      end = Math.min(this.length, Math.max(start, Number(end)));
      if (typeof value === 'number') {
        Uint8Array.prototype.fill.call(this, value & 0xff, start, end);
        return this;
      }
      const pattern = typeof value === 'string' ? ZbBuffer.from(value, encoding) : ZbBuffer.from(value);
      if (!pattern.length) throw new TypeError('fill value must not be empty');
      for (let i = start; i < end; i++) this[i] = pattern[(i - start) % pattern.length];
      return this;
    }
    equals(other) {
      const value = ZbBuffer.from(other);
      return this.length === value.length && this.every((byte, index) => byte === value[index]);
    }
    readUInt8(offset = 0) { return this[offset]; }
    readUIntLE(offset, byteLength) { let value = 0; for (let i = byteLength - 1; i >= 0; i--) value = value * 256 + this[offset + i]; return value; }
    readUIntBE(offset, byteLength) { let value = 0; for (let i = 0; i < byteLength; i++) value = value * 256 + this[offset + i]; return value; }
    readUInt16LE(offset = 0) { return this.readUIntLE(offset, 2); }
    readUInt16BE(offset = 0) { return this.readUIntBE(offset, 2); }
    readUInt32LE(offset = 0) { return this.readUIntLE(offset, 4) >>> 0; }
    readUInt32BE(offset = 0) { return this.readUIntBE(offset, 4) >>> 0; }
    writeUInt8(value, offset = 0) { this[offset] = value; return offset + 1; }
    writeUIntLE(value, offset, byteLength) { for (let i = 0; i < byteLength; i++) { this[offset + i] = value & 0xff; value = Math.floor(value / 256); } return offset + byteLength; }
    writeUIntBE(value, offset, byteLength) { for (let i = byteLength - 1; i >= 0; i--) { this[offset + i] = value & 0xff; value = Math.floor(value / 256); } return offset + byteLength; }
    writeUInt16LE(value, offset = 0) { return this.writeUIntLE(value, offset, 2); }
    writeUInt16BE(value, offset = 0) { return this.writeUIntBE(value, offset, 2); }
    writeUInt32LE(value, offset = 0) { return this.writeUIntLE(value, offset, 4); }
    writeUInt32BE(value, offset = 0) { return this.writeUIntBE(value, offset, 4); }
  }
  globalThis.Buffer = ZbBuffer;
  const peerSocket = {
    addListener: (event, callback) => {
      if (typeof callback !== 'function') throw new TypeError('peerSocket listener must be a function');
      if (event === 'message' && !listeners.includes(callback)) listeners.push(callback);
    },
    removeListener: (event, callback) => {
      if (typeof callback !== 'function') throw new TypeError('peerSocket listener must be a function');
      if (event !== 'message') return;
      const index = listeners.indexOf(callback);
      if (index !== -1) listeners.splice(index, 1);
    },
    send: data => sendMessage('ZeroBoxHost', JSON.stringify({
      method: 'appside.peer.send', args: [ZbBuffer.from(data).toString('hex')]
    }))
  };
  globalThis.messaging = {peerSocket};
  const decodeBase64 = value => {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
    const input = String(value || '').replace(/[^A-Za-z0-9+/]/g, '');
    const output = [];
    let bits = 0, bitCount = 0;
    for (const char of input) {
      const index = alphabet.indexOf(char);
      if (index < 0) continue;
      bits = bits << 6 | index;
      bitCount += 6;
      if (bitCount >= 8) {
        bitCount -= 8;
        output.push(bits >> bitCount & 0xff);
      }
    }
    return new ZbBuffer(output);
  };
  globalThis.fetch = (input, options) => {
    const request = typeof input === 'string'
      ? {...(options || {}), url: input}
      : {...(input || {})};
    request.method = String(request.method || 'GET');
    request.headers = request.headers || {};
    return Promise.resolve(sendMessage('ZeroBoxHost', JSON.stringify({
      method: 'appside.fetch', args: [JSON.stringify(request)]
    }))).then(raw => {
      const response = raw && typeof raw === 'object' ? raw : {body: raw};
      const bodyText = () => {
        if (typeof response.body === 'string') return response.body;
        if (response.body == null) return '';
        return JSON.stringify(response.body);
      };
      response.ok = Number(response.status) >= 200 && Number(response.status) < 300;
      response.text = () => Promise.resolve(bodyText());
      response.json = () => Promise.resolve(
        typeof response.body === 'string' ? JSON.parse(response.body) : response.body
      );
      response.arrayBuffer = () => Promise.resolve(
        response.bodyBase64 == null
          ? ZbBuffer.from(bodyText()).buffer
          : decodeBase64(response.bodyBase64).buffer
      );
      response.clone = () => ({...response});
      return response;
    });
  };
  const values = new Map(Object.entries(initialSettings));
  const storageListeners = [];
  const persistSettings = change => {
    sendMessage('ZeroBoxHost', JSON.stringify({
      method: 'appside.settings.write', args: [JSON.stringify(change)]
    })).catch(error => console.error(error));
  };
  const notifyStorage = change => {
    for (const callback of [...storageListeners]) {
      try { callback(change); } catch (error) { console.error(error); }
    }
  };
  globalThis.settings = {settingsStorage: {
    get length() { return values.size; },
    getItem(key) { key = String(key); return values.has(key) ? values.get(key) : undefined; },
    setItem(key, value) {
      key = String(key);
      value = String(value);
      const oldValue = values.has(key) ? values.get(key) : undefined;
      values.set(key, value);
      persistSettings({operation: 'set', key, value});
      notifyStorage({key, newValue: value, oldValue});
    },
    removeItem(key) {
      key = String(key);
      if (!values.has(key)) return;
      const oldValue = values.get(key);
      values.delete(key);
      persistSettings({operation: 'remove', key});
      notifyStorage({key, newValue: undefined, oldValue});
    },
    clear() {
      const entries = Array.from(values.entries());
      values.clear();
      persistSettings({operation: 'clear'});
      for (const [key, oldValue] of entries) notifyStorage({key, newValue: undefined, oldValue});
    },
    key: index => Array.from(values.keys())[index] ?? null,
    toObject: () => Object.fromEntries(values),
    addListener(event, callback) {
      if (event !== 'change') return;
      if (typeof callback !== 'function') throw new TypeError('settingsStorage listener must be a function');
      if (!storageListeners.includes(callback)) storageListeners.push(callback);
    }
  }};
  let service;
  let started = false;
  let destroyed = false;
  globalThis.AppSideService = value => {
    service = value;
    globalThis.appSideService = value;
  };
  if (typeof console.debug !== 'function') console.debug = (...args) => console.log(...args);
  const logger = {getLogger: () => console, log: (...args) => console.log(...args), debug: (...args) => console.debug(...args), info: (...args) => console.info(...args), warn: (...args) => console.warn(...args), error: (...args) => console.error(...args)};
  globalThis.DeviceRuntimeCore = logger;
  globalThis.Logger = logger;
  globalThis.HmLogger = logger;
  AstroBox.event.addEventListener('appside.lifecycle.start', async () => {
    if (started) return;
    started = true;
    if (service && typeof service.onInit === 'function') await service.onInit();
    if (service && typeof service.onRun === 'function') await service.onRun();
  });
  AstroBox.event.addEventListener('appside.lifecycle.destroy', async () => {
    if (destroyed) return;
    destroyed = true;
    try {
      if (service && typeof service.onDestroy === 'function') await service.onDestroy();
    } finally {
      listeners.length = 0;
    }
  });
  AstroBox.event.addEventListener('appside.settings.external', encoded => {
    const next = JSON.parse(encoded);
    const previous = new Map(values);
    values.clear();
    for (const [key, value] of Object.entries(next)) values.set(key, String(value));
    const keys = new Set([...previous.keys(), ...values.keys()]);
    for (const key of keys) {
      const oldValue = previous.get(key);
      const newValue = values.get(key);
      if (oldValue !== newValue) notifyStorage({key, oldValue, newValue});
    }
  });
  AstroBox.event.addEventListener('appside.peer', hex => {
    const message = ZbBuffer.from(hex, 'hex');
    for (const callback of [...listeners]) {
      try {
        callback(message);
      } catch (error) {
        console.error(error);
      }
    }
  });
})();
''';
