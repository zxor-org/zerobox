import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

export 'resource_task_status.dart';

enum ResourceTaskStatus { pending, downloading, installing, completed, failed }

enum LocalDeviceInstallType { app, watchface, firmware }

class DownloadedResource {
  const DownloadedResource({
    required this.path,
    required this.fileName,
    this.bytes,
  });

  final String path;
  final String fileName;
  final Uint8List? bytes;
}

class ResourceInstallService {
  Future<DownloadedResource?> downloadResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required CommunityResourceCatalog catalog,
    String? targetDevice,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    onUpdate(ResourceTaskStatus.downloading, 0, null);
    try {
      final result = await catalog.download(
        CommunityDownloadRequest(
          resource: resource,
          file: file,
          targetDevice: targetDevice,
          onProgress: (progress, {status = ''}) =>
              onUpdate(ResourceTaskStatus.downloading, progress, null),
        ),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
      return DownloadedResource(
        path: result.path,
        fileName: result.fileName,
        bytes: result.bytes,
      );
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Download failed: $e');
      return null;
    }
  }

  Future<void> installDownloadedResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String filePath,
    Uint8List? bytes,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
    bool deleteAfterInstall = false,
  }) async {
    onUpdate(ResourceTaskStatus.installing, 0, null);
    try {
      final payload = bytes ?? await File(filePath).readAsBytes();
      await _installByType(
        resource: resource,
        file: file,
        bytes: payload,
        deviceManager: deviceManager,
        onProgress: (progress) =>
            onUpdate(ResourceTaskStatus.installing, progress, null),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    } finally {
      if (deleteAfterInstall && !kIsWeb) {
        try {
          await File(filePath).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> downloadAndInstall({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required CommunityResourceCatalog catalog,
    String? targetDevice,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
    required String taskId,
  }) async {
    final downloaded = await downloadResource(
      resource: resource,
      file: file,
      catalog: catalog,
      targetDevice: targetDevice,
      onUpdate: onUpdate,
    );
    if (downloaded == null) return;
    await installDownloadedResource(
      resource: resource,
      file: file,
      filePath: downloaded.path,
      bytes: downloaded.bytes,
      deviceManager: deviceManager,
      onUpdate: onUpdate,
      deleteAfterInstall: true,
    );
  }

  Future<void> installLocalFile({
    required String filePath,
    Uint8List? bytes,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    onUpdate(ResourceTaskStatus.installing, 0, null);

    final fileName = Uri.tryParse(filePath)?.pathSegments.isNotEmpty == true
        ? Uri.decodeComponent(Uri.parse(filePath).pathSegments.last)
        : filePath;

    Uint8List payload;
    try {
      payload = bytes ?? await File(filePath).readAsBytes();
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Read failed: $e');
      return;
    }

    final type = detectLocalInstallType(fileName, payload);
    if (type == null) {
      onUpdate(
        ResourceTaskStatus.failed,
        0,
        'Unsupported or ambiguous file type: $fileName',
      );
      return;
    }

    try {
      await installLocalPayload(
        type: type,
        fileName: fileName,
        bytes: payload,
        deviceManager: deviceManager,
        onProgress: (progress) =>
            onUpdate(ResourceTaskStatus.installing, progress, null),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    }
  }

  /// Installs an already loaded local payload and propagates failures to the
  /// caller. GUI queue code wraps this method to update task state, while CLI
  /// callers use the thrown error to produce a reliable process exit code.
  Future<void> installLocalPayload({
    required LocalDeviceInstallType type,
    required String fileName,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
  }) async {
    switch (type) {
      case LocalDeviceInstallType.app:
        await deviceManager.installApp(
          bytes,
          packageName:
              _extractAppPackageName(bytes) ?? _guessPackageName(fileName),
          onProgress: onProgress,
        );
      case LocalDeviceInstallType.watchface:
        await deviceManager.installWatchface(
          bytes,
          watchfaceId:
              _extractWatchfaceId(bytes) ?? _guessWatchfaceId(fileName),
          onProgress: onProgress,
        );
      case LocalDeviceInstallType.firmware:
        await deviceManager.installFirmware(bytes, onProgress: onProgress);
    }
  }

  LocalDeviceInstallType? detectLocalInstallType(
    String fileName,
    Uint8List bytes,
  ) {
    // Zepp OS packages are ZIP containers whose extension is routinely
    // changed by browsers, download managers and users. Their manifest and
    // nested package structure are authoritative; the name is only a hint.
    try {
      final package = const ZeppOsPackageParser().parse(bytes);
      return switch (package.type) {
        ZeppOsPackageType.app => LocalDeviceInstallType.app,
        ZeppOsPackageType.watchface => LocalDeviceInstallType.watchface,
        ZeppOsPackageType.firmware => LocalDeviceInstallType.firmware,
      };
    } catch (_) {
      // Not a recognized Zepp OS container. Continue with other formats and
      // finally use the extension as a compatibility fallback.
    }

    final lower = fileName.toLowerCase();
    final extension = lower.contains('.') ? lower.split('.').last : '';

    if (_extractAppPackageName(bytes) != null) {
      return LocalDeviceInstallType.app;
    }
    if (_extractWatchfaceId(bytes) != null) {
      return LocalDeviceInstallType.watchface;
    }
    if (extension == 'rpk' || extension == 'zpk' || extension == 'zab') {
      return LocalDeviceInstallType.app;
    }
    if (extension == 'face' || extension == 'mwz') {
      return LocalDeviceInstallType.watchface;
    }
    return null;
  }

  Future<void> _installByType({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
  }) async {
    switch (resource.type) {
      case CommunityResourceType.quickApp:
        final packageName =
            _extractAppPackageName(bytes) ?? _guessPackageName(file.fileName);
        await deviceManager.installApp(
          bytes,
          packageName: packageName,
          onProgress: onProgress,
        );
      case CommunityResourceType.watchface:
        final watchfaceId =
            _extractWatchfaceId(bytes) ?? _guessWatchfaceId(file.fileName);
        await deviceManager.installWatchface(
          bytes,
          watchfaceId: watchfaceId,
          onProgress: onProgress,
        );
      case CommunityResourceType.firmware:
        await deviceManager.installFirmware(bytes, onProgress: onProgress);
      case CommunityResourceType.fontpack:
      case CommunityResourceType.iconpack:
        throw UnsupportedError('${resource.type} install not implemented yet');
    }
  }

  String _guessPackageName(String fileName) {
    final name = fileName.split('.').first;
    if (name.isEmpty) return 'com.zerobox.unknown';
    final sanitized = name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_');
    return 'com.zerobox.$sanitized';
  }

  String _guessWatchfaceId(String fileName) {
    return fileName.split('.').first;
  }

  String? _extractAppPackageName(Uint8List bytes) {
    if (!_looksLikeZip(bytes)) return null;
    try {
      final archive = ZipDecoder().decodeBytes(bytes);
      const candidates = ['manifest.json', 'app.json'];
      for (final entry in archive) {
        if (!entry.isFile) continue;
        final name = entry.name.toLowerCase();
        if (!candidates.contains(name)) continue;
        final text = utf8.decode(entry.content);
        final json = jsonDecode(text) as Map<String, dynamic>;
        final pkg =
            json['package'] ?? json['packageName'] ?? json['package_name'];
        if (pkg is String && pkg.isNotEmpty) return pkg;
      }
    } catch (e) {
      log(
        'failed to parse app zip manifest',
        error: e,
        name: 'ResourceInstallService',
      );
    }
    return null;
  }

  String? _extractWatchfaceId(Uint8List bytes) {
    if (_looksLikeZip(bytes)) {
      try {
        final archive = ZipDecoder().decodeBytes(bytes);
        for (final entry in archive) {
          if (!entry.isFile) continue;
          if (entry.name.toLowerCase().endsWith('.json')) {
            final text = utf8.decode(entry.content);
            final json = jsonDecode(text) as Map<String, dynamic>;
            final id =
                json['id'] ?? json['watchfaceId'] ?? json['watchface_id'];
            if (id is String && _isValidWatchfaceId(id)) return id;
          }
        }
      } catch (e) {
        log(
          'failed to parse watchface zip manifest',
          error: e,
          name: 'ResourceInstallService',
        );
      }
      return null;
    }

    final id = _extractWatchfaceIdFromBin(bytes);
    if (id != null && _isValidWatchfaceId(id)) return id;
    return null;
  }

  static String? _extractWatchfaceIdFromBin(Uint8List bytes) {
    const idOffset = 0x28;
    const idLength = 12;
    if (bytes.length < idOffset + idLength) return null;
    final raw = bytes.sublist(idOffset, idOffset + idLength);
    final trimmed = raw
        .takeWhile((b) => b != 0)
        .map((b) => String.fromCharCode(b))
        .join();
    return trimmed.isEmpty ? null : trimmed;
  }

  static bool _isValidWatchfaceId(String id) {
    if (id.isEmpty || id.length > 12) return false;
    if (RegExp(r'^[0]+$').hasMatch(id)) return false;
    return RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(id);
  }

  bool _looksLikeZip(Uint8List bytes) =>
      bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

final resourceInstallServiceProvider = Provider<ResourceInstallService>((ref) {
  return ResourceInstallService();
});

extension ResourceTypeLabel on CommunityResourceType {
  String get fileExtensionHint {
    return switch (this) {
      CommunityResourceType.quickApp => 'bin/rpk/zpk/zab/zip',
      CommunityResourceType.watchface => 'bin/face/mwz/zip',
      CommunityResourceType.firmware => 'zip/bin',
      CommunityResourceType.fontpack => 'zip',
      CommunityResourceType.iconpack => 'zip',
    };
  }
}
