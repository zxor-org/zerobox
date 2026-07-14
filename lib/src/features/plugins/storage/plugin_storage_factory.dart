import 'plugin_storage.dart';
import 'plugin_storage_stub.dart'
    if (dart.library.io) 'plugin_storage_io.dart'
    if (dart.library.js_interop) 'plugin_storage_web.dart'
    as implementation;

Future<PluginStorage> createPluginStorage() =>
    implementation.createPluginStorage();
