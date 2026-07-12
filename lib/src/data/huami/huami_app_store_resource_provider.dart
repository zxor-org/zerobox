import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/data/huami/huami_app_store_api_client.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

class HuamiAppStoreCatalog implements CommunityResourceCatalog {
  HuamiAppStoreCatalog({required Dio dio, required HuamiAuthNotifier auth})
    : _api = HuamiAppStoreApiClient(dio: dio, auth: auth);

  final HuamiAppStoreApiClient _api;

  static const _fallbackDeviceSources = [
    8519936,
    8519937,
    8519939,
    9568512,
    9568513,
    9568515,
  ];

  @override
  CommunitySourceId get sourceId => CommunitySourceId.huamiAppStore;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(
        search: false,
        deviceFilter: true,
        typeFilter: true,
        serverSort: true,
      );

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    if (query.type != null && query.type != CommunityResourceType.quickApp) {
      return CommunityResourcePage(
        items: const [],
        page: query.page,
        hasMore: false,
      );
    }

    final deviceSources = _selectedDeviceSources(query.selectedDevices);
    final perDevicePageSize = max(
      5,
      (query.pageSize / deviceSources.length).ceil(),
    );
    final pages = await Future.wait(
      deviceSources.map(
        (source) => _api.getPopularApps(
          deviceSource: source,
          page: query.page + 1,
          perPage: perDevicePageSize,
        ),
      ),
    );

    final items = <CommunityResource>[];
    final seen = <String>{};
    for (var index = 0; index < deviceSources.length; index += 1) {
      final source = deviceSources[index];
      for (final row in pages[index]) {
        final appId = row['id']?.toString() ?? '';
        if (appId.isEmpty || !seen.add(appId)) continue;
        final item = _summaryFromApp(row, deviceSource: source);
        if (item == null) continue;
        items.add(item);
      }
    }
    items.sort((a, b) {
      final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });

    return CommunityResourcePage(
      items: items.take(query.pageSize).toList(),
      page: query.page,
      hasMore: pages.any((page) => page.length >= perDevicePageSize),
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _requireSource(ref);
    final parts = ref.id.split(':');
    if (parts.length != 2) {
      throw FormatException('Invalid Huami AppStore ref: ${ref.id}');
    }
    final deviceSource = int.parse(parts[0]);
    final appId = parts[1];
    final detail = await _api.getAppDetail(
      deviceSource: deviceSource,
      appId: appId,
    );
    return _detailFromApp(detail, deviceSource: deviceSource, appId: appId);
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final devices = await _api.getDevices();
    return devices
        .where((device) => device.supportsLightApps)
        .map(
          (device) => CommunityResourceDevice(
            codename: device.deviceSource.toString(),
            name: device.name.isEmpty
                ? device.deviceSource.toString()
                : device.name,
            description: device.id,
          ),
        )
        .toList();
  }

