import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';

import 'plugin_storage.dart';

Future<PluginStorage> createPluginStorage() async {
  final storage = _WebPluginStorage();
  await storage.initialize();
  return storage;
}

class _WebPluginStorage implements PluginStorage {
  static const _databaseName = 'zerobox.plugins';
  static const _databaseVersion = 1;
  static const _filesStore = 'files';
  static const _separator = '\u0001';
  static const _configFile = '.zerobox-config.json';
  static const _permissionsFile = '.zerobox-permissions.json';

  web.IDBDatabase? _database;

  Future<void> initialize() async {
    final request = web.window.indexedDB.open(_databaseName, _databaseVersion);
    request.onupgradeneeded = ((web.Event _) {
      final database = request.result as web.IDBDatabase;
      if (!database.objectStoreNames.contains(_filesStore)) {
        database.createObjectStore(_filesStore);
      }
    }).toJS;
    _database = await _request(request) as web.IDBDatabase;
  }

  @override
  Future<List<InstalledPlugin>> loadInstalled() async {
    final entries = await _allEntries();
    final manifestSuffix =
        '$_separator${PluginStorageArea.package.name}'
        '${_separator}manifest.json';
    final plugins = <InstalledPlugin>[];
    for (final entry in entries.entries.where(
      (entry) => entry.key.endsWith(manifestSuffix),
    )) {
      try {
        final id = entry.key.substring(
          0,
          entry.key.length - manifestSuffix.length,
        );
        final manifest = const PluginPackageReader().readManifest(entry.value);
        if (manifest.id != id) {
          throw const FormatException(
            'Plugin storage ID does not match manifest',
          );
        }
        final source =
            entries[_fileKey(id, PluginStorageArea.package, manifest.entry)];
        if (source == null) {
          throw FormatException('Plugin entry is missing: ${manifest.entry}');
        }
        final icon = manifest.iconPath == null
            ? null
            : entries[_fileKey(
                id,
                PluginStorageArea.package,
                manifest.iconPath!,
              )];
        final configBytes =
            entries[_fileKey(id, PluginStorageArea.data, _configFile)];
        plugins.add(
          InstalledPlugin(
            manifest: manifest,
            entryBytes: source,
            config: _decodeConfig(configBytes),
            iconBase64: icon == null ? null : base64Encode(icon),
          ),
        );
      } catch (_) {
        // A damaged plugin is isolated from the rest of the registry
      }
    }
    return plugins;
  }

  @override
  Future<InstalledPlugin> install(
    PluginPackage package, {
    required Map<String, Object?> config,
  }) async {
    final id = package.manifest.id;
    final packagePrefix = _areaPrefix(id, PluginStorageArea.package);
    final existingKeys = await _allKeys();
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    final files = transaction.objectStore(_filesStore);
    for (final key in existingKeys.where(
      (key) => key.startsWith(packagePrefix),
    )) {
      files.delete(key.toJS);
    }
    for (final entry in package.files.entries) {
      files.put(
        entry.value.toJS,
        _fileKey(id, PluginStorageArea.package, entry.key).toJS,
      );
    }
    files.put(
      Uint8List.fromList(utf8.encode(jsonEncode(config))).toJS,
      _fileKey(id, PluginStorageArea.data, _configFile).toJS,
    );
    await _transaction(transaction);
    return package.installed(config: config);
  }

  @override
  Future<void> writeConfig(String pluginId, Map<String, Object?> config) async {
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    final store = transaction.objectStore(_filesStore);
    store.put(
      Uint8List.fromList(utf8.encode(jsonEncode(config))).toJS,
      _fileKey(pluginId, PluginStorageArea.data, _configFile).toJS,
    );
    await _transaction(transaction);
  }

