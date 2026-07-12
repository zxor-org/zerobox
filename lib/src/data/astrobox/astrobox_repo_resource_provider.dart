import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

class AstroBoxRepoCatalog implements CommunityResourceCatalog {
  AstroBoxRepoCatalog({Dio? dio, this.cdn = AstroBoxCdn.raw})
    : _dio = dio ?? Dio();

  final Dio _dio;
  final AstroBoxCdn cdn;
  Future<List<AstroBoxIndexItem>>? _indexRequest;
  final Map<String, AstroBoxIndexItem> _indexById = {};

  static const String _repoBase =
      'https://raw.githubusercontent.com/AstralSightStudios/AstroBox-Repo/refs/heads/main';

  @override
  CommunitySourceId get sourceId => CommunitySourceId.astroboxRepo;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(search: true, serverSort: false);

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    var items = List<AstroBoxIndexItem>.from(await _fetchIndex());
    if (query.type != null) {
      items = items.where((item) => _mapType(item.type) == query.type).toList();
    }
    if (query.hidePaid) {
      items = items
          .where((item) => item.paidType != AstroBoxPaidType.paid)
          .toList();
    }
    if (query.hideForcePaid) {
      items = items
          .where((item) => item.paidType != AstroBoxPaidType.forcePaid)
          .toList();
    }
    if (query.selectedDevices.isNotEmpty) {
      items = items
          .where((item) => item.devices.any(query.selectedDevices.contains))
          .toList();
    }
    final needle = query.query.trim().toLowerCase();
    if (needle.isNotEmpty) {
      items = items.where((item) {
        return item.name.toLowerCase().contains(needle) ||
            item.tags.any((tag) => tag.toLowerCase().contains(needle));
      }).toList();
    }
    switch (query.sort) {
      case CommunitySortRule.random:
        // A deterministic seed prevents duplicated/skipped entries between pages.
        items.shuffle(Random(0));
      case CommunitySortRule.name:
        items.sort((a, b) => a.name.compareTo(b.name));
      case CommunitySortRule.time:
        items = items.reversed.toList();
    }
    final start = query.page * query.pageSize;
    final pageItems = start >= items.length
        ? const <AstroBoxIndexItem>[]
        : items.sublist(start, min(start + query.pageSize, items.length));
    return CommunityResourcePage(
      items: pageItems.map(_summaryFromIndex).toList(),
      page: query.page,
      hasMore: start + pageItems.length < items.length,
      total: items.length,
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _requireSource(ref);
    final item = await _findIndexItem(ref.id);
    final manifest = await _fetchManifest(item);
    final files = <CommunityResourceFile>[];
    for (final entry in manifest.downloads.entries) {
      final download = entry.value;
      final name = download.fileName.trim();
      files.add(
        CommunityResourceFile(
          id: entry.key,
          fileName: name,
          displayName: download.displayName,
          version: download.version,
          downloadUrl: Uri.tryParse(_resolveDownloadUrl(item, download)),
          supportedDevices: entry.key == 'default' ? const {} : {entry.key},
        ),
      );
    }
    final manifestItem = manifest.item;
    return CommunityResourceDetail(
      ref: ref,
      name: manifestItem.name,
      type: _mapType(manifestItem.restype),
      paidType: _mapPaid(manifestItem.paidType ?? item.paidType),
      authors: manifestItem.author
          .where((author) => author.name.isNotEmpty)
          .map((author) => CommunityResourceAuthor(name: author.name))
          .toList(),
      supportedDevices: files.expand((file) => file.supportedDevices).toSet(),
      iconUrl: Uri.tryParse(_resolveAssetUrl(item, manifestItem.icon)),
      coverUrl: Uri.tryParse(_resolveAssetUrl(item, manifestItem.cover)),
      summary: manifestItem.description,
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: manifestItem.description,
      ),
      previews: manifestItem.preview
          .map((path) => Uri.tryParse(_resolveAssetUrl(item, path)))
          .whereType<Uri>()
          .toList(),
      previewImages: manifestItem.preview
          .map((path) => Uri.tryParse(_resolveAssetUrl(item, path)))
          .whereType<Uri>()
          .map((url) => CommunityResourceImage(url: url))
          .toList(),
      links: manifest.links
          .map(
            (link) => CommunityResourceLink(
              title: link.title,
              url: Uri.parse(_resolveAssetUrl(item, link.url)),
            ),
          )
          .toList(),
      files: files,
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    const url = '$_repoBase/devices_v2.json';
    final map = AstroBoxDeviceMap.fromJson(await _fetchJsonObject(url));
    return map.xiaomi.values
        .map(
          (device) => CommunityResourceDevice(
            codename: _normalizeDeviceKey(device.id),
            name: device.name,
            description: device.description,
          ),
        )
        .toList();
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    if (request.file.downloadUrl == null) {
      throw StateError('AstroBox resource file has no download URL');
    }
    final fileName = _sanitizeLocalFilename(request.file.label);
    request.onProgress?.call(0);
    if (request.file.downloadUrl!.scheme.isEmpty) {
      throw StateError('AstroBox resource file has an invalid download URL');
    }
    if (kIsWeb) {
      final response = await _dio.get<Uint8List>(
        request.file.downloadUrl!.toString(),
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: (received, total) {
          if (total > 0) request.onProgress?.call(received / total);
        },
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        throw StateError('AstroBox resource download returned empty data');
      }
      request.onProgress?.call(1, status: 'finished');
      return CommunityResourceDownloadResult(
        path: '/zerobox_downloads/$fileName',
        fileName: fileName,
        bytes: bytes,
      );
    }
    final tempDir = await getTemporaryDirectory();
    final directory = Directory(
      '${tempDir.path}/zerobox_downloads/${request.resource.ref.id}',
    );
    await directory.create(recursive: true);
    final path = '${directory.path}/$fileName';
    await _dio.download(
      request.file.downloadUrl!.toString(),
      path,
      onReceiveProgress: (received, total) {
        if (total > 0) request.onProgress?.call(received / total);
      },
    );
    request.onProgress?.call(1, status: 'finished');
    return CommunityResourceDownloadResult(path: path, fileName: fileName);
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    if (file.size != null) return file.size;
    final url = file.downloadUrl;
    if (url == null) return null;
    final response = await _dio.head<Object>(url.toString());
    return int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
  }

