import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';

import 'plugin_storage.dart';

Future<PluginStorage> createPluginStorage() async {
  final localAppData = Platform.environment['LOCALAPPDATA'];
  final support = Platform.isWindows
      ? Directory(
          '${localAppData ?? (await getApplicationSupportDirectory()).path}'
          '${Platform.pathSeparator}ZeroBox',
        )
      : await getApplicationSupportDirectory();
  final cache = Platform.isWindows
      ? Directory(
          '${localAppData ?? (await getApplicationCacheDirectory()).path}'
          '${Platform.pathSeparator}ZeroBox'
          '${Platform.pathSeparator}cache',
        )
      : await getApplicationCacheDirectory();
  final temporary = await getTemporaryDirectory();
  return createIoPluginStorage(
    installedRoot: Directory('${support.path}${Platform.pathSeparator}plugins'),
    cacheRoot: Directory('${cache.path}${Platform.pathSeparator}plugins'),
    temporaryRoot: Directory(
      '${temporary.path}${Platform.pathSeparator}zerobox'
      '${Platform.pathSeparator}plugins-$pid',
    ),
  );
}

Future<PluginStorage> createIoPluginStorage({
  required Directory installedRoot,
  required Directory cacheRoot,
  required Directory temporaryRoot,
}) async {
  final storage = _IoPluginStorage(
    installedRoot: installedRoot,
    cacheRoot: cacheRoot,
    temporaryRoot: temporaryRoot,
  );
  await storage.initialize();
  return storage;
}

class _IoPluginStorage implements PluginStorage {
  _IoPluginStorage({
    required this.installedRoot,
    required this.cacheRoot,
    required this.temporaryRoot,
  });

  static const _manifestFile = 'manifest.json';
  static const _metadataDirectoryName = '.zerobox';
  static const _configFile = 'config.json';
  static const _permissionsFile = 'permissions.json';
  static const _legacyConfigFile = '.zerobox-config.json';
  static const _legacyPermissionsFile = '.zerobox-permissions.json';

  final Directory installedRoot;
  final Directory cacheRoot;
  final Directory temporaryRoot;

  Future<void> initialize() async {
    await installedRoot.create(recursive: true);
    await cacheRoot.create(recursive: true);
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
    await temporaryRoot.create(recursive: true);
  }

  @override
  Future<List<InstalledPlugin>> loadInstalled() async {
    final plugins = <InstalledPlugin>[];
    await for (final entity in installedRoot.list(followLinks: false)) {
      if (entity is! Directory) continue;
      final id = _leafName(entity.path);
      if (!_isPluginId(id)) continue;
      try {
        plugins.add(await _loadPlugin(id));
      } catch (_) {
        // A damaged plugin is isolated from the rest of the registry
      }
    }
    return plugins;
  }

  Future<InstalledPlugin> _loadPlugin(String id) async {
    final package = _packageDirectory(id);
    final manifestFile = File(_join(package.path, _manifestFile));
    final manifest = const PluginPackageReader().readManifest(
      await manifestFile.readAsBytes(),
    );
    if (manifest.id != id) {
      throw const FormatException(
        'Plugin directory ID does not match manifest',
      );
    }
    final entryBytes = await _packageFile(id, manifest.entry).readAsBytes();
    final icon = manifest.iconPath == null
        ? null
        : await _packageFile(id, manifest.iconPath!).readAsBytes();
    await readPermissionGrants(id);
    return InstalledPlugin(
      manifest: manifest,
      entryBytes: entryBytes,
      config: await _readConfig(id),
      iconBase64: icon == null ? null : base64Encode(icon),
    );
  }

