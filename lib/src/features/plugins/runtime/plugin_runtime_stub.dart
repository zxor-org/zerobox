import 'plugin_runtime.dart';

PluginRuntime createPluginRuntime() => _UnsupportedPluginRuntime();

class _UnsupportedPluginRuntime implements PluginRuntime {
  @override
  Future<void> start({
    required String pluginId,
    required String pluginName,
    required String pluginVersion,
    required String runtimeVersion,
    required String source,
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
    List<String> arguments,
  ) async => null;

  @override
  Future<void> dispatchEvent(String name, String payload) async {}

  @override
  Future<void> close() async {}
}