  Future<List<AstroBoxIndexItem>> _fetchIndex() {
    return _indexRequest ??= _loadIndex();
  }

  Future<List<AstroBoxIndexItem>> _loadIndex() async {
    final response = await _dio.get<String>('$_repoBase/index_v2.csv');
    final rows = _parseCsvRows(_stripZeroWidth(response.data ?? ''));
    if (rows.isEmpty) return const [];
    final headers = rows.first.map((value) => value.trim()).toList();
    final items = <AstroBoxIndexItem>[];
    for (final row in rows.skip(1)) {
      if (row.length < headers.length) continue;
      final values = <String, String>{
        for (var i = 0; i < headers.length; i++) headers[i]: row[i].trim(),
      };
      final id = values['id'] ?? '';
      if (id.isEmpty || id == '<placeholder>') continue;
      final item = AstroBoxIndexItem(
        id: id,
        name: values['name'] ?? '',
        type: _parseDtoType(values['restype']),
        repoOwner: values['repo_owner'] ?? '',
        repoName: values['repo_name'] ?? '',
        repoCommitHash: values['repo_commit_hash'] ?? '',
        icon: values['icon'] ?? '',
        cover: values['cover'] ?? '',
        tags: _splitSemicolon(values['tags']),
        deviceVendors: _splitSemicolon(values['device_vendors']),
        devices: _normalizeDeviceKeys(_splitSemicolon(values['devices'])),
        paidType: _parseDtoPaid(values['paid_type']),
      );
      items.add(item);
      _indexById[item.id] = item;
    }
    return items;
  }

  Future<AstroBoxIndexItem> _findIndexItem(String id) async {
    await _fetchIndex();
    final item = _indexById[id];
    if (item == null) throw StateError('AstroBox resource not found: $id');
    return item;
  }