  Future<Map<String, Object?>> _readConfig(String id) async {
    await _ensureMetadataSafe(id);
    var file = _metadataFile(id, _configFile);
    final legacy = File(_join(_dataDirectory(id).path, _legacyConfigFile));
    if (!await file.exists() && await legacy.exists()) {
      final bytes = await legacy.readAsBytes();
      await writeConfig(
        id,
        (jsonDecode(utf8.decode(bytes)) as Map).cast<String, Object?>(),
      );
      await legacy.delete();
      file = _metadataFile(id, _configFile);
    }
    if (!await file.exists()) return const {};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map) throw const FormatException('Invalid plugin config');
    return decoded.cast<String, Object?>();
  }

  @override
  Future<InstalledPlugin> install(
    PluginPackage package, {
    required Map<String, Object?> config,
  }) async {
    final id = package.manifest.id;
    _requirePluginId(id);
    final pluginRoot = _pluginDirectory(id);
    if (await FileSystemEntity.type(pluginRoot.path, followLinks: false) ==
        FileSystemEntityType.link) {
      throw StateError('Symbolic links are not allowed in plugin storage');
    }
    await pluginRoot.create(recursive: true);
    final nonce = DateTime.now().microsecondsSinceEpoch;
    final staging = Directory(_join(pluginRoot.path, '.package-$nonce'));
    final target = _packageDirectory(id);
    final backup = Directory(_join(pluginRoot.path, '.package-backup-$nonce'));
    await staging.create(recursive: true);
    try {
      for (final entry in package.files.entries) {
        final file = _fileBelow(staging, entry.key);
        await file.parent.create(recursive: true);
        await file.writeAsBytes(entry.value, flush: true);
      }
      await writeConfig(id, config);
      if (await target.exists()) await target.rename(backup.path);
      try {
        await staging.rename(target.path);
      } catch (_) {
        if (await backup.exists() && !await target.exists()) {
          await backup.rename(target.path);
        }
        rethrow;
      }
      if (await backup.exists()) await backup.delete(recursive: true);
      return package.installed(config: config);
    } finally {
      if (await staging.exists()) await staging.delete(recursive: true);
    }
  }

  @override
  Future<void> writeConfig(String pluginId, Map<String, Object?> config) async {
    _requirePluginId(pluginId);
    await _ensureMetadataSafe(pluginId);
    final directory = _metadataDirectory(pluginId);
    await directory.create(recursive: true);
    final target = File(_join(directory.path, _configFile));
    final temporary = File('${target.path}.tmp-$pid');
    await temporary.writeAsString(jsonEncode(config), flush: true);
    await _replaceFile(temporary, target);
  }

  @override
  Future<Set<String>> readPermissionGrants(String pluginId) async {
    _requirePluginId(pluginId);
    await _ensureMetadataSafe(pluginId);
    var file = _metadataFile(pluginId, _permissionsFile);
    final legacy = File(
      _join(_dataDirectory(pluginId).path, _legacyPermissionsFile),
    );
    if (!await file.exists() && await legacy.exists()) {
      final decoded = jsonDecode(await legacy.readAsString());
      if (decoded is! List) {
        throw const FormatException('Invalid plugin permission grants');
      }
      await writePermissionGrants(
        pluginId,
        decoded.map((value) => value.toString()).toSet(),
      );
      await legacy.delete();
      file = _metadataFile(pluginId, _permissionsFile);
    }
    if (!await file.exists()) return <String>{};
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! List) {
      throw const FormatException('Invalid plugin permission grants');
    }
    return decoded.map((value) => value.toString()).toSet();
  }

  @override
  Future<void> writePermissionGrants(
    String pluginId,
    Set<String> grants,
  ) async {
    _requirePluginId(pluginId);
    await _ensureMetadataSafe(pluginId);
    final directory = _metadataDirectory(pluginId);
    await directory.create(recursive: true);
    final target = File(_join(directory.path, _permissionsFile));
    final temporary = File('${target.path}.tmp-$pid');
    await temporary.writeAsString(
      jsonEncode(grants.toList()..sort()),
      flush: true,
    );
    await _replaceFile(temporary, target);
  }

  @override
  Future<void> removePlugin(String pluginId) async {
    _requirePluginId(pluginId);
    for (final directory in [
      _pluginDirectory(pluginId),
      _cacheDirectory(pluginId),
      _temporaryDirectory(pluginId),
    ]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
  }

  @override
  Future<void> clearPluginData(String pluginId) async {
    _requirePluginId(pluginId);
    for (final directory in [
      _dataDirectory(pluginId),
      _metadataDirectory(pluginId),
      _cacheDirectory(pluginId),
      _temporaryDirectory(pluginId),
    ]) {
      if (await directory.exists()) await directory.delete(recursive: true);
    }
    await _dataDirectory(pluginId).create(recursive: true);
    await _cacheDirectory(pluginId).create(recursive: true);
    await _temporaryDirectory(pluginId).create(recursive: true);
  }

  @override
  Future<Uint8List> readFile(String pluginId, PluginStoragePath path) async {
    await _ensureNoSymbolicLinks(pluginId, path);
    final file = _resolveFile(pluginId, path);
    if (await FileSystemEntity.type(file.path, followLinks: false) !=
        FileSystemEntityType.file) {
      throw StateError('Plugin file does not exist: ${path.virtualPath}');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> writeFile(
    String pluginId,
    PluginStoragePath path,
    Uint8List bytes,
  ) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    await _ensureNoSymbolicLinks(pluginId, path);
    final file = _resolveFile(pluginId, path);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp-$pid');
    await temporary.writeAsBytes(bytes, flush: true);
    await _replaceFile(temporary, file);
  }

  @override
  Future<int> writeFileStream(
    String pluginId,
    PluginStoragePath path,
    Stream<List<int>> stream, {
    bool append = false,
  }) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    await _ensureNoSymbolicLinks(pluginId, path);
    final file = _resolveFile(pluginId, path);
    await file.parent.create(recursive: true);
    var written = 0;
    final sink = file.openWrite(
      mode: append ? FileMode.append : FileMode.write,
    );
    await for (final chunk in stream) {
      sink.add(chunk);
      written += chunk.length;
    }
    await sink.flush();
    await sink.close();
    return written;
  }

  @override
  Future<List<PluginFileStat>> listDirectory(
    String pluginId,
    PluginStoragePath path,
  ) async {
    await _ensureNoSymbolicLinks(pluginId, path);
    final directory = _resolveDirectory(pluginId, path);
    if (!await directory.exists()) return const [];
    final result = <PluginFileStat>[];
    await for (final entity in directory.list(followLinks: false)) {
      final name = _leafName(entity.path);
      if (name.startsWith('.zerobox')) continue;
      final type = await FileSystemEntity.type(entity.path, followLinks: false);
      if (type == FileSystemEntityType.link) continue;
      final childPath = '${path.virtualPath}/$name';
      result.add(
        PluginFileStat(
          path: childPath,
          size: type == FileSystemEntityType.file
              ? await File(entity.path).length()
              : 0,
          isDirectory: type == FileSystemEntityType.directory,
        ),
      );
    }
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }

  @override
  Future<void> createDirectory(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    await _ensureNoSymbolicLinks(pluginId, path);
    await _resolveDirectory(pluginId, path).create(recursive: true);
  }

  @override
  Future<PluginFileStat?> stat(String pluginId, PluginStoragePath path) async {
    await _ensureNoSymbolicLinks(pluginId, path);
    final entityPath = _resolvePath(pluginId, path);
    final type = await FileSystemEntity.type(entityPath, followLinks: false);
    if (type == FileSystemEntityType.notFound ||
        type == FileSystemEntityType.link) {
      return null;
    }
    return PluginFileStat(
      path: path.virtualPath,
      size: type == FileSystemEntityType.file
          ? await File(entityPath).length()
          : 0,
      isDirectory: type == FileSystemEntityType.directory,
    );
  }

  @override
  Future<void> removeFile(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('Cannot remove a storage root');
    }
    await _ensureNoSymbolicLinks(pluginId, path);
    final entityPath = _resolvePath(pluginId, path);
    final type = await FileSystemEntity.type(entityPath, followLinks: false);
    if (type == FileSystemEntityType.file) {
      await File(entityPath).delete();
    } else if (type == FileSystemEntityType.directory) {
      await Directory(entityPath).delete(recursive: true);
    } else if (type == FileSystemEntityType.link) {
      throw StateError('Symbolic links are not allowed in plugin storage');
    }
  }

  @override
  String nativePath(String pluginId, PluginStoragePath path) {
    return _resolvePath(pluginId, path);
  }

  @override
  Future<void> close() async {
    if (await temporaryRoot.exists()) {
      await temporaryRoot.delete(recursive: true);
    }
  }

  Directory _pluginDirectory(String id) {
    _requirePluginId(id);
    return Directory(_join(installedRoot.path, id));
  }

  Directory _packageDirectory(String id) =>
      Directory(_join(_pluginDirectory(id).path, 'package'));

  Directory _dataDirectory(String id) =>
      Directory(_join(_pluginDirectory(id).path, 'data'));

  Directory _metadataDirectory(String id) =>
      Directory(_join(_pluginDirectory(id).path, _metadataDirectoryName));

  File _metadataFile(String id, String name) =>
      File(_join(_metadataDirectory(id).path, name));

  Directory _cacheDirectory(String id) {
    _requirePluginId(id);
    return Directory(_join(cacheRoot.path, id));
  }

  Directory _temporaryDirectory(String id) {
    _requirePluginId(id);
    return Directory(_join(temporaryRoot.path, id));
  }

  File _packageFile(String id, String relativePath) =>
      _fileBelow(_packageDirectory(id), relativePath);

  File _resolveFile(String id, PluginStoragePath path) {
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    return File(_resolvePath(id, path));
  }

  Directory _resolveDirectory(String id, PluginStoragePath path) =>
      Directory(_resolvePath(id, path));

  String _resolvePath(String id, PluginStoragePath path) {
    final root = _rootDirectory(id, path.area);
    return path.relativePath.isEmpty
        ? root.path
        : _fileBelow(root, path.relativePath).path;
  }

  Directory _rootDirectory(String id, PluginStorageArea area) => switch (area) {
    PluginStorageArea.package => _packageDirectory(id),
    PluginStorageArea.data => _dataDirectory(id),
    PluginStorageArea.cache => _cacheDirectory(id),
    PluginStorageArea.temporary => _temporaryDirectory(id),
  };

  Future<void> _ensureNoSymbolicLinks(String id, PluginStoragePath path) async {
    var current = _rootDirectory(id, path.area).path;
    final rootType = await FileSystemEntity.type(current, followLinks: false);
    if (rootType == FileSystemEntityType.link) {
      throw StateError('Symbolic links are not allowed in plugin storage');
    }
    for (final part in path.relativePath.split('/')) {
      if (part.isEmpty) continue;
      current = _join(current, part);
      final type = await FileSystemEntity.type(current, followLinks: false);
      if (type == FileSystemEntityType.link) {
        throw StateError('Symbolic links are not allowed in plugin storage');
      }
      if (type == FileSystemEntityType.notFound) break;
    }
  }

  Future<void> _ensureMetadataSafe(String id) async {
    final pluginType = await FileSystemEntity.type(
      _pluginDirectory(id).path,
      followLinks: false,
    );
    final metadataType = await FileSystemEntity.type(
      _metadataDirectory(id).path,
      followLinks: false,
    );
    if (pluginType == FileSystemEntityType.link ||
        metadataType == FileSystemEntityType.link) {
      throw StateError('Symbolic links are not allowed in plugin storage');
    }
  }

  Future<void> _replaceFile(File temporary, File target) async {
    final backup = File(
      '${target.path}.backup-${DateTime.now().microsecondsSinceEpoch}',
    );
    if (await target.exists()) await target.rename(backup.path);
    try {
      await temporary.rename(target.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (await backup.exists() && !await target.exists()) {
        await backup.rename(target.path);
      }
      rethrow;
    }
  }

  File _fileBelow(Directory root, String relativePath) {
    final parts = relativePath.split('/');
    if (relativePath.isEmpty ||
        parts.any(
          (part) =>
              part.isEmpty ||
              part == '.' ||
              part == '..' ||
              part.contains('\\') ||
              part.startsWith('.zerobox'),
        )) {
      throw FormatException('Unsafe plugin path: $relativePath');
    }
    return File([root.path, ...parts].join(Platform.pathSeparator));
  }

  bool _isPluginId(String id) =>
      RegExp(r'^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*)+$').hasMatch(id) ||
      RegExp(r'^[a-z0-9][a-z0-9-]{0,127}$').hasMatch(id);

  void _requirePluginId(String id) {
    if (!_isPluginId(id)) throw FormatException('Invalid plugin ID: $id');
  }

  String _join(String parent, String child) =>
      '$parent${Platform.pathSeparator}$child';

  String _leafName(String path) =>
      path.split(Platform.pathSeparator).where((part) => part.isNotEmpty).last;
}
