import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/data/community/community_resource_repository.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';

class AstroBoxRepoCommunityRepository implements CommunityResourceRepository {
  AstroBoxRepoCommunityRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  static const String _repoBase =
      'https://raw.githubusercontent.com/AstralSightStudios/AstroBox-Repo/refs/heads/main';

  @override
  CommunitySourceId get sourceId => CommunitySourceId.astroboxRepo;

  @override
  String get providerName => sourceId.storageKey;

  @override
  CommunityProviderState get state => CommunityProviderState.ready;

  @override
  Future<void> refresh({String config = ''}) async {}

  @override
  Future<List<AstroBoxIndexItem>> fetchIndex() async {
    const url = '$_repoBase/index_v2.csv';
    final response = await _dio.get<String>(url);
    final sanitized = _stripZeroWidth(response.data ?? '');

    final rows = _parseCsvRows(sanitized);

    if (rows.isEmpty) return [];

    final headers = rows.first.map((e) => e.toString().trim()).toList();
    final items = <AstroBoxIndexItem>[];

    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.length < headers.length) continue;
      final map = <String, String>{};
      for (var j = 0; j < headers.length; j++) {
        map[headers[j]] = row[j].toString().trim();
      }

      final id = map['id'] ?? '';
      if (id.isEmpty || id == '<placeholder>') continue;

