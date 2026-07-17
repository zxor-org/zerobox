import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';

enum LocalDeviceInstallType { app, watchface, firmware }

enum ResourceInstallMode { automatic, forceType, forcePlatform }

enum ResourcePlatform { vela, zeppOs }

enum ResourcePackageKind {
  rawPayload,
  velaWatchfaceProject,
  velaOta,
  zeppOsPackage,
  zeppOsBundle,
}

class ResourcePayloadAnalysis {
  const ResourcePayloadAnalysis({
    required this.type,
    required this.platform,
    required this.packageKind,
    required this.payload,
    required this.evidence,
    this.name,
    this.version,
    this.identifier,
    this.target,
  });

  final LocalDeviceInstallType type;
  final ResourcePlatform platform;
  final ResourcePackageKind packageKind;
  final Uint8List payload;
  final List<String> evidence;
  final String? name;
  final String? version;
  final String? identifier;
  final String? target;

  bool get wasNormalized =>
      packageKind == ResourcePackageKind.velaWatchfaceProject;
}

class ResourcePayloadAnalyzer {
  ResourcePayloadAnalyzer();

  static final _log = getLogger('ResourcePayloadAnalyzer');
  static const _maxExtractedWatchfaceBytes = 64 * 1024 * 1024;

  ResourcePayloadAnalysis? analyze({
    required String fileName,
    required Uint8List bytes,
    LocalDeviceInstallType? hint,
    String source = 'local',
  }) {
    ResourcePayloadAnalysis? result;
    Object? failure;
    try {
      result = _looksLikeZip(bytes)
          ? _analyzeZip(fileName, bytes)
          : _analyzeRaw(bytes);
    } catch (error) {
      failure = error;
    }

    if (result == null) {
      _log.warning(
        'resource analysis rejected source=$source file="$fileName" '
        'bytes=${bytes.length} hint=${hint?.name ?? 'none'}'
        '${failure == null ? '' : ' error=$failure'}',
      );
      return null;
    }

    final mismatch = hint != null && hint != result.type;
    _log.info(
      'resource analysis source=$source file="$fileName" '
      'bytes=${bytes.length} type=${result.type.name} '
      'platform=${result.platform.name} package=${result.packageKind.name} '
      'payloadBytes=${result.payload.length} hint=${hint?.name ?? 'none'} '
      'hintMismatch=$mismatch normalized=${result.wasNormalized} '
      'id=${result.identifier ?? 'none'} target=${result.target ?? 'none'} '
      'evidence="${result.evidence.join('; ')}"',
    );
    return result;
  }

  ResourcePayloadAnalysis? _analyzeZip(String fileName, Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final names = <String>{
      for (final entry in archive)
        if (entry.isFile) entry.name.replaceAll('\\', '/'),
    };

    if (names.contains('description.xml') &&
        names.contains('capability.json') &&
        names.contains('resource.bin')) {
      return _velaWatchfaceProject(archive);
    }

    try {
      final package = const ZeppOsPackageParser().parse(bytes);
      return ResourcePayloadAnalysis(
        type: switch (package.type) {
          ZeppOsPackageType.app => LocalDeviceInstallType.app,
          ZeppOsPackageType.watchface => LocalDeviceInstallType.watchface,
          ZeppOsPackageType.firmware => LocalDeviceInstallType.firmware,
        },
        platform: ResourcePlatform.zeppOs,
        packageKind:
            names.contains('device.zip') || names.contains('manifest.json')
            ? ResourcePackageKind.zeppOsBundle
            : ResourcePackageKind.zeppOsPackage,
        payload: bytes,
        name: package.name,
        version: package.version,
        identifier: package.appId?.toString(),
        evidence: [
          if (package.type == ZeppOsPackageType.firmware)
            'Zepp OS firmware entry'
          else
            'Zepp OS app.json appType=${package.type.name}',
          if (names.contains('device.zip')) 'device.zip bundle',
          if (names.contains('app-side.zip')) 'app-side.zip bundle',
        ],
      );
    } catch (_) {
      // Continue with Vela and generic quick-app containers.
    }

    if (_isVelaOta(names)) {
      final otaJson = _jsonFile(archive, 'ota.json');
      return ResourcePayloadAnalysis(
        type: LocalDeviceInstallType.firmware,
        platform: ResourcePlatform.vela,
        packageKind: ResourcePackageKind.velaOta,
        payload: bytes,
        version:
            otaJson?['sw_version']?.toString() ??
            _propertyValue(_textFile(archive, 'version'), 'res.version'),
        target: otaJson?['magic_string']?.toString(),
        evidence: [
          if (names.contains('ota.json')) 'ota.json sections',
          if (names.contains('ota.sh')) 'ota.sh partition installer',
          if (names.contains('META-INF/MANIFEST.MF')) 'signed OTA manifest',
          if (names.contains('vela_ota.bin')) 'vela_ota.bin',
        ],
      );
    }

    final manifest = _jsonFile(archive, 'manifest.json');
    final packageName = _firstString(manifest, const [
      'package',
      'packageName',
      'package_name',
    ]);
    if (packageName != null) {
      return ResourcePayloadAnalysis(
        type: LocalDeviceInstallType.app,
        platform: ResourcePlatform.vela,
        packageKind: ResourcePackageKind.rawPayload,
        payload: bytes,
        identifier: packageName,
        name: _firstString(manifest, const ['name', 'appName']),
        version: _firstString(manifest, const ['versionName', 'version']),
        evidence: ['quick-app manifest package=$packageName'],
      );
    }
    return null;
  }

