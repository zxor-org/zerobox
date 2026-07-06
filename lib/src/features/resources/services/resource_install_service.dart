import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/data/astrobox/astrobox_community_repository.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:archive/archive.dart';

export 'resource_task_status.dart';

enum ResourceTaskStatus { pending, downloading, installing, completed, failed }

enum LocalDeviceInstallType { app, watchface, firmware }

class DownloadedResource {
  const DownloadedResource({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

class ResourceInstallService {
  ResourceInstallService({Dio? dio, this.cancelToken}) : _dio = dio ?? Dio();

  final Dio _dio;
  final CancelToken? cancelToken;

  Future<DownloadedResource?> downloadResource({
    required AstroBoxIndexItem item,
    required AstroBoxManifestDownload download,
    required AstroBoxCommunityRepository repo,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    final resolvedUrl = repo.resolveDownloadUrl(item, download);
    if (resolvedUrl.isEmpty) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Download URL missing');
      return null;
    }

    onUpdate(ResourceTaskStatus.downloading, 0, null);

    final displayName = (download.displayName?.isNotEmpty ?? false)
        ? download.displayName!
        : download.fileName;
    final tempDir = await getTemporaryDirectory();
    final safeName = displayName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final savePath = '${tempDir.path}/zerobox_downloads/$safeName';
    await Directory(
      '${tempDir.path}/zerobox_downloads',
    ).create(recursive: true);

    try {
      await _dio.download(
        resolvedUrl,
        savePath,
        cancelToken: cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onUpdate(ResourceTaskStatus.downloading, received / total, null);
          }
        },
      );
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) {
        onUpdate(ResourceTaskStatus.failed, 0, 'Cancelled');
      } else {
        onUpdate(ResourceTaskStatus.failed, 0, 'Download failed: $e');
      }
      return null;
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Download failed: $e');
      return null;
    }

    onUpdate(ResourceTaskStatus.completed, 1, null);
    return DownloadedResource(path: savePath, fileName: displayName);
  }

  Future<void> installDownloadedResource({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required String filePath,
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
      final bytes = await File(filePath).readAsBytes();
      await _installByType(
        item: item,
        manifest: manifest,
        download: download,
        bytes: bytes,
        deviceManager: deviceManager,
        onProgress: (progress) =>
            onUpdate(ResourceTaskStatus.installing, progress, null),
      );
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    } finally {
      if (deleteAfterInstall) {
        try {
          await File(filePath).delete();
        } catch (_) {}
      }
    }
  }

  Future<void> downloadAndInstall({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required AstroBoxCommunityRepository repo,
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
      item: item,
      download: download,
      repo: repo,
      onUpdate: onUpdate,
    );
    if (downloaded == null) return;
    await installDownloadedResource(
      item: item,
      manifest: manifest,
      download: download,
      filePath: downloaded.path,
      deviceManager: deviceManager,
      onUpdate: onUpdate,
      deleteAfterInstall: true,
    );
  }

  Future<void> installLocalFile({
    required String filePath,
    required DeviceManager deviceManager,
    required void Function(
      ResourceTaskStatus status,
      double progress,
      String? error,
    )
    onUpdate,
  }) async {
    onUpdate(ResourceTaskStatus.installing, 0, null);

    final file = File(filePath);
    final fileName = file.uri.pathSegments.isEmpty
        ? filePath
        : Uri.decodeComponent(file.uri.pathSegments.last);

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Read failed: $e');
      return;
    }

    final type = detectLocalInstallType(fileName, bytes);
    if (type == null) {
      onUpdate(
        ResourceTaskStatus.failed,
        0,
        'Unsupported or ambiguous file type: $fileName',
      );
      return;
    }

    try {
      switch (type) {
        case LocalDeviceInstallType.app:
          await deviceManager.installApp(
            bytes,
            packageName:
                _extractAppPackageName(bytes) ?? _guessPackageName(fileName),
            onProgress: (progress) =>
                onUpdate(ResourceTaskStatus.installing, progress, null),
          );
        case LocalDeviceInstallType.watchface:
          await deviceManager.installWatchface(
            bytes,
            watchfaceId:
                _extractWatchfaceId(bytes) ?? _guessWatchfaceId(fileName),
            onProgress: (progress) =>
                onUpdate(ResourceTaskStatus.installing, progress, null),
          );
        case LocalDeviceInstallType.firmware:
          await deviceManager.installFirmware(
            bytes,
            onProgress: (progress) =>
                onUpdate(ResourceTaskStatus.installing, progress, null),
          );
      }
      onUpdate(ResourceTaskStatus.completed, 1, null);
    } catch (e) {
      onUpdate(ResourceTaskStatus.failed, 0, 'Install failed: $e');
    }
  }

  LocalDeviceInstallType? detectLocalInstallType(
    String fileName,
    Uint8List bytes,
  ) {
    final lower = fileName.toLowerCase();
    final extension = lower.contains('.') ? lower.split('.').last : '';

    if (extension == 'rpk' || extension == 'zpk') {
      return LocalDeviceInstallType.app;
    }
    if (extension == 'face' || extension == 'mwz') {
      return LocalDeviceInstallType.watchface;
    }
    if (_extractAppPackageName(bytes) != null) {
      return LocalDeviceInstallType.app;
    }
    if (_extractWatchfaceId(bytes) != null) {
      return LocalDeviceInstallType.watchface;
    }
    return null;
  }

  Future<void> _installByType({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required Uint8List bytes,
    required DeviceManager deviceManager,
    required void Function(double progress) onProgress,
  }) async {
    switch (item.type) {
      case AstroBoxResourceType.quickApp:
        final packageName =
            _extractAppPackageName(bytes) ??
            _guessPackageName(download.fileName);
        await deviceManager.installApp(
          bytes,
          packageName: packageName,
          onProgress: onProgress,
        );
      case AstroBoxResourceType.watchface:
        final watchfaceId =
            _extractWatchfaceId(bytes) ?? _guessWatchfaceId(download.fileName);
        await deviceManager.installWatchface(
          bytes,
          watchfaceId: watchfaceId,
          onProgress: onProgress,
        );
      case AstroBoxResourceType.firmware:
        await deviceManager.installFirmware(bytes, onProgress: onProgress);
      case AstroBoxResourceType.fontpack:
      case AstroBoxResourceType.iconpack:
        throw UnsupportedError('${item.type} install not implemented yet');
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

extension ResourceTypeLabel on AstroBoxResourceType {
  String get fileExtensionHint {
    return switch (this) {
      AstroBoxResourceType.quickApp => 'bin/rpk/zpk/zip',
      AstroBoxResourceType.watchface => 'bin/face/mwz/zip',
      AstroBoxResourceType.firmware => 'zip/bin',
      AstroBoxResourceType.fontpack => 'zip',
      AstroBoxResourceType.iconpack => 'zip',
    };
  }
}
