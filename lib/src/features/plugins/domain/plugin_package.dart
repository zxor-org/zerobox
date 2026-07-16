import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';

enum PluginRuntimeType { legacy, js, wasm, hybrid }

extension PluginRuntimeTypeJson on PluginRuntimeType {
  String? get manifestValue => switch (this) {
    PluginRuntimeType.legacy => null,
    PluginRuntimeType.js => 'js',
    PluginRuntimeType.wasm => 'wasm',
    PluginRuntimeType.hybrid => 'hybrid',
  };
}

class PluginManifest {
  const PluginManifest({
    required this.id,
    required this.name,
    required this.version,
    required this.author,
    required this.description,
    required this.apiLevel,
    required this.runtime,
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
  final PluginRuntimeType runtime;
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
    if (runtime.manifestValue != null) 'runtime': runtime.manifestValue,
    'legacy': runtime == PluginRuntimeType.legacy,
    'entry': entry,
    'permissions': permissions,
    if (website != null) 'website': website,
    if (iconPath != null) 'iconPath': iconPath,
  };
}

class InstalledPlugin {
  const InstalledPlugin({
    required this.manifest,
    required this.entryBytes,
    required this.config,
    this.iconBase64,
  });

  final PluginManifest manifest;
  final Uint8List entryBytes;
  String get source => utf8.decode(entryBytes);
  final Map<String, Object?> config;
  final String? iconBase64;

  InstalledPlugin copyWith({Map<String, Object?>? config}) => InstalledPlugin(
    manifest: manifest,
    entryBytes: entryBytes,
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
      entryBytes: Uint8List.fromList(sourceBytes),
      config: config,
      iconBase64: iconBytes == null ? null : base64Encode(iconBytes),
    );
  }
}

class PluginPackageReader {
  const PluginPackageReader();

  static const _maxPackageBytes = 32 * 1024 * 1024;
  static const _maxEntryBytes = 8 * 1024 * 1024;
  static const _maxExpandedBytes = 64 * 1024 * 1024;
  static const _maxEntries = 4096;

  PluginPackage read(Uint8List bytes, {String? fileName}) {
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
    final extension = fileName?.trim().toLowerCase().split('.').lastOrNull;
    if (extension == 'zbp' && manifest.runtime == PluginRuntimeType.legacy) {
      throw const FormatException('ZBP manifest must declare runtime');
    }
    if (extension == 'abp' && manifest.runtime != PluginRuntimeType.legacy) {
      throw const FormatException(
        'ZeroBox plugins must use the .zbp extension',
      );
    }
    if (!entries.containsKey(manifest.entry)) {
      throw FormatException('ABP entry is missing: ${manifest.entry}');
    }
    if (manifest.runtime == PluginRuntimeType.wasm) {
      final wasm = entries[manifest.entry]!;
      if (wasm.length < 4 ||
          wasm[0] != 0x00 ||
          wasm[1] != 0x61 ||
          wasm[2] != 0x73 ||
          wasm[3] != 0x6d) {
        throw const FormatException(
          'WASM plugin entry has an invalid WebAssembly header',
        );
      }
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
      throw FormatException('Unsupported plugin API level: $apiLevel');
    }
    final runtime = _runtime(json['runtime']);
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
    final id = runtime == PluginRuntimeType.legacy
        ? _legacyId(name)
        : _requiredPluginId(json);
    final suffix = entry.split('.').last.toLowerCase();
    if (runtime == PluginRuntimeType.wasm && suffix != 'wasm') {
      throw const FormatException('WASM plugin entry must be a .wasm file');
    }
    if ((runtime == PluginRuntimeType.js ||
            runtime == PluginRuntimeType.hybrid) &&
        !const {'js', 'mjs', 'cjs'}.contains(suffix)) {
      throw const FormatException(
        'JS and hybrid plugin entries must be JavaScript',
      );
    }
    final permissions =
        (json['permissions'] as List?)
            ?.map((value) => value.toString())
            .toSet()
            .toList(growable: false) ??
        const <String>[];
    if (runtime != PluginRuntimeType.legacy) {
      const supported = {
        'ui',
        'file',
        'network',
        'interconnect',
        'provider',
        'device',
        'protocol',
      };
      final unknown = permissions.where((value) => !supported.contains(value));
      if (unknown.isNotEmpty) {
        throw FormatException(
          'Unsupported plugin permissions: ${unknown.join(', ')}',
        );
      }
    }

    return PluginManifest(
      id: id,
      name: name,
      version: _requiredString(json, 'version'),
      author: json['author']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      apiLevel: apiLevel,
      runtime: runtime,
      entry: entry,
      permissions: permissions,
      website: json['website']?.toString(),
      iconPath: normalizedIcon,
    );
  }

  PluginRuntimeType _runtime(Object? value) => switch (value) {
    null => PluginRuntimeType.legacy,
    'js' => PluginRuntimeType.js,
    'wasm' => PluginRuntimeType.wasm,
    'hybrid' => PluginRuntimeType.hybrid,
    _ => throw FormatException('Unsupported plugin runtime: $value'),
  };

  String _requiredPluginId(Map<String, Object?> json) {
    final id = _requiredString(json, 'id');
    if (!RegExp(r'^[a-z][a-z0-9]*(?:[.-][a-z0-9][a-z0-9-]*)+$').hasMatch(id)) {
      throw FormatException('Invalid plugin ID: $id');
    }
    return id;
  }

  String _legacyId(String name) {
    final hash = sha256.convert(utf8.encode(name)).toString().substring(0, 12);
    final slug = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return '${slug.isEmpty ? 'plugin' : slug}-$hash';
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

/// Reader retained for the AstroBox plugin store and legacy callers.
class AbPluginPackageReader {
  const AbPluginPackageReader();

  PluginPackage read(Uint8List bytes) {
    final package = const PluginPackageReader().read(
      bytes,
      fileName: 'legacy.abp',
    );
    if (package.manifest.runtime != PluginRuntimeType.legacy) {
      throw const FormatException('Not an AstroBox legacy plugin');
    }
    return package;
  }

  PluginManifest readManifest(Uint8List bytes) {
    final manifest = const PluginPackageReader().readManifest(bytes);
    if (manifest.runtime != PluginRuntimeType.legacy) {
      throw const FormatException('Not an AstroBox legacy manifest');
    }
    return manifest;
  }
}