  ResourcePayloadAnalysis _velaWatchfaceProject(Archive archive) {
    final resource = _fileBytes(archive, 'resource.bin');
    if (resource == null || resource.length > _maxExtractedWatchfaceBytes) {
      throw const FormatException('Invalid MWZ resource.bin');
    }
    if (!_isVelaWatchface(resource)) {
      throw const FormatException('MWZ resource.bin is not a Vela watchface');
    }
    final description = _textFile(archive, 'description.xml') ?? '';
    final name = _xmlValue(description, 'name');
    final version = _xmlValue(description, 'version');
    final target = _xmlValue(description, 'deviceType');
    final identifier = _watchfaceId(resource);
    return ResourcePayloadAnalysis(
      type: LocalDeviceInstallType.watchface,
      platform: ResourcePlatform.vela,
      packageKind: ResourcePackageKind.velaWatchfaceProject,
      payload: resource,
      name: name,
      version: version,
      identifier: _validWatchfaceId(identifier) ? identifier : null,
      target: target,
      evidence: [
        'MWZ authoring project',
        'embedded resource.bin magic=5aa53412',
        if (target != null) 'description.xml deviceType=$target',
      ],
    );
  }

  ResourcePayloadAnalysis? _analyzeRaw(Uint8List bytes) {
    if (_isVelaWatchface(bytes)) {
      final identifier = _watchfaceId(bytes);
      return ResourcePayloadAnalysis(
        type: LocalDeviceInstallType.watchface,
        platform: ResourcePlatform.vela,
        packageKind: ResourcePackageKind.rawPayload,
        payload: bytes,
        identifier: _validWatchfaceId(identifier) ? identifier : null,
        evidence: [
          'Vela watchface magic=5aa53412',
          if (!_validWatchfaceId(identifier)) 'missing or zero watchface id',
        ],
      );
    }
    if (bytes.length >= 4 &&
        bytes[0] == 0x60 &&
        bytes[1] == 0x5a &&
        bytes[2] == 0x5a &&
        bytes[3] == 0x7e) {
      return ResourcePayloadAnalysis(
        type: LocalDeviceInstallType.firmware,
        platform: ResourcePlatform.vela,
        packageKind: ResourcePackageKind.rawPayload,
        payload: bytes,
        version: _nullTerminatedAscii(bytes, 4, 24),
        evidence: ['Vela firmware magic=605a5a7e'],
      );
    }
    return null;
  }

  static bool _isVelaOta(Set<String> names) {
    if (names.contains('ota.json') && names.contains('vela_ota.bin')) {
      return true;
    }
    if (names.contains('ota.sh') &&
        (names.contains('vela_ota.bin') ||
            names.any(
              (name) => name.startsWith('vela_') && name.endsWith('.bin'),
            ))) {
      return true;
    }
    return false;
  }

  static bool _looksLikeZip(List<int> bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4b &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;

  static bool _isVelaWatchface(List<int> bytes) =>
      bytes.length >= 0x34 &&
      bytes[0] == 0x5a &&
      bytes[1] == 0xa5 &&
      bytes[2] == 0x34 &&
      bytes[3] == 0x12;

  static String? _watchfaceId(Uint8List bytes) =>
      _nullTerminatedAscii(bytes, 0x28, 12);

  static bool _validWatchfaceId(String? id) =>
      id != null &&
      id.isNotEmpty &&
      !RegExp(r'^[0]+$').hasMatch(id) &&
      RegExp(r'^[a-zA-Z0-9_-]{1,12}$').hasMatch(id);

  static Uint8List? _fileBytes(Archive archive, String path) {
    for (final entry in archive) {
      if (entry.isFile && entry.name.replaceAll('\\', '/') == path) {
        return Uint8List.fromList(entry.content as List<int>);
      }
    }
    return null;
  }

  static String? _textFile(Archive archive, String path) {
    final bytes = _fileBytes(archive, path);
    return bytes == null ? null : utf8.decode(bytes, allowMalformed: true);
  }

  static Map<String, Object?>? _jsonFile(Archive archive, String path) {
    final text = _textFile(archive, path);
    if (text == null) return null;
    final value = jsonDecode(text);
    return value is Map ? value.cast<String, Object?>() : null;
  }

  static String? _firstString(Map<String, Object?>? values, List<String> keys) {
    if (values == null) return null;
    for (final key in keys) {
      final value = values[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  static String? _xmlValue(String xml, String tag) {
    final match = RegExp(
      '<$tag>([\\s\\S]*?)</$tag>',
      caseSensitive: false,
    ).firstMatch(xml);
    return match?.group(1)?.trim();
  }

  static String? _propertyValue(String? text, String name) {
    if (text == null) return null;
    for (final line in const LineSplitter().convert(text)) {
      final separator = line.indexOf('=');
      if (separator < 0 || line.substring(0, separator).trim() != name) {
        continue;
      }
      return line.substring(separator + 1).trim();
    }
    return null;
  }

  static String? _nullTerminatedAscii(
    List<int> bytes,
    int offset,
    int maxLength,
  ) {
    if (offset >= bytes.length) return null;
    final end = (offset + maxLength).clamp(0, bytes.length);
    final values = bytes.sublist(offset, end).takeWhile((byte) => byte != 0);
    final result = String.fromCharCodes(values).trim();
    return result.isEmpty ? null : result;
  }
}