  Future<List<CommunityResource>> getPublisherResources({
    required String publisherName,
    int maxPages = 2,
  }) async {
    final normalizedPublisher = _normalizePublisher(publisherName);
    if (normalizedPublisher.isEmpty) return const [];

    final candidates = <String, _HuamiAppCandidate>{};
    for (var page = 1; page <= maxPages; page += 1) {
      final pages = await Future.wait(
        _fallbackDeviceSources.map(
          (source) => _api.getPopularApps(
            deviceSource: source,
            page: page,
            perPage: 15,
          ),
        ),
      );
      for (var index = 0; index < _fallbackDeviceSources.length; index += 1) {
        final source = _fallbackDeviceSources[index];
        for (final row in pages[index]) {
          final appId = row['id']?.toString() ?? '';
          if (appId.isEmpty) continue;
          candidates.putIfAbsent(
            appId,
            () => _HuamiAppCandidate(deviceSource: source, appId: appId),
          );
        }
      }
    }

    final items = <CommunityResource>[];
    for (final candidate in candidates.values.take(60)) {
      try {
        final detail = await _api.getAppDetail(
          deviceSource: candidate.deviceSource,
          appId: candidate.appId,
        );
        final publisher = _publisherName(detail['publisher']);
        if (_normalizePublisher(publisher) != normalizedPublisher) continue;
        items.add(
          _detailFromApp(
            detail,
            deviceSource: candidate.deviceSource,
            appId: candidate.appId,
          ),
        );
      } catch (_) {
        // Individual store entries may disappear between list and detail fetches.
      }
    }

    items.sort((a, b) {
      final aTime = a.updatedAt?.millisecondsSinceEpoch ?? 0;
      final bTime = b.updatedAt?.millisecondsSinceEpoch ?? 0;
      return bTime.compareTo(aTime);
    });
    return items;
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    final url = request.file.downloadUrl;
    if (url == null) {
      throw StateError('Huami AppStore resource file has no download URL');
    }
    request.onProgress?.call(0);
    final response = await _api.downloadFile(
      url.toString(),
      onReceiveProgress: (received, total) {
        if (total > 0) request.onProgress?.call(received / total);
      },
    );
    final bytes = Uint8List.fromList(response.data ?? const []);
    if (bytes.isEmpty) {
      throw StateError('Huami AppStore download returned empty data');
    }
    final fileName = _sanitizeFileName(request.file.fileName);
    request.onProgress?.call(1, status: 'finished');
    if (kIsWeb) {
      return CommunityResourceDownloadResult(
        path: '/zerobox_downloads/$fileName',
        fileName: fileName,
        bytes: bytes,
      );
    }

    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/zerobox_downloads/${request.resource.ref.id}',
    );
    await directory.create(recursive: true);
    final path = '${directory.path}/$fileName';
    await File(path).writeAsBytes(bytes, flush: true);
    return CommunityResourceDownloadResult(path: path, fileName: fileName);
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    return file.size;
  }

  List<int> _selectedDeviceSources(Set<String> selectedDevices) {
    final selected = selectedDevices
        .map((value) => int.tryParse(value))
        .whereType<int>()
        .where((value) => value > 0)
        .toList();
    return selected.isEmpty ? _fallbackDeviceSources : selected;
  }

  CommunityResource? _summaryFromApp(
    Map<String, Object?> row, {
    required int deviceSource,
  }) {
    final appId = row['id']?.toString() ?? '';
    final name = row['name']?.toString().trim() ?? '';
    if (appId.isEmpty || name.isEmpty) return null;
    final version =
        row['device_support_version']?.toString() ??
        row['version']?.toString() ??
        '';
    final isFree = row['is_free'] != false;
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: '$deviceSource:$appId'),
      name: name,
      type: CommunityResourceType.quickApp,
      paidType: isFree ? CommunityPaidType.free : CommunityPaidType.paid,
      authors: _publisherAuthors(row['publisher']),
      supportedDevices: {deviceSource.toString()},
      iconUrl: _uri(row['image']),
      coverUrl: _uri(row['image']),
      summary: row['brief_description']?.toString().trim() ?? '',
      updatedAt: _dateFromUnix(row['updated_at']),
      tags: const [],
      version: version,
    );
  }

  CommunityResourceDetail _detailFromApp(
    Map<String, Object?> row, {
    required int deviceSource,
    required String appId,
  }) {
    final summary =
        _summaryFromApp(row, deviceSource: deviceSource) ??
        CommunityResource(
          ref: ResourceRef(source: sourceId, id: '$deviceSource:$appId'),
          name: row['name']?.toString().trim() ?? appId,
          type: CommunityResourceType.quickApp,
          paidType: row['is_free'] == false
              ? CommunityPaidType.paid
              : CommunityPaidType.free,
          authors: const [],
          supportedDevices: {deviceSource.toString()},
        );
    final downloadUrl = _uri(row['download_url']);
    final version = summary.version ?? row['version']?.toString() ?? '';
    final previews = _previewImages(row['preview_pic']);
    final description = row['description']?.toString().trim() ?? '';
    final changelog = row['new_description']?.toString().trim() ?? '';
    final publisher = _publisherAuthor(row['publisher']);
    return CommunityResourceDetail(
      ref: summary.ref,
      name: summary.name,
      type: summary.type,
      paidType: summary.paidType,
      authors: publisher == null ? summary.authors : [publisher],
      supportedDevices: summary.supportedDevices,
      iconUrl: summary.iconUrl,
      coverUrl: summary.coverUrl,
      summary: summary.summary,
      updatedAt: summary.updatedAt,
      tags: summary.tags,
      version: version,
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: [
          if (description.isNotEmpty) description,
          if (changelog.isNotEmpty) 'Changelog:\n$changelog',
        ].join('\n\n'),
      ),
      files: downloadUrl == null
          ? const []
          : [
              CommunityResourceFile(
                id: '$appId:$version',
                fileName: _fileNameFromUrl(downloadUrl, fallback: '$appId.zpk'),
                version: version,
                downloadUrl: downloadUrl,
                size: _intValue(row['size']),
                supportedDevices: {deviceSource.toString()},
              ),
            ],
      previews: previews.map((image) => image.url).toList(),
      previewImages: previews,
      canDownload:
          downloadUrl != null && summary.paidType == CommunityPaidType.free,
    );
  }

  List<CommunityResourceImage> _previewImages(Object? value) {
    if (value is! List) return const [];
    return value
        .map(_uri)
        .whereType<Uri>()
        .map((url) => CommunityResourceImage(url: url))
        .toList();
  }

  CommunityResourceAuthor? _publisherAuthor(Object? value) {
    final name = _publisherName(value);
    if (name == null || name.trim().isEmpty) return null;
    return CommunityResourceAuthor(name: name.trim());
  }

  List<CommunityResourceAuthor> _publisherAuthors(Object? value) {
    final author = _publisherAuthor(value);
    return author == null ? const [] : [author];
  }

  String? _publisherName(Object? value) {
    if (value is Map) {
      final map = value.cast<String, Object?>();
      return map['name']?.toString();
    }
    return null;
  }

  String _normalizePublisher(String? value) => (value ?? '').trim().toLowerCase();

  DateTime? _dateFromUnix(Object? value) {
    final seconds = _intValue(value);
    return seconds == null || seconds <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  int? _intValue(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');

  Uri? _uri(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  String _fileNameFromUrl(Uri url, {required String fallback}) {
    final last = url.pathSegments.isEmpty ? '' : url.pathSegments.last;
    final decoded = Uri.decodeComponent(last);
    return decoded.trim().isEmpty ? fallback : decoded;
  }

  String _sanitizeFileName(String value) {
    final result = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return result.isEmpty ? 'huami-appstore.zpk' : result;
  }

  void _requireSource(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw ArgumentError.value(ref, 'ref', 'Wrong resource source');
    }
  }
}

class _HuamiAppCandidate {
  const _HuamiAppCandidate({required this.deviceSource, required this.appId});

  final int deviceSource;
  final String appId;
}
