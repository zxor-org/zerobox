import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:zerobox/src/core/wasm/wasm_runtime.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';

import 'plugin_wasi_sandbox.dart';

class PluginWasmHost {
  PluginWasmHost({required this.pluginId, required this.storage})
    : _scope = WasmRuntime.shared.openScope('plugin.$pluginId');

  final String pluginId;
  final PluginStorage storage;
  final WasmScope _scope;
  final Map<String, ScopedWasmInstance> _instances = {};
  PluginWasiSandbox? _sandbox;
  var _sequence = 0;

  Future<String> load(String path, Map<String, Object?> options) async {
    final storagePath = PluginStoragePath.parse(path);
    final bytes = await storage.readFile(pluginId, storagePath);
    final wasi = options['wasi'] != false
        ? (_sandbox ??= await PluginWasiSandbox.create(
            pluginId: pluginId,
            storage: storage,
          ))
        : null;
    final digest = sha256.convert(bytes);
    final instance = await _scope.instantiate(
      bytes,
      cacheKey: 'plugin:$pluginId:$path:$digest',
      wasiConfig: wasi?.config,
    );
    final id = 'wasm_${++_sequence}';
    _instances[id] = instance;
    return id;
  }

  List<Object?> call(String id, String function, List<Object?> arguments) {
    return _instance(id).call(function, arguments);
  }

  String readMemory(String id, String memoryName, int offset, int length) {
    final memory = _instance(id).memory(memoryName).view;
    _checkMemoryRange(memory, offset, length);
    return base64Encode(memory.sublist(offset, offset + length));
  }

  void writeMemory(String id, String memoryName, int offset, Uint8List bytes) {
    final memory = _instance(id).memory(memoryName).view;
    _checkMemoryRange(memory, offset, bytes.length);
    memory.setRange(offset, offset + bytes.length, bytes);
  }

  void disposeInstance(String id) => _instances.remove(id)?.dispose();

  Future<void> dispose() async {
    _instances.clear();
    _scope.dispose();
    final sandbox = _sandbox;
    _sandbox = null;
    if (sandbox != null) await sandbox.sync();
  }

  ScopedWasmInstance _instance(String id) {
    final instance = _instances[id];
    if (instance == null) throw StateError('WASM instance not found: $id');
    return instance;
  }

  void _checkMemoryRange(Uint8List memory, int offset, int length) {
    if (offset < 0 || length < 0 || offset + length > memory.length) {
      throw RangeError('WASM memory range is out of bounds');
    }
  }
}
