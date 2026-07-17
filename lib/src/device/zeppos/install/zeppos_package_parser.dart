import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

enum ZeppOsPackageType { firmware, app, watchface }

class ZeppOsInstallPackage {
  const ZeppOsInstallPackage({
    required this.type,
    required this.bytes,
    required this.crc32,
    this.appId,
    this.name,
    this.version,
    this.appSideJs,
    this.settingJs,
    this.settingAssets = const {},
  });

  final ZeppOsPackageType type;
  final Uint8List bytes;
  final int crc32;
  final int? appId;
  final String? name;
  final String? version;
  final Uint8List? appSideJs;
  final Uint8List? settingJs;
  final Map<String, Uint8List> settingAssets;

  int get firmwareType => switch (type) {
    ZeppOsPackageType.firmware => 0x00,
    ZeppOsPackageType.app || ZeppOsPackageType.watchface => 0x08,
  };
}

class ZeppOsPackageParser {
  const ZeppOsPackageParser();

  // Firmware bundles legitimately contain several thousand small resources,
  // while ebook-style apps may contain individual assets larger than 8 MiB.
  // ZipDecoder keeps entry bodies lazy, and this parser only materializes the
  // manifests and nested packages it needs.
  static const _maxFiles = 8192;
  static const _maxFileBytes = 64 * 1024 * 1024;
  static const _maxTotalBytes = 512 * 1024 * 1024;

  ZeppOsInstallPackage parse(
    Uint8List input, {
    Set<int> deviceSources = const {},
  }) {
    if (!_isZip(input)) {
      throw const FormatException('Zepp OS install package must be a ZIP');
    }
    return _parseZip(
      input,
      deviceSources: deviceSources,
      depth: 0,
      inheritedSide: const _SideBundle(),
    );
  }

  ZeppOsInstallPackage _parseZip(
    Uint8List bytes, {
    required Set<int> deviceSources,
    required int depth,
    required _SideBundle inheritedSide,
  }) {
    if (depth > 3) {
      throw const FormatException('Nested Zepp OS package is too deep');
    }
    final archive = _decode(bytes);
    final localSide = _sideBundle(archive);
    final side = localSide.isEmpty ? inheritedSide : localSide;
    if (_file(archive, const [
          'META/firmware.bin',
          'META/firmware_sign.bin',
          'firmware.bin',
        ]) !=
        null) {
      return ZeppOsInstallPackage(
        type: ZeppOsPackageType.firmware,
        bytes: bytes,
        crc32: _crc32(bytes),
      );
    }

    final manifestBytes = _file(archive, const ['manifest.json']);
    if (manifestBytes != null) {
      final zpks = _json(manifestBytes, 'manifest.json')['zpks'];
      if (zpks is! List) {
        throw const FormatException('ZAB manifest has no zpks');
      }
      final candidates = <Uint8List>[];
      for (final raw in zpks) {
        if (raw is! Map) continue;
        final entry = raw.cast<String, Object?>();
        final platforms = entry['platforms'];
        final compatible =
            deviceSources.isEmpty ||
            platforms is! List ||
            platforms.any(
              (platform) =>
                  platform is Map &&
                  deviceSources.contains(
                    (platform['deviceSource'] as num?)?.toInt(),
                  ),
            );
        if (!compatible) continue;
        final name = _safeRelativePath(entry['name']);
        final candidate = name == null ? null : _file(archive, [name]);
        if (candidate != null && _isZip(candidate)) candidates.add(candidate);
      }
      if (candidates.isEmpty) {
        throw const FormatException(
          'ZAB has no package compatible with this device',
        );
      }
      if (deviceSources.isEmpty && candidates.length > 1) {
        throw const FormatException(
          'ZAB contains multiple device packages but deviceSource is unknown',
        );
      }
      return _parseZip(
        candidates.first,
        deviceSources: deviceSources,
        depth: depth + 1,
        inheritedSide: side,
      );
    }

    final deviceZip = _file(archive, const ['device.zip']);
    if (deviceZip != null && _isZip(deviceZip)) {
      return _parseZip(
        deviceZip,
        deviceSources: deviceSources,
        depth: depth + 1,
        inheritedSide: side,
      );
    }

    final appJsonBytes = _file(archive, const ['app.json']);
    if (appJsonBytes != null) {
      final root = _json(appJsonBytes, 'app.json');
      final app = (root['app'] as Map?)?.cast<String, Object?>();
      if (app == null) {
        throw const FormatException('app.json has no app object');
      }
      final type = switch (app['appType']?.toString()) {
        'app' => ZeppOsPackageType.app,
        'watchface' => ZeppOsPackageType.watchface,
        final value => throw FormatException(
          'Unsupported Zepp OS appType: $value',
        ),
      };
      final appId = _appId(app['appId']);
      if (appId == null) {
        throw const FormatException(
          'Zepp OS app package has a missing or invalid appId',
        );
      }
      return ZeppOsInstallPackage(
        type: type,
        bytes: bytes,
        crc32: _crc32(bytes),
        appId: appId,
        name: app['appName']?.toString(),
        version: (app['version'] as Map?)?['name']?.toString(),
        appSideJs: side.appSideJs,
        settingJs: side.settingJs,
        settingAssets: side.assets,
      );
    }
    throw const FormatException('Not a recognized Zepp OS package');
  }

