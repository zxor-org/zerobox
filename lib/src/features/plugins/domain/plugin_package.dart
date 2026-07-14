import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.apiLevel,
    required this.entry,
    required this.permissions,
    this.website,
    this.iconPath,
  });

  final String id;
  final String name;
  final String version;
  final String author;
  final String description;
  final int apiLevel;
  final String entry;
  final List<String> permissions;
  final String? website;
  final String? iconPath;

  Map<String, Object?> toJson() => {
    'id': id,
    'name': name,
    'version': version,
    'author': author,
    'description': description,
    'apiLevel': apiLevel,
    'entry': entry,
    'permissions': permissions,
    if (website != null) 'website': website,
    if (iconPath != null) 'iconPath': iconPath,
  };
}

class InstalledPlugin {
  const InstalledPlugin({
    required this.manifest,
    required this.source,
    required this.config,
    this.iconBase64,
  });

  final PluginManifest manifest;
  final String source;
  final Map<String, Object?> config;
  final String? iconBase64;

  InstalledPlugin copyWith({Map<String, Object?>? config}) => InstalledPlugin(
    manifest: manifest,
    source: source,
    config: config ?? this.config,
    iconBase64: iconBase64,
  );

  Map<String, Object?> summaryJson({bool includeIcon = true}) => {
    ...manifest.toJson(),
    if (includeIcon && iconBase64 != null) 'icon': iconBase64,
  };
}

class PluginPackage {
  const PluginPackage({required this.manifest, required this.files});

  final PluginManifest manifest;
  final Map<String, Uint8List> files;

  InstalledPlugin installed({Map<String, Object?> config = const {}}) {
    final sourceBytes = files[manifest.entry];
    if (sourceBytes == null) {
      throw FormatException('ABP entry is missing: ${manifest.entry}');
    }
    final iconBytes = manifest.iconPath == null
        ? null
        : files[manifest.iconPath];
    return InstalledPlugin(
      manifest: manifest,
      source: utf8.decode(sourceBytes),
      config: config,
      iconBase64: iconBytes == null ? null : base64Encode(iconBytes),
    );
  }
}

class AbPluginPackageReader {
  const AbPluginPackageReader();

  static const _maxPackageBytes = 32 * 1024 * 1024;
  static const _maxEntryBytes = 8 * 1024 * 1024;
  static const _maxExpandedBytes = 64 * 1024 * 1024;
  static const _maxEntries = 4096;

  PluginPackage read(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > _maxPackageBytes) {
      throw const FormatException('Invalid ABP package size');
    }

    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final entries = <String, Uint8List>{};
    var expandedBytes = 0;
    for (final file in archive) {
      if (!file.isFile) continue;
      if (entries.length >= _maxEntries) {
        throw const FormatException('ABP contains too many files');
      }
      final name = _normalizePath(file.name);
      if (file.size > _maxEntryBytes) {
        throw FormatException('ABP entry is too large: $name');
      }
      expandedBytes += file.size;
      if (expandedBytes > _maxExpandedBytes) {
        throw const FormatException('ABP expanded size is too large');
      }
      if (entries.containsKey(name)) {
        throw FormatException('Duplicate ABP entry: $name');
      }
      entries[name] = Uint8List.fromList(file.content as List<int>);
    }

    final manifestBytes = entries['manifest.json'];
    if (manifestBytes == null) {
      throw const FormatException('ABP manifest.json is missing');
    }
    final manifest = readManifest(manifestBytes);
    if (!entries.containsKey(manifest.entry)) {
      throw FormatException('ABP entry is missing: ${manifest.entry}');
    }
    if (manifest.iconPath != null && !entries.containsKey(manifest.iconPath)) {
      throw FormatException('ABP icon is missing: ${manifest.iconPath}');
    }
    return PluginPackage(manifest: manifest, files: Map.unmodifiable(entries));
  }

  PluginManifest readManifest(Uint8List manifestBytes) {
    final raw = jsonDecode(utf8.decode(manifestBytes));
    if (raw is! Map) throw const FormatException('Invalid ABP manifest');
    final json = raw.cast<String, Object?>();
    final apiLevel = (json['api_level'] as num?)?.toInt() ?? 0;
    if (apiLevel != 1) {
      throw FormatException('Unsupported ABP API level: $apiLevel');
    }
    final name = _requiredString(json, 'name');
    final entry = _normalizePath(
      json['entry']?.toString().trim().isNotEmpty == true
          ? json['entry']!.toString()
          : 'main.js',
    );
    final iconPath = json['icon']?.toString().trim();
    final normalizedIcon = iconPath == null || iconPath.isEmpty
        ? null
        : _normalizePath(iconPath);
    final idHash = sha256
        .convert(utf8.encode(name))
        .toString()
        .substring(0, 12);
    final idName = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return PluginManifest(
      id: '${idName.isEmpty ? 'plugin' : idName}-$idHash',
      name: name,
      version: _requiredString(json, 'version'),
      author: json['author']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      apiLevel: apiLevel,
      entry: entry,
      permissions:
          (json['permissions'] as List?)
              ?.map((value) => value.toString())
              .toList(growable: false) ??
          const [],
      website: json['website']?.toString(),
      iconPath: normalizedIcon,
    );
  }

  String _normalizePath(String value) {
    final path = value.replaceAll('\\', '/');
    final parts = path.split('/');
    if (path.startsWith('/') ||
        path.contains('\x00') ||
        parts.any(
          (part) => part == '..' || part.isEmpty || part.contains(':'),
        )) {
      throw FormatException('Unsafe ABP path: $value');
    }
    return parts.where((part) => part != '.').join('/');
  }

  String _requiredString(Map<String, Object?> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) throw FormatException('ABP $key is missing');
    return value;
  }
}