      items.add(
        AstroBoxIndexItem(
          id: id,
          name: map['name'] ?? '',
          type: _parseResourceType(map['restype']),
          repoOwner: map['repo_owner'] ?? '',
          repoName: map['repo_name'] ?? '',
          repoCommitHash: map['repo_commit_hash'] ?? '',
          icon: map['icon'] ?? '',
          cover: map['cover'] ?? '',
          tags: _splitSemicolon(map['tags']),
          deviceVendors: _splitSemicolon(map['device_vendors']),
          devices: _normalizeDeviceKeys(_splitSemicolon(map['devices'])),
          paidType: _parsePaidType(map['paid_type']),
        ),
      );
    }

    return items;
  }

  @override
  Future<AstroBoxDeviceMap> fetchDeviceMap() async {
    const url = '$_repoBase/devices_v2.json';
    final data = await _fetchJsonObject(url, 'devices_v2.json');
    return AstroBoxDeviceMap.fromJson(data);
  }

  @override
  Future<AstroBoxManifest> fetchManifest(AstroBoxIndexItem item) async {
    final base = _buildRepoRawUrl(item);

    try {
      final url = '$base/manifest_v2.json';
      final data = await _fetchJsonObject(url, 'manifest_v2.json');
      return _normalizeManifestDeviceKeys(AstroBoxManifest.fromJson(data));
    } on DioException catch (_) {
      final url = '$base/manifest.json';
      final data = await _fetchJsonObject(url, 'manifest.json');
      return _legacyManifestV1ToV2(data, item);
    }
  }

  @override
  Future<List<AstroBoxIndexItem>> getPage({
    required int page,
    required int limit,
    CommunitySearchConfig search = const CommunitySearchConfig(),
  }) async {
    var result = await fetchIndex();

    if (search.type != null) {
      result = result.where((item) => item.type == search.type).toList();
    }
    if (search.hidePaid) {
      result = result
          .where((item) => item.paidType != AstroBoxPaidType.paid)
          .toList();
    }
    if (search.hideForcePaid) {
      result = result
          .where((item) => item.paidType != AstroBoxPaidType.forcePaid)
          .toList();
    }
    if (search.selectedDevices.isNotEmpty) {
      result = result
          .where((item) => item.devices.any(search.selectedDevices.contains))
          .toList();
    }

    final query = search.query?.trim().toLowerCase() ?? '';
    if (query.isNotEmpty) {
      result = result.where((item) {
        return item.name.toLowerCase().contains(query) ||
            item.tags.any((tag) => tag.toLowerCase().contains(query));
      }).toList();
    }

    switch (search.sort) {
      case CommunitySortRule.random:
        result.shuffle(Random());
      case CommunitySortRule.name:
        result.sort((a, b) => a.name.compareTo(b.name));
      case CommunitySortRule.time:
        result = result.reversed.toList();
    }

    final start = page * limit;
    if (start >= result.length) return [];
    final end = min(start + limit, result.length);
    return result.sublist(start, end);
  }

  @override
  Future<List<String>> getCategories() async {
    final deviceMap = await fetchDeviceMap();
    final categories = <String>{
      'hide_paid',
      'hide_force_paid',
      'quick_app',
      'watchface',
      ...deviceMap.xiaomi.values.map((device) => device.name),
    };
    return categories.toList();
  }

  @override
  Future<AstroBoxManifest> getItemManifest(String itemId) async {
    final index = await fetchIndex();
    final item = index.cast<AstroBoxIndexItem?>().firstWhere(
      (entry) => entry?.id == itemId || entry?.name == itemId,
      orElse: () => null,
    );
    if (item == null) {
      throw StateError('Item not found by id or name: $itemId');
    }
    return fetchManifest(item);
  }

  @override
  Future<CommunityDownloadResult> download({
    required String itemId,
    required String device,
    void Function(CommunityProgressData progress)? onProgress,
  }) async {
    final index = await fetchIndex();
    final item = index.cast<AstroBoxIndexItem?>().firstWhere(
      (entry) => entry?.id == itemId || entry?.name == itemId,
      orElse: () => null,
    );
    if (item == null) {
      throw StateError('Item not found by id or name: $itemId');
    }

    final manifest = await fetchManifest(item);
    final download = _resolveDownloadEntry(manifest, device);
    final url = resolveDownloadUrl(item, download);
    var fileName = download.displayName?.trim().isNotEmpty == true
        ? download.displayName!.trim()
        : download.fileName.trim();
    if (fileName.isEmpty && download.url?.trim().isNotEmpty == true) {
      fileName = Uri.parse(download.url!).pathSegments.last;
    }
    if (fileName.isEmpty) {
      throw StateError('Download entry missing file name');
    }

    final tempDir = await getTemporaryDirectory();
    final itemDir = Directory('${tempDir.path}/zerobox_downloads/${item.id}');
    await itemDir.create(recursive: true);
    final safeName = _sanitizeLocalFilename(fileName);
    final savePath = '${itemDir.path}/$safeName';

    onProgress?.call(const CommunityProgressData(progress: 0));
    await _dio.download(
      url,
      savePath,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(CommunityProgressData(progress: received / total));
        }
      },
    );
    onProgress?.call(
      const CommunityProgressData(progress: 1, status: 'finished'),
    );
    return CommunityDownloadResult(path: savePath, fileName: fileName);
  }

  @override
  Future<int?> probeDownloadSize({
    required String itemId,
    required String device,
  }) async {
    final index = await fetchIndex();
    final item = index.cast<AstroBoxIndexItem?>().firstWhere(
      (entry) => entry?.id == itemId || entry?.name == itemId,
      orElse: () => null,
    );
    if (item == null) {
      throw StateError('Item not found by id or name: $itemId');
    }
    final manifest = await fetchManifest(item);
    final download = _resolveDownloadEntry(manifest, device);
    final response = await _dio.head<Object>(
      resolveDownloadUrl(item, download),
    );
    return int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
  }

  Future<Map<String, dynamic>> _fetchJsonObject(
    String url,
    String pathForError,
  ) async {
    final response = await _dio.get<String>(url);
    final text = response.data ?? '';
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      throw FormatException(
        '$pathForError returned ${decoded.runtimeType} instead of JSON object\nURL: $url',
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw FormatException(
        '$pathForError returned invalid JSON\nURL: $url\nFirst 200 chars: ${text.length > 200 ? text.substring(0, 200) : text}',
      );
    }
  }

  @override
  String resolveImageUrl(AstroBoxIndexItem item, String path) {
    if (path.startsWith('http://') ||
        path.startsWith('https://') ||
        path.startsWith('data:') ||
        path.startsWith('blob:') ||
        path.startsWith('tauri:') ||
        path.startsWith('/')) {
      return path;
    }
    final base = _buildRepoRawUrl(item);
    return '$base/${path.trimStartMatches('/')}';
  }

  String buildRepoRawUrl(AstroBoxIndexItem item) => _buildRepoRawUrl(item);

  @override
  String resolveDownloadUrl(
    AstroBoxIndexItem item,
    AstroBoxManifestDownload download,
  ) {
    if (download.url != null && download.url!.isNotEmpty) {
      return resolveImageUrl(item, download.url!);
    }
    final base = _buildRepoRawUrl(item).replaceAll(RegExp(r'/+$'), '');
    return '$base/${download.fileName.trimStartMatches('/')}';
  }

  String _buildRepoRawUrl(AstroBoxIndexItem item) {
    return 'https://raw.githubusercontent.com/${item.repoOwner}/${item.repoName}/${item.repoCommitHash}';
  }

  AstroBoxManifestDownload _resolveDownloadEntry(
    AstroBoxManifest manifest,
    String device,
  ) {
    final normalizedDevice = _normalizeDeviceKey(device);
    final downloads = manifest.downloads;
    if (downloads.isEmpty) {
      throw StateError('Manifest ${manifest.item.id} has no downloads');
    }
    return downloads[normalizedDevice] ??
        downloads[device] ??
        downloads['default'] ??
        downloads.values.first;
  }

  String _sanitizeLocalFilename(String input) {
    final sanitized = input
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ');
    if (sanitized.isEmpty || sanitized == '.' || sanitized == '..') {
      return 'download';
    }
    return sanitized;
  }

  AstroBoxResourceType _parseResourceType(String? value) {
    return switch (value) {
      'quick_app' => AstroBoxResourceType.quickApp,
      'watchface' => AstroBoxResourceType.watchface,
      'firmware' => AstroBoxResourceType.firmware,
      'fontpack' => AstroBoxResourceType.fontpack,
      'iconpack' => AstroBoxResourceType.iconpack,
      _ => AstroBoxResourceType.quickApp,
    };
  }

  AstroBoxPaidType _parsePaidType(String? value) {
    return switch (value) {
      'paid' => AstroBoxPaidType.paid,
      'force_paid' => AstroBoxPaidType.forcePaid,
      _ => AstroBoxPaidType.free,
    };
  }

  List<String> _splitSemicolon(String? value) {
    if (value == null || value.isEmpty) return [];
    return value
        .split(';')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  String _stripZeroWidth(String input) {
    return input.replaceAll(RegExp('[\u200b\u200c\u200d\u2060\ufeff]'), '');
  }

  List<List<String>> _parseCsvRows(String csv) {
    final lines = const LineSplitter().convert(csv);
    return lines
        .where((line) => line.trim().isNotEmpty)
        .map(_parseCsvLine)
        .toList();
  }

  List<String> _parseCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < line.length; i++) {
      final char = line[i];
      if (char == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buffer.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (char == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(char);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  List<String> _normalizeDeviceKeys(List<String> keys) {
    return keys
        .map(_normalizeDeviceKey)
        .where((key) => key.isNotEmpty)
        .toSet()
        .toList();
  }

  String _normalizeDeviceKey(String key) {
    final codename = normalizeXiaomiWearableCodename(key);
    return codename.isNotEmpty ? codename : key.trim();
  }

  AstroBoxManifest _normalizeManifestDeviceKeys(AstroBoxManifest manifest) {
    final downloads = <String, AstroBoxManifestDownload>{};
    manifest.downloads.forEach((key, value) {
      downloads[_normalizeDeviceKey(key)] = value;
    });
    return manifest.copyWith(downloads: downloads);
  }

  static int? _parseOptionalU64(dynamic value) {
    if (value is int) return value;
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static List<AstroBoxManifestAuthor> _parseAuthors(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(
            (a) => AstroBoxManifestAuthor(
              name: a['name']?.toString() ?? '',
              bindAbAccount: a['bindABAccount'] == true,
            ),
          )
          .where((a) => a.name.isNotEmpty)
          .toList();
    }
    if (raw is String && raw.isNotEmpty) {
      return [AstroBoxManifestAuthor(name: raw)];
    }
    return [];
  }

  AstroBoxManifest _legacyManifestV1ToV2(
    Map<String, dynamic> raw,
    AstroBoxIndexItem item,
  ) {
    final itemMap = raw['item'] as Map<String, dynamic>? ?? {};
    final downloadsMap = raw['downloads'] as Map<String, dynamic>? ?? {};

    final downloads = <String, AstroBoxManifestDownload>{};
    downloadsMap.forEach((key, value) {
      if (value is! Map<String, dynamic>) {
        throw FormatException(
          'download "$key" in ${item.id} manifest is ${value.runtimeType}, expected object',
        );
      }
      final mappedKey = _normalizeDeviceKey(key);
      final versionCode =
          _parseOptionalU64(value['versionCode']) ??
          _parseOptionalU64(value['version_code']);
      downloads[mappedKey] = AstroBoxManifestDownload(
        version: value['version']?.toString() ?? '',
        fileName: value['file_name']?.toString() ?? '',
        versionCode: versionCode,
        url: value['url']?.toString(),
        sha256: value['sha256']?.toString(),
        displayName: value['display_name']?.toString(),
      );
    });

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
        author: authors.isNotEmpty
            ? authors
            : [AstroBoxManifestAuthor(name: item.repoOwner)],
      ),
      downloads: downloads,
    );
  }

  List<String> _toStringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return [];
  }
}

extension _StringExtension on String {
  String trimStartMatches(String prefix) {
    var result = this;
    while (result.startsWith(prefix)) {
      result = result.substring(prefix.length);
    }
    return result;
  }
}
