import 'dart:typed_data';

import 'package:wasm_run_flutter/wasm_run_flutter.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';

final class PluginWasiSandbox {
  PluginWasiSandbox._({
    required this.pluginId,
    required this.storage,
    required this.config,
    required Map<String, WasiDirectory> webDirectories,
  }) : _webDirectories = webDirectories;

  final String pluginId;
  final PluginStorage storage;
  final WasiConfig config;
  final Map<String, WasiDirectory> _webDirectories;

  static Future<PluginWasiSandbox> create({
    required String pluginId,
    required PluginStorage storage,
  }) async {
    const writableRoots = ['/data', '/cache', '/temp'];
    final native = storage.nativePath(
      pluginId,
      PluginStoragePath.parse('/data'),
    );
    if (native != null) {
      for (final root in writableRoots) {
        await storage.createDirectory(pluginId, PluginStoragePath.parse(root));
      }
      final packageShadow = PluginStoragePath.parse(
        '/temp/zerobox-runtime/plugin',
      );
      if (await storage.stat(pluginId, packageShadow) != null) {
        await storage.removeFile(pluginId, packageShadow);
      }
      await _copyTree(
        storage,
        pluginId,
        PluginStoragePath.parse('/plugin'),
        packageShadow,
      );
      final preopened = <PreopenedDir>[
        PreopenedDir(
          wasmGuestPath: '/plugin',
          hostPath: storage.nativePath(pluginId, packageShadow)!,
        ),
        for (final root in writableRoots)
          PreopenedDir(
            wasmGuestPath: root,
            hostPath: storage.nativePath(
              pluginId,
              PluginStoragePath.parse(root),
            )!,
          ),
      ];
      return PluginWasiSandbox._(
        pluginId: pluginId,
        storage: storage,
        config: WasiConfig(
          preopenedDirs: preopened,
          webBrowserFileSystem: const {},
          captureStdout: true,
          captureStderr: true,
        ),
        webDirectories: const {},
      );
    }

    final directories = <String, WasiDirectory>{
      for (final root in const ['/plugin', ...writableRoots])
        root: await _snapshot(storage, pluginId, PluginStoragePath.parse(root)),
    };
    return PluginWasiSandbox._(
      pluginId: pluginId,
      storage: storage,
      config: WasiConfig(
        preopenedDirs: const [],
        webBrowserFileSystem: directories,
        captureStdout: true,
        captureStderr: true,
      ),
      webDirectories: directories,
    );
  }

  Future<void> sync() async {
    for (final root in const ['/data', '/cache', '/temp']) {
      final directory = _webDirectories[root];
      if (directory == null) continue;
      await _syncDirectory(
        storage,
        pluginId,
        PluginStoragePath.parse(root),
        directory,
      );
    }
  }

  static Future<void> _copyTree(
    PluginStorage storage,
    String pluginId,
    PluginStoragePath source,
    PluginStoragePath destination,
  ) async {
    await storage.createDirectory(pluginId, destination);
    for (final entry in await storage.listDirectory(pluginId, source)) {
      final name = entry.path.split('/').last;
      final childSource = PluginStoragePath.parse(entry.path);
      final childDestination = PluginStoragePath.parse(
        '${destination.virtualPath}/$name',
      );
      if (entry.isDirectory) {
        await _copyTree(storage, pluginId, childSource, childDestination);
      } else {
        await storage.writeFile(
          pluginId,
          childDestination,
          await storage.readFile(pluginId, childSource),
        );
      }
    }
  }

  static Future<WasiDirectory> _snapshot(
    PluginStorage storage,
    String pluginId,
    PluginStoragePath path,
  ) async {
    final items = <String, WasiFd>{};
    for (final entry in await storage.listDirectory(pluginId, path)) {
      final child = PluginStoragePath.parse(entry.path);
      final name = child.relativePath.split('/').last;
      items[name] = entry.isDirectory
          ? await _snapshot(storage, pluginId, child)
          : WasiFile(await storage.readFile(pluginId, child));
    }
    return WasiDirectory(items);
  }

  static Future<void> _syncDirectory(
    PluginStorage storage,
    String pluginId,
    PluginStoragePath path,
    WasiDirectory directory,
  ) async {
    await storage.createDirectory(pluginId, path);
    final existing = {
      for (final entry in await storage.listDirectory(pluginId, path))
        entry.path.split('/').last: entry,
    };
    for (final entry in existing.entries) {
      if (!directory.items.containsKey(entry.key)) {
        await storage.removeFile(
          pluginId,
          PluginStoragePath.parse(entry.value.path),
        );
      }
    }
    for (final entry in directory.items.entries) {
      final child = PluginStoragePath.parse('${path.virtualPath}/${entry.key}');
      switch (entry.value) {
        case WasiDirectory value:
          await _syncDirectory(storage, pluginId, child, value);
        case WasiFile value:
          await storage.writeFile(
            pluginId,
            child,
            Uint8List.fromList(value.content),
          );
        default:
          throw StateError('Unsupported WASI file system entry');
      }
    }
  }
}
