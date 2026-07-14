import 'dart:async';
import 'dart:convert';

import 'package:quickjs_engine/quickjs_engine.dart';

import 'plugin_runtime.dart';

PluginRuntime createPluginRuntime() => _QuickJsPluginRuntime();

class _QuickJsPluginRuntime implements PluginRuntime {
  QuickJsRuntime2? _runtime;
  PluginHostCall? _hostCall;
  final _timers = <int, Timer>{};

  @override
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required String source,
    required PluginHostCall hostCall,
  }) async {
    await close();
    final runtime = QuickJsRuntime2(
      stackSize: 1024 * 1024,
      // quickjs_engine 0.1.1 declares jsSetMemoryLimit in Dart but does not
      // export an implementation from its native bridge
      memoryLimit: 0,
      timeout: 10 * 1000,
      hostPromiseRejectionHandler: (reason) {
        unawaited(
          Future.sync(() => hostCall('console.error', [reason.toString()])),
        );
      },
    );
    _runtime = runtime;
    _hostCall = hostCall;

    JavascriptRuntime.channelFunctionsRegistered[runtime
        .getEngineInstanceId()]!['ZeroBoxHost'] = (dynamic message) {
      final json = (message as Map).cast<String, Object?>();
      final method = json['method']?.toString() ?? '';
      final arguments = (json['args'] as List?)?.cast<Object?>() ?? const [];
      if (method == 'runtime.setTimer') {
        return _setTimer(arguments);
      }
      if (method == 'runtime.clearTimer') {
        return _clearTimer(arguments);
      }
      final result = hostCall(method, arguments);
      if (result is Future) {
        result.whenComplete(() => scheduleMicrotask(runtime.dispatch));
      }
      return result;
    };

    _evaluate(runtime, abV1PluginBootstrap, name: 'zerobox_abv1_host.js');
    _evaluate(
      runtime,
      '__zbSetRuntimeGlobals('
      '${jsonEncode(pluginId)}, '
      '${jsonEncode(pluginName)}, '
      '${jsonEncode(pluginVersion)}, '
      '${jsonEncode(runtimeVersion)})',
      name: 'zerobox_abv1_globals.js',
    );
    _evaluate(runtime, source, name: '$pluginId/main.js');
    final started = runtime.evaluate('__zbStartPlugin()');
    if (started.isError) throw StateError(started.stringResult);
    await _resolveResult(runtime, started.rawResult);
  }

  @override
  Future<void> invokeCallback(String callbackId, [String? value]) async {
    await invokeRegistered(callbackId, value == null ? const [] : [value]);
  }

  @override
  Future<Object?> invokeRegistered(
    String callbackId,
    List<String> arguments,
  ) async {
    final runtime = _requiredRuntime;
    final result = runtime.evaluate(
      '__zbInvokeRegistered(${jsonEncode(callbackId)}, ${jsonEncode(arguments)})',
    );
    if (result.isError) throw StateError(result.stringResult);
    return _resolveResult(runtime, result.rawResult);
  }

  @override
  Future<void> dispatchEvent(String name, String payload) async {
    final runtime = _requiredRuntime;
    final result = runtime.evaluate(
      '__zbDispatchEvent(${jsonEncode(name)}, ${jsonEncode(payload)})',
    );
    if (result.isError) throw StateError(result.stringResult);
    await _resolveResult(runtime, result.rawResult);
  }

  @override
  Future<void> close() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _hostCall = null;
    final runtime = _runtime;
    _runtime = null;
    if (runtime == null) return;
    JavascriptRuntime.channelFunctionsRegistered.remove(
      runtime.getEngineInstanceId(),
    );
    runtime.dispose();
  }

  QuickJsRuntime2 get _requiredRuntime {
    final runtime = _runtime;
    if (runtime == null) throw StateError('Plugin is not running');
    return runtime;
  }

  void _evaluate(
    QuickJsRuntime2 runtime,
    String source, {
    required String name,
  }) {
    final result = runtime.evaluate(source, name: name);
    if (result.isError) throw StateError(result.stringResult);
  }

  Future<Object?> _resolveResult(
    QuickJsRuntime2 runtime,
    Object? rawResult,
  ) async {
    await runtime.dispatch();
    if (rawResult is! Future) return rawResult;
    final value = await rawResult;
    await runtime.dispatch();
    return value;
  }

  Object? _setTimer(List<Object?> arguments) {
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
    return null;
  }

  Object? _clearTimer(List<Object?> arguments) {
    final id = (arguments.firstOrNull as num?)?.toInt();
    if (id != null) _timers.remove(id)?.cancel();
    return null;
  }

  Future<void> _fireTimer(int id) async {
    final runtime = _runtime;
    if (runtime == null) return;
    try {
      final result = runtime.evaluate('__zbFireTimer($id)');
      if (result.isError) throw StateError(result.stringResult);
      await _resolveResult(runtime, result.rawResult);
    } catch (error) {
      await Future.sync(
        () => _hostCall?.call('console.error', ['Timer $id failed: $error']),
      );
    }
  }
}