  @override
  Future<Set<String>> readPermissionGrants(String pluginId) async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction
          .objectStore(_filesStore)
          .get(
            _fileKey(pluginId, PluginStorageArea.data, _permissionsFile).toJS,
          ),
    );
    if (value == null) return <String>{};
    final raw = value.dartify();
    final bytes = raw is Uint8List
        ? raw
        : Uint8List.fromList((raw as List).cast<int>());
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! List) {
      throw const FormatException('Invalid plugin permission grants');
    }
    return decoded.map((item) => item.toString()).toSet();
  }

  @override
  Future<void> writePermissionGrants(
    String pluginId,
    Set<String> grants,
  ) async {
    final bytes = Uint8List.fromList(
      utf8.encode(jsonEncode(grants.toList()..sort())),
    );
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    transaction
        .objectStore(_filesStore)
        .put(
          bytes.toJS,
          _fileKey(pluginId, PluginStorageArea.data, _permissionsFile).toJS,
        );
    await _transaction(transaction);
  }

  @override
  Future<void> removePlugin(String pluginId) async {
    final keys = await _allKeys();
    final prefix = '$pluginId$_separator';
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    final files = transaction.objectStore(_filesStore);
    for (final key in keys.where((key) => key.startsWith(prefix))) {
      files.delete(key.toJS);
    }
    await _transaction(transaction);
  }

  @override
  Future<void> clearPluginData(String pluginId) async {
    final keys = await _allKeys();
    final packagePrefix = _areaPrefix(pluginId, PluginStorageArea.package);
    final pluginPrefix = '$pluginId$_separator';
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    final files = transaction.objectStore(_filesStore);
    for (final key in keys.where(
      (key) => key.startsWith(pluginPrefix) && !key.startsWith(packagePrefix),
    )) {
      files.delete(key.toJS);
    }
    await _transaction(transaction);
  }

  @override
  Future<Uint8List> readFile(String pluginId, PluginStoragePath path) async {
    if (path.relativePath.isEmpty) {
      throw const FormatException('A file path is required');
    }
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction
          .objectStore(_filesStore)
          .get(_fileKey(pluginId, path.area, path.relativePath).toJS),
    );
    if (value == null) {
      throw StateError('Plugin file does not exist: ${path.virtualPath}');
    }
    final dartValue = value.dartify();
    if (dartValue is Uint8List) return dartValue;
    if (dartValue is List) {
      return Uint8List.fromList(
        dartValue.whereType<num>().map((v) => v.toInt()).toList(),
      );
    }
    throw StateError('Invalid plugin file: ${path.virtualPath}');
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
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    transaction
        .objectStore(_filesStore)
        .put(bytes.toJS, _fileKey(pluginId, path.area, path.relativePath).toJS);
    await _transaction(transaction);
  }

  @override
  Future<int> writeFileStream(
    String pluginId,
    PluginStoragePath path,
    Stream<List<int>> stream, {
    bool append = false,
  }) async {
    final builder = BytesBuilder(copy: false);
    if (append) {
      final existing = await stat(pluginId, path);
      if (existing != null && !existing.isDirectory) {
        builder.add(await readFile(pluginId, path));
      }
    }
    var written = 0;
    await for (final chunk in stream) {
      builder.add(chunk);
      written += chunk.length;
    }
    await writeFile(pluginId, path, builder.takeBytes());
    return written;
  }

  @override
  Future<List<PluginFileStat>> listDirectory(
    String pluginId,
    PluginStoragePath path,
  ) async {
    final entries = await _allEntries();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final directoryPrefix = path.relativePath.isEmpty ? key : '$key/';
    final children = <String, PluginFileStat>{};
    for (final entry in entries.entries) {
      if (!entry.key.startsWith(directoryPrefix)) continue;
      final remainder = entry.key.substring(directoryPrefix.length);
      if (remainder.isEmpty) continue;
      final slash = remainder.indexOf('/');
      final name = slash < 0 ? remainder : remainder.substring(0, slash);
      if (name.startsWith('.zerobox')) continue;
      final virtual = '${path.virtualPath}/$name';
      children[name] = PluginFileStat(
        path: virtual,
        size: slash < 0 ? entry.value.length : 0,
        isDirectory: slash >= 0,
      );
    }
    final result = children.values.toList();
    result.sort((a, b) => a.path.compareTo(b.path));
    return result;
  }

  @override
  Future<void> createDirectory(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) return;
    final marker = '${path.relativePath}/.zerobox-directory';
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    transaction
        .objectStore(_filesStore)
        .put(Uint8List(0).toJS, _fileKey(pluginId, path.area, marker).toJS);
    await _transaction(transaction);
  }

  @override
  Future<PluginFileStat?> stat(String pluginId, PluginStoragePath path) async {
    if (path.relativePath.isEmpty) {
      return PluginFileStat(path: path.virtualPath, size: 0, isDirectory: true);
    }
    final entries = await _allEntries();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final bytes = entries[key];
    if (bytes != null) {
      return PluginFileStat(
        path: path.virtualPath,
        size: bytes.length,
        isDirectory: false,
      );
    }
    if (entries.keys.any((candidate) => candidate.startsWith('$key/'))) {
      return PluginFileStat(path: path.virtualPath, size: 0, isDirectory: true);
    }
    return null;
  }

  @override
  Future<void> removeFile(String pluginId, PluginStoragePath path) async {
    if (path.area == PluginStorageArea.package) {
      throw UnsupportedError('/plugin is read-only');
    }
    if (path.relativePath.isEmpty) {
      throw const FormatException('Cannot remove a storage root');
    }
    final keys = await _allKeys();
    final key = _fileKey(pluginId, path.area, path.relativePath);
    final transaction = _db.transaction(_filesStore.toJS, 'readwrite');
    final store = transaction.objectStore(_filesStore);
    for (final candidate in keys.where(
      (candidate) => candidate == key || candidate.startsWith('$key/'),
    )) {
      store.delete(candidate.toJS);
    }
    await _transaction(transaction);
  }

  @override
  String? nativePath(String pluginId, PluginStoragePath path) => null;

  Future<List<String>> _allKeys() async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final value = await _request(
      transaction.objectStore(_filesStore).getAllKeys(),
    );
    return (value?.dartify() as List? ?? const [])
        .map((key) => key.toString())
        .toList(growable: false);
  }

  Future<Map<String, Uint8List>> _allEntries() async {
    final transaction = _db.transaction(_filesStore.toJS, 'readonly');
    final store = transaction.objectStore(_filesStore);
    final keysRequest = _request(store.getAllKeys());
    final valuesRequest = _request(store.getAll());
    final keysValue = await keysRequest;
    final valuesValue = await valuesRequest;
    final keys = keysValue?.dartify() as List? ?? const [];
    final values = valuesValue?.dartify() as List? ?? const [];
    final result = <String, Uint8List>{};
    for (var index = 0; index < keys.length && index < values.length; index++) {
      final value = values[index];
      if (value is Uint8List) result[keys[index].toString()] = value;
    }
    return result;
  }

  String _fileKey(String id, PluginStorageArea area, String relativePath) =>
      '$id$_separator${area.name}$_separator$relativePath';

  String _areaPrefix(String id, PluginStorageArea area) =>
      '$id$_separator${area.name}$_separator';

  Map<String, Object?> _decodeConfig(Uint8List? bytes) {
    if (bytes == null) return const {};
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map) throw const FormatException('Invalid plugin config');
    return decoded.cast<String, Object?>();
  }

  Future<JSAny?> _request(web.IDBRequest request) {
    final completer = Completer<JSAny?>();
    request.onsuccess = ((web.Event _) {
      if (!completer.isCompleted) completer.complete(request.result);
    }).toJS;
    request.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(request.error?.message ?? 'IndexedDB request failed'),
        );
      }
    }).toJS;
    return completer.future;
  }

  Future<void> _transaction(web.IDBTransaction transaction) {
    final completer = Completer<void>();
    transaction.oncomplete = ((web.Event _) {
      if (!completer.isCompleted) completer.complete();
    }).toJS;
    transaction.onabort = transaction.onerror = ((web.Event _) {
      if (!completer.isCompleted) {
        completer.completeError(
          StateError(
            transaction.error?.message ?? 'IndexedDB transaction failed',
          ),
        );
      }
    }).toJS;
    return completer.future;
  }

  web.IDBDatabase get _db {
    final database = _database;
    if (database == null) throw StateError('Plugin storage is closed');
    return database;
  }

  @override
  Future<void> close() async {
    _database?.close();
    _database = null;
  }
}
