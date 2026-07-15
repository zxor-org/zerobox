import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';

import 'plugin_runtime.dart';
import 'plugin_runtime_stub.dart'
    if (dart.library.io) 'plugin_runtime_quickjs.dart'
    if (dart.library.js_interop) 'plugin_runtime_web.dart'
    as implementation;
import 'plugin_runtime_wasm.dart';

PluginRuntime createPluginRuntime(
  PluginRuntimeType type, {
  required PluginStorage storage,
}) => switch (type) {
  PluginRuntimeType.wasm => WasmPluginRuntime(storage: storage),
  _ => implementation.createPluginRuntime(),
};

PluginRuntime createJavaScriptPluginRuntime() =>
    implementation.createPluginRuntime();
