import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'plugin_runtime.dart';

PluginRuntime createPluginRuntime() => _WebPluginRuntime();

@JS('zeroboxPluginHostCall')
external set _webHostCall(JSFunction value);

@JS('ZeroBoxPluginRuntime.create')
external JSPromise<JSAny?> _webCreate(
  JSString id,
  JSString bootstrap,
  JSString globals,
  JSString source,
);

@JS('ZeroBoxPluginRuntime.invoke')
external JSPromise<JSAny?> _webInvoke(
  JSString id,
  JSString callback,
  JSArray<JSAny?> arguments,
);

@JS('ZeroBoxPluginRuntime.dispatchEvent')
external JSPromise<JSAny?> _webDispatchEvent(
  JSString id,
  JSString name,
  JSString payload,
);

@JS('ZeroBoxPluginRuntime.fireTimer')
external JSPromise<JSAny?> _webFireTimer(JSString id, JSNumber timerId);

@JS('ZeroBoxPluginRuntime.close')
external JSPromise<JSAny?> _webClose(JSString id);

class _WebPluginRuntime implements PluginRuntime {
  static final _instances = <String, _WebPluginRuntime>{};
  static bool _hostInstalled = false;

  String? _pluginId;
  PluginHostCall? _hostCall;
  final _timers = <int, Timer>{};

  @override
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required Uint8List entryBytes,
    required String bootstrap,
    required PluginHostCall hostCall,
  }) async {
    await close();
    _installHostBridge();
    _pluginId = pluginId;
    _hostCall = hostCall;
    _instances[pluginId] = this;
    final globals =
        '__zbSetRuntimeGlobals('
        '${jsonEncode(pluginId)}, '
        '${jsonEncode(pluginName)}, '
        '${jsonEncode(pluginVersion)}, '
        '${jsonEncode(runtimeVersion)})';
    try {
      await _webCreate(
        pluginId.toJS,
        bootstrap.toJS,
        globals.toJS,
        utf8.decode(entryBytes).toJS,
      ).toDart;
    } catch (_) {
      _instances.remove(pluginId);
      _pluginId = null;
      _hostCall = null;
      rethrow;
    }
  }

  static void _installHostBridge() {
    if (_hostInstalled) return;
    _hostInstalled = true;
    _webHostCall = ((JSString id, JSString channel, JSString message) {
      return _dispatchHost(id.toDart, channel.toDart, message.toDart);
    }).toJS;
  }

  static JSAny? _dispatchHost(String id, String channel, String message) {
    if (channel != 'ZeroBoxHost') {
      throw UnsupportedError('Unknown plugin channel: $channel');
    }
    final instance = _instances[id];
    final hostCall = instance?._hostCall;
    if (instance == null || hostCall == null) {
      throw StateError('Plugin runtime not found: $id');
    }
    final decoded = jsonDecode(message);
    if (decoded is! Map) throw const FormatException('Invalid host message');
    final json = decoded.cast<String, Object?>();
    final method = json['method']?.toString() ?? '';
    final arguments = (json['args'] as List?)?.cast<Object?>() ?? const [];
    if (method == 'runtime.setTimer') {
      instance._setTimer(arguments);
      return null;
    }
    if (method == 'runtime.clearTimer') {
      instance._clearTimer(arguments);
      return null;
    }
    final value = hostCall(method, arguments);
    if (value is Future) {
      return value.then((value) => value?.jsify()).toJS;
    }
    return value?.jsify();
  }

  @override
  Future<void> invokeCallback(String callbackId, [String? value]) async {
    await invokeRegistered(callbackId, value == null ? const [] : [value]);
  }

  @override
  Future<Object?> invokeRegistered(
    String callbackId,
    List<Object?> arguments,
  ) async {
    final id = _requiredId;
    final value = await _webInvoke(
      id.toJS,
      callbackId.toJS,
      arguments.map((value) => value?.jsify()).toList().toJS,
    ).toDart;
    return value?.dartify();
  }

  @override
  Future<void> dispatchEvent(String name, String payload) async {
    final id = _requiredId;
    await _webDispatchEvent(id.toJS, name.toJS, payload.toJS).toDart;
  }

  @override
  Future<void> close() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    final id = _pluginId;
    _pluginId = null;
    _hostCall = null;
    if (id == null) return;
    _instances.remove(id);
    await _webClose(id.toJS).toDart;
  }

  String get _requiredId {
    final id = _pluginId;
    if (id == null) throw StateError('Plugin is not running');
    return id;
  }

  void _setTimer(List<Object?> arguments) {
    final id = (arguments.firstOrNull as num?)?.toInt();
    if (id == null) throw const FormatException('Timer ID is required');
    final milliseconds = ((arguments.elementAtOrNull(1) as num?)?.toInt() ?? 0)
        .clamp(0, 0x7fffffff);
    final repeat = arguments.elementAtOrNull(2) == true;
    _timers.remove(id)?.cancel();
    final duration = Duration(
      milliseconds: repeat && milliseconds == 0 ? 1 : milliseconds,
    );
    _timers[id] = repeat
        ? Timer.periodic(duration, (_) => unawaited(_fireTimer(id)))
        : Timer(duration, () {
            _timers.remove(id);
            unawaited(_fireTimer(id));
          });
  }

  void _clearTimer(List<Object?> arguments) {
    final id = (arguments.firstOrNull as num?)?.toInt();
    if (id != null) _timers.remove(id)?.cancel();
  }

  Future<void> _fireTimer(int timerId) async {
    final id = _pluginId;
    if (id == null) return;
    try {
      await _webFireTimer(id.toJS, timerId.toJS).toDart;
    } catch (error) {
      await Future.sync(
        () => _hostCall?.call('log.error', ['Timer $timerId failed: $error']),
      );
    }
  }
}