  Future<AstroBoxManifest> _fetchManifest(AstroBoxIndexItem item) async {
    final base = _buildRepoRawUrl(item);
    try {
      return _normalizeManifestDeviceKeys(
        AstroBoxManifest.fromJson(
          await _fetchJsonObject('$base/manifest_v2.json'),
        ),
      );
    } on DioException {
      return _legacyManifestV1ToV2(
        await _fetchJsonObject('$base/manifest.json'),
        item,
      );
    }
  }

  CommunityResource _summaryFromIndex(AstroBoxIndexItem item) {
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: item.id),
      name: item.name,
      type: _mapType(item.type),
      paidType: _mapPaid(item.paidType),
      authors: item.repoOwner.isEmpty
          ? const []
          : [CommunityResourceAuthor(name: item.repoOwner)],
      supportedDevices: item.devices.toSet(),
      iconUrl: Uri.tryParse(_resolveAssetUrl(item, item.icon)),
      coverUrl: Uri.tryParse(_resolveAssetUrl(item, item.cover)),
      tags: item.tags,
    );
  }

  Future<Map<String, dynamic>> _fetchJsonObject(String url) async {
    final response = await _dio.get<String>(url);
    final decoded = jsonDecode(response.data ?? '');
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return decoded.cast<String, dynamic>();
    throw FormatException('$url did not return a JSON object');
  }

  String _resolveAssetUrl(AstroBoxIndexItem item, String path) {
    final value = path.trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') ||
        value.startsWith('https://') ||
        value.startsWith('data:') ||
        value.startsWith('/')) {
      return rewriteGithubCdnUrl(value, cdn);
    }
    return rewriteGithubCdnUrl(
      '${_buildRepoRawUrl(item)}/${Uri.encodeComponent(value.trimStartMatches('/'))}',
      cdn,
    );
  }

  String _resolveDownloadUrl(
    AstroBoxIndexItem item,
    AstroBoxManifestDownload download,
  ) {
    if (download.url?.trim().isNotEmpty == true) {
      return _resolveAssetUrl(item, download.url!);
    }
    return _resolveAssetUrl(item, download.fileName);
  }

  String _buildRepoRawUrl(AstroBoxIndexItem item) =>
      'https://raw.githubusercontent.com/${item.repoOwner}/${item.repoName}/${item.repoCommitHash}';

  CommunityResourceType _mapType(AstroBoxResourceType value) => switch (value) {
    AstroBoxResourceType.quickApp => CommunityResourceType.quickApp,
    AstroBoxResourceType.watchface => CommunityResourceType.watchface,
    AstroBoxResourceType.firmware => CommunityResourceType.firmware,
    AstroBoxResourceType.fontpack => CommunityResourceType.fontpack,
    AstroBoxResourceType.iconpack => CommunityResourceType.iconpack,
  };

  CommunityPaidType _mapPaid(AstroBoxPaidType value) => switch (value) {
    AstroBoxPaidType.free => CommunityPaidType.free,
    AstroBoxPaidType.paid => CommunityPaidType.paid,
    AstroBoxPaidType.forcePaid => CommunityPaidType.forcePaid,
  };

  AstroBoxResourceType _parseDtoType(String? value) => switch (value) {
    'watchface' => AstroBoxResourceType.watchface,
    'firmware' => AstroBoxResourceType.firmware,
    'fontpack' => AstroBoxResourceType.fontpack,
    'iconpack' => AstroBoxResourceType.iconpack,
    _ => AstroBoxResourceType.quickApp,
  };

  AstroBoxPaidType _parseDtoPaid(String? value) => switch (value) {
    'paid' => AstroBoxPaidType.paid,
    'force_paid' => AstroBoxPaidType.forcePaid,
    _ => AstroBoxPaidType.free,
  };

  List<String> _splitSemicolon(String? value) => value == null || value.isEmpty
      ? const []
      : value
            .split(';')
            .map((part) => part.trim())
            .where((part) => part.isNotEmpty)
            .toList();

  List<List<String>> _parseCsvRows(String csv) => const LineSplitter()
      .convert(csv)
      .where((line) => line.trim().isNotEmpty)
      .map(_parseCsvLine)
      .toList();

  List<String> _parseCsvLine(String line) {
    final values = <String>[];
    final buffer = StringBuffer();
    var quoted = false;
    for (var index = 0; index < line.length; index++) {
      final character = line[index];
      if (character == '"') {
        if (quoted && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write(character);
          index++;
        } else {
          quoted = !quoted;
        }
      } else if (character == ',' && !quoted) {
        values.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(character);
      }
    }
    values.add(buffer.toString());
    return values;
  }

  String _stripZeroWidth(String value) =>
      value.replaceAll(RegExp('[\u200b\u200c\u200d\u2060\ufeff]'), '');

  List<String> _normalizeDeviceKeys(List<String> keys) => keys
      .map(_normalizeDeviceKey)
      .where((key) => key.isNotEmpty)
      .toSet()
      .toList();

  String _normalizeDeviceKey(String value) {
    final normalized = normalizeXiaomiWearableCodename(value);
    return normalized.isEmpty ? value.trim() : normalized;
  }

  AstroBoxManifest _normalizeManifestDeviceKeys(AstroBoxManifest manifest) {
    return manifest.copyWith(
      downloads: {
        for (final entry in manifest.downloads.entries)
          _normalizeDeviceKey(entry.key): entry.value,
      },
    );
  }

  AstroBoxManifest _legacyManifestV1ToV2(
    Map<String, dynamic> raw,
    AstroBoxIndexItem item,
  ) {
    final itemMap = raw['item'] is Map
        ? (raw['item'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final downloadMap = raw['downloads'] is Map
        ? (raw['downloads'] as Map).cast<String, dynamic>()
        : const <String, dynamic>{};
    final downloads = <String, AstroBoxManifestDownload>{};
    for (final entry in downloadMap.entries) {
      if (entry.value is! Map) continue;
      final data = (entry.value as Map).cast<String, dynamic>();
      downloads[_normalizeDeviceKey(entry.key)] = AstroBoxManifestDownload(
        version: data['version']?.toString() ?? '',
        fileName: data['file_name']?.toString() ?? '',
        url: data['url']?.toString(),
        sha256: data['sha256']?.toString(),
        displayName: data['display_name']?.toString(),
      );
    }
    final authors = _parseAuthors(itemMap['author']);
    return AstroBoxManifest(
      item: AstroBoxManifestItem(
        id: item.id,
        restype: item.type,
        name: itemMap['name']?.toString() ?? item.name,
        description: itemMap['description']?.toString() ?? '',
        preview: _toStringList(itemMap['preview']),
        icon: itemMap['icon']?.toString() ?? item.icon,
        cover: itemMap['cover']?.toString() ?? item.cover,
        paidType: item.paidType,
        author: authors.isEmpty
            ? [AstroBoxManifestAuthor(name: item.repoOwner)]
            : authors,
      ),
      downloads: downloads,
    );
  }

  List<AstroBoxManifestAuthor> _parseAuthors(Object? value) {
    if (value is List) {
      return value
          .whereType<Map>()
          .map((entry) {
            final data = entry.cast<String, dynamic>();
            return AstroBoxManifestAuthor(name: data['name']?.toString() ?? '');
          })
          .where((author) => author.name.isNotEmpty)
          .toList();
    }
    if (value is String && value.isNotEmpty) {
      return [AstroBoxManifestAuthor(name: value)];
    }
    return const [];
  }

  List<String> _toStringList(Object? value) => value is List
      ? value.map((entry) => entry.toString()).toList()
      : const [];

  String _sanitizeLocalFilename(String value) {
    final result = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return result.isEmpty || result == '.' || result == '..'
        ? 'download'
        : result;
  }

  void _requireSource(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw ArgumentError.value(ref, 'ref', 'Wrong resource source');
    }
  }
}

extension on String {
  String trimStartMatches(String prefix) {
    var value = this;
    while (value.startsWith(prefix)) {
      value = value.substring(prefix.length);
    }
    return value;
  }
}