  static Archive _decode(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    var files = 0;
    var total = 0;
    for (final entry in archive) {
      if (!entry.isFile) continue;
      files++;
      if (files > _maxFiles) {
        throw const FormatException('ZIP has too many files');
      }
      final size = entry.size;
      if (size > _maxFileBytes) {
        throw const FormatException('ZIP file is too large');
      }
      total += size;
      if (total > _maxTotalBytes) {
        throw const FormatException('ZIP is too large');
      }
      if (_safeRelativePath(entry.name) == null) {
        throw FormatException('Unsafe ZIP path: ${entry.name}');
      }
    }
    return archive;
  }

  static _SideBundle _sideBundle(Archive archive) {
    final appSideZip = _file(archive, const ['app-side.zip', 'appSide.zip']);
    if (appSideZip != null && _isZip(appSideZip)) {
      final sideArchive = _decode(appSideZip);
      final assets = <String, Uint8List>{};
      for (final entry in sideArchive) {
        if (!entry.isFile) continue;
        final path = _safeRelativePath(entry.name)!;
        final basename = path.split('/').last.toLowerCase();
        if (basename == 'app.json' ||
            basename == 'app-side.js' ||
            basename == 'setting.js') {
          continue;
        }
        assets[path] = Uint8List.fromList(entry.content as List<int>);
      }
      return _SideBundle(
        appSideJs: _basenameFile(sideArchive, 'app-side.js'),
        settingJs: _basenameFile(sideArchive, 'setting.js'),
        assets: Map.unmodifiable(assets),
      );
    }
    return _SideBundle(
      appSideJs: _basenameFile(archive, 'app-side.js'),
      settingJs: _basenameFile(archive, 'setting.js'),
    );
  }

  static Map<String, Object?> _json(Uint8List bytes, String name) {
    try {
      return (jsonDecode(utf8.decode(bytes).replaceFirst('\uFEFF', '')) as Map)
          .cast<String, Object?>();
    } catch (error) {
      throw FormatException('Invalid $name: $error');
    }
  }

  static int? _appId(Object? value) {
    if (value is num) {
      final id = value.toInt();
      return id >= 0 && id <= 0xffffffff ? id : null;
    }
    if (value is! String) return null;
    final normalized = value.trim().toLowerCase();
    final id = int.tryParse(
      normalized.startsWith('0x') ? normalized.substring(2) : normalized,
      radix: normalized.startsWith('0x') ? 16 : 10,
    );
    return id != null && id >= 0 && id <= 0xffffffff ? id : null;
  }

  static Uint8List? _file(Archive archive, List<String> names) {
    final targets = names.map((name) => name.replaceAll('\\', '/')).toSet();
    for (final file in archive) {
      if (!file.isFile || !targets.contains(file.name.replaceAll('\\', '/'))) {
        continue;
      }
      return Uint8List.fromList(file.content as List<int>);
    }
    return null;
  }

  static Uint8List? _basenameFile(Archive archive, String basename) {
    final candidates =
        archive.where((entry) {
          if (!entry.isFile) return false;
          final path = _safeRelativePath(entry.name);
          return path != null && path.split('/').last.toLowerCase() == basename;
        }).toList()..sort((a, b) {
          final ap = _safeRelativePath(a.name)!;
          final bp = _safeRelativePath(b.name)!;
          final depth = ap.split('/').length.compareTo(bp.split('/').length);
          return depth != 0 ? depth : ap.compareTo(bp);
        });
    return candidates.isEmpty
        ? null
        : Uint8List.fromList(candidates.first.content as List<int>);
  }

  static String? _safeRelativePath(Object? path) {
    if (path == null) return null;
    final normalized = path.toString().trim().replaceAll('\\', '/');
    if (normalized.isEmpty ||
        normalized.startsWith('/') ||
        RegExp(r'^[a-zA-Z]:').hasMatch(normalized)) {
      return null;
    }
    final parts = normalized.split('/');
    if (parts.any((part) => part == '..')) return null;
    return parts.where((part) => part.isNotEmpty && part != '.').join('/');
  }

  static bool _isZip(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 3 &&
      bytes[3] == 4;
}

class _SideBundle {
  const _SideBundle({this.appSideJs, this.settingJs, this.assets = const {}});

  final Uint8List? appSideJs;
  final Uint8List? settingJs;
  final Map<String, Uint8List> assets;
  bool get isEmpty => appSideJs == null && settingJs == null && assets.isEmpty;
}

int _crc32(List<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb88320 : crc >> 1;
    }
  }
  return (crc ^ 0xffffffff) & 0xffffffff;
}
