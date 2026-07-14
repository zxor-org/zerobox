import 'plugin_runtime.dart';
import 'plugin_runtime_stub.dart'
    if (dart.library.io) 'plugin_runtime_quickjs.dart'
    if (dart.library.js_interop) 'plugin_runtime_web.dart'
    as implementation;

PluginRuntime createPluginRuntime() => implementation.createPluginRuntime();
