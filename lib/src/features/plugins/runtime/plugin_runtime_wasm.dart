import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:wasm_run_flutter/wasm_run_flutter.dart';
import 'package:zerobox/src/core/wasm/wasm_runtime.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';

import 'plugin_runtime.dart';
import 'plugin_wasi_sandbox.dart';

final class WasmPluginRuntime implements PluginRuntime {
  WasmPluginRuntime({required this.storage});

  final PluginStorage storage;
  final _requests = <int, _WasmHostResult>{};
  WasmScope? _scope;
  ScopedWasmInstance? _instance;
  PluginWasiSandbox? _sandbox;
  PluginHostCall? _hostCall;
  StreamSubscription<Uint8List>? _stdoutSubscription;
  StreamSubscription<Uint8List>? _stderrSubscription;
  var _requestSequence = 0;
  var _closed = true;

  @override
  Map<String, Object?> get diagnostics => {
    'engine': 'wasm_run',
    'running': !_closed,
    'pendingRequests': _requests.length,
    'instantiated': _instance != null,
  };

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
    _closed = false;
    _hostCall = hostCall;
    final scope = WasmRuntime.shared.openScope('plugin.$pluginId.runtime');
    _scope = scope;
    final sandbox = await PluginWasiSandbox.create(
      pluginId: pluginId,
      storage: storage,
    );
    _sandbox = sandbox;
    try {
      final instance = await scope.instantiate(
        entryBytes,
        cacheKey: 'plugin:$pluginId:$pluginVersion:entry',
        wasiConfig: sandbox.config,
        configure: _configureHostImports,
      );
      _instance = instance;
      _stdoutSubscription = instance.stdout.listen(
        (bytes) => _emitStdio('log.info', bytes),
      );
      _stderrSubscription = instance.stderr.listen(
        (bytes) => _emitStdio('log.error', bytes),
      );
      final start = instance.functionOrNull('zerobox_start');
      final wasiStart = instance.functionOrNull('_start');
      if (start == null && wasiStart == null) {
        throw StateError(
          'WASM plugin must export zerobox_start or WASI _start',
        );
      }
      (start ?? wasiStart!).call();
    } catch (_) {
      await close();
      rethrow;
    }
  }

  void _configureHostImports(WasmInstanceBuilder builder) {
    builder
      ..addImport(
        'zerobox',
        'request',
        WasmFunction(
          (
            int methodPointer,
            int methodLength,
            int argsPointer,
            int argsLength,
          ) => _request(methodPointer, methodLength, argsPointer, argsLength),
          params: const [ValueTy.i32, ValueTy.i32, ValueTy.i32, ValueTy.i32],
          results: const [ValueTy.i32],
        ),
      )
      ..addImport(
        'zerobox',
        'poll',
        WasmFunction(
          (int requestId) => _requests[requestId]?.status ?? -1,
          params: const [ValueTy.i32],
          results: const [ValueTy.i32],
        ),
      )
      ..addImport(
        'zerobox',
        'result_len',
        WasmFunction(
          (int requestId) => _requests[requestId]?.bytes.length ?? -1,
          params: const [ValueTy.i32],
          results: const [ValueTy.i32],
        ),
      )
      ..addImport(
        'zerobox',
        'result_read',
        WasmFunction(
          (int requestId, int pointer, int capacity) =>
              _readResult(requestId, pointer, capacity),
          params: const [ValueTy.i32, ValueTy.i32, ValueTy.i32],
          results: const [ValueTy.i32],
        ),
      )
      ..addImport(
        'zerobox',
        'result_drop',
        WasmFunction.voidReturn((int requestId) {
          _requests.remove(requestId);
        }, params: const [ValueTy.i32]),
      );
  }

  int _request(
    int methodPointer,
    int methodLength,
    int argsPointer,
    int argsLength,
  ) {
    final method = _readUtf8(methodPointer, methodLength);
    final decoded = jsonDecode(_readUtf8(argsPointer, argsLength));
    if (decoded is! List) {
      throw const FormatException('WASM Host API arguments must be an array');
    }
    final id = ++_requestSequence;
    _requests[id] = const _WasmHostResult.pending();
    Future.sync(() => _hostCall!(method, decoded.cast<Object?>())).then(
      (value) => _completeRequest(id, ok: true, value: value),
      onError: (Object error, StackTrace stackTrace) =>
          _completeRequest(id, ok: false, value: error.toString()),
    );
    return id;
  }

  void _completeRequest(int id, {required bool ok, required Object? value}) {
    if (_closed || !_requests.containsKey(id)) return;
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode({'ok': ok, ok ? 'value' : 'error': value})),
    );
    _requests[id] = _WasmHostResult(status: ok ? 1 : 2, bytes: bytes);
    scheduleMicrotask(() {
      if (_closed) return;
      _instance?.functionOrNull('zerobox_on_result')?.call([id]);
    });
  }

  void _emitStdio(String method, Uint8List bytes) {
    final message = utf8.decode(bytes, allowMalformed: true).trimRight();
    if (message.isEmpty) return;
    unawaited(Future.sync(() => _hostCall?.call(method, [message])));
  }

  int _readResult(int id, int pointer, int capacity) {
    final result = _requests[id];
    if (result == null || result.status == 0) return -1;
    if (capacity < result.bytes.length) return -result.bytes.length;
    final memory = _memory;
    _checkRange(memory, pointer, result.bytes.length);
    memory.setRange(pointer, pointer + result.bytes.length, result.bytes);
    return result.bytes.length;
  }

  String _readUtf8(int pointer, int length) {
    final memory = _memory;
    _checkRange(memory, pointer, length);
    return utf8.decode(memory.sublist(pointer, pointer + length));
  }

  Uint8List get _memory => _requiredInstance.memory('memory').view;

  ScopedWasmInstance get _requiredInstance {
    final instance = _instance;
    if (instance == null) {
      throw StateError(
        'WASM host imports cannot be called from a module start section',
      );
    }
    return instance;
  }

  void _checkRange(Uint8List memory, int pointer, int length) {
    if (pointer < 0 || length < 0 || pointer + length > memory.length) {
      throw RangeError('WASM memory range is out of bounds');
    }
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
    return _invokeJsonExport('zerobox_callback', callbackId, arguments);
  }

  @override
  Future<void> dispatchEvent(String name, String payload) async {
    final event = _instance?.functionOrNull('zerobox_event');
    if (event == null) return;
    _invokeStringExport(event, name, payload);
  }

  Object? _invokeJsonExport(String exportName, String name, Object? value) {
    final function = _requiredInstance.functionOrNull(exportName);
    if (function == null) {
      throw StateError('WASM plugin does not export $exportName');
    }
    return _invokeStringExport(function, name, jsonEncode(value));
  }

  Object? _invokeStringExport(
    WasmFunction function,
    String first,
    String second,
  ) {
    final firstBytes = Uint8List.fromList(utf8.encode(first));
    final secondBytes = Uint8List.fromList(utf8.encode(second));
    final firstPointer = _allocate(firstBytes);
    final secondPointer = _allocate(secondBytes);
    try {
      final values = function.call([
        firstPointer,
        firstBytes.length,
        secondPointer,
        secondBytes.length,
      ]);
      return values.firstOrNull;
    } finally {
      _free(firstPointer, firstBytes.length);
      _free(secondPointer, secondBytes.length);
    }
  }

  int _allocate(Uint8List bytes) {
    final alloc = _requiredInstance.functionOrNull('zerobox_alloc');
    if (alloc == null) {
      throw StateError('WASM plugin must export zerobox_alloc');
    }
    final pointer = alloc.call([bytes.length]).firstOrNull;
    if (pointer is! int) throw StateError('zerobox_alloc returned no pointer');
    final memory = _memory;
    _checkRange(memory, pointer, bytes.length);
    memory.setRange(pointer, pointer + bytes.length, bytes);
    return pointer;
  }

  void _free(int pointer, int length) {
    _instance?.functionOrNull('zerobox_free')?.call([pointer, length]);
  }

  @override
  Future<void> close() async {
    _closed = true;
    _requests.clear();
    await _stdoutSubscription?.cancel();
    await _stderrSubscription?.cancel();
    _stdoutSubscription = null;
    _stderrSubscription = null;
    _hostCall = null;
    _instance = null;
    _scope?.dispose();
    _scope = null;
    final sandbox = _sandbox;
    _sandbox = null;
    if (sandbox != null) await sandbox.sync();
  }
}

final class _WasmHostResult {
  const _WasmHostResult({required this.status, required this.bytes});
  const _WasmHostResult.pending() : status = 0, bytes = const <int>[];

  final int status;
  final List<int> bytes;
}
