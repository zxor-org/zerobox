import 'dart:typed_data';

import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';

enum PluginStorageArea { package, data, cache, temporary }

class PluginFileStat {
  const PluginFileStat({
    required this.path,
    required this.size,
    required this.isDirectory,
  });

  final String path;
  final int size;
  final bool isDirectory;

  Map<String, Object?> toJson() => {
    'path': path,
    'size': size,
    'isDirectory': isDirectory,
  };
}

class PluginStoragePath {
  const PluginStoragePath({required this.area, required this.relativePath});

  final PluginStorageArea area;
  final String relativePath;

  String get virtualPath {
    final root = switch (area) {
      PluginStorageArea.package => 'plugin',
      PluginStorageArea.data => 'data',
      PluginStorageArea.cache => 'cache',
      PluginStorageArea.temporary => 'temp',
    };
    return relativePath.isEmpty ? '/$root' : '/$root/$relativePath';
  }

  static PluginStoragePath parse(String value) {
    if (!value.startsWith('/') ||
        value.contains('\\') ||
        value.contains('\x00')) {
      throw FormatException('Invalid plugin path: $value');
    }
    final parts = value.substring(1).split('/');
    if (parts.isEmpty || parts.first.isEmpty) {
      throw FormatException('Invalid plugin path: $value');
    }
    final area = switch (parts.first) {
      'plugin' => PluginStorageArea.package,
      'data' => PluginStorageArea.data,
      'cache' => PluginStorageArea.cache,
      'temp' => PluginStorageArea.temporary,
      _ => throw FormatException('Unknown plugin path root: $value'),
    };
    final tail = parts.skip(1).toList(growable: false);
    if (tail.any(
      (part) =>
          part.isEmpty ||
          part == '.' ||
          part == '..' ||
          part.startsWith('.zerobox'),
    )) {
      throw FormatException('Unsafe plugin path: $value');
    }
    return PluginStoragePath(area: area, relativePath: tail.join('/'));
  }
}

abstract interface class PluginStorage {
  Future<List<InstalledPlugin>> loadInstalled();

  Future<InstalledPlugin> install(
    PluginPackage package, {
    required Map<String, Object?> config,
  });

  Future<void> writeConfig(String pluginId, Map<String, Object?> config);

  Future<Set<String>> readPermissionGrants(String pluginId);

  Future<void> writePermissionGrants(String pluginId, Set<String> grants);

  Future<void> removePlugin(String pluginId);

  Future<void> clearPluginData(String pluginId);

  Future<Uint8List> readFile(String pluginId, PluginStoragePath path);

  Future<void> writeFile(
    String pluginId,
    PluginStoragePath path,
    Uint8List bytes,
  );

  Future<int> writeFileStream(
    String pluginId,
    PluginStoragePath path,
    Stream<List<int>> stream, {
    bool append = false,
  });

  Future<List<PluginFileStat>> listDirectory(
    String pluginId,
    PluginStoragePath path,
  );

  Future<void> createDirectory(String pluginId, PluginStoragePath path);

  Future<PluginFileStat?> stat(String pluginId, PluginStoragePath path);

  Future<void> removeFile(String pluginId, PluginStoragePath path);

  String? nativePath(String pluginId, PluginStoragePath path);

  Future<void> close();
}
