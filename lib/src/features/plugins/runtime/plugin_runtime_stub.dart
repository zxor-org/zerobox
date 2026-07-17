import 'plugin_runtime.dart';
import 'dart:typed_data';

PluginRuntime createPluginRuntime() => _UnsupportedPluginRuntime();

class _UnsupportedPluginRuntime implements PluginRuntime {
  @override
  Map<String, Object?> get diagnostics => const {
    'engine': 'unsupported',
    'running': false,
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
    throw UnsupportedError(
      'The ABP v1 JavaScript runtime is not available on this platform yet',
    );
  }

  @override
  Future<void> invokeCallback(String callbackId, [String? value]) async {}

  @override
  Future<Object?> invokeRegistered(
    String callbackId,
    List<Object?> arguments,
  ) async => null;

  @override
  Future<void> dispatchEvent(String name, String payload) async {}

  @override
  Future<void> close() async {}
}
