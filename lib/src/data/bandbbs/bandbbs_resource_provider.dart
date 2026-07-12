import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as crypto;
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pointycastle/export.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_api_client.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

class BandBbsCatalog implements CommunityResourceCatalog {
  BandBbsCatalog({
    required Dio dio,
    required BandBbsAuthNotifier auth,
    this.showAllCategories = false,
  }) : _api = BandBbsApiClient(dio: dio, auth: auth);

  final BandBbsApiClient _api;
  final bool showAllCategories;
  Future<List<_BandBbsCategory>>? _categoryRequest;
  static const _categoryFilterPrefix = 'bandbbs-category:';

  @override
  CommunitySourceId get sourceId => CommunitySourceId.bandbbs;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(
        search: true,
        deviceFilter: true,
        typeFilter: true,
        serverSort: true,
      );

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final categoryIds = await _categoryIdsFor(query.selectedDevices);
    final keyword = query.query.trim();
    final payloads = keyword.isNotEmpty
        ? [
            await _api.searchResources(
              keywords: keyword,
              page: query.page + 1,
              order: query.sort == CommunitySortRule.time
                  ? 'date'
                  : 'relevance',
              categoryIds: categoryIds.isEmpty ? null : categoryIds,
            ),
          ]
        : categoryIds.isEmpty
        ? [
            await _api.getResources(
              page: query.page + 1,
              prefixId: _prefixIdForType(query.type),
              type: query.hidePaid || query.hideForcePaid ? 'free' : null,
              order: _orderForSort(query.sort),
              direction: _directionForSort(query.sort),
            ),
          ]
        : await Future.wait(
            categoryIds.map(
              (id) => _api.getCategoryResources(
                categoryId: id,
                page: query.page + 1,
              ),
            ),
          );

    final resources = <CommunityResource>[];
    final seen = <String>{};
    var hasMore = false;
    var total = 0;
    for (final payload in payloads) {
      final pagination = _objectMap(payload['pagination']);
      final currentPage =
          _intValue(pagination['current_page']) ?? query.page + 1;
      final lastPage = _intValue(pagination['last_page']) ?? currentPage;
      hasMore = hasMore || currentPage < lastPage;
      total += _intValue(pagination['total']) ?? 0;
      final values = payload['resources'] ?? payload['results'];
      if (values is! List) continue;
      for (final value in values.whereType<Map>()) {
        final resource = _summaryFromResource(value.cast<String, dynamic>());
        if (resource == null || !seen.add(resource.ref.key)) continue;
        if (!_matches(resource, query)) continue;
        resources.add(resource);
      }
    }
    return CommunityResourcePage(
      items: resources,
      page: query.page,
      hasMore: hasMore,
      total: total == 0 ? null : total,
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _requireSource(ref);
    final root = await _api.getResource(ref.id);
    return _detailFromResource(_objectMap(root['resource']));
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final categories = await _categories();
    final byParent = <int, List<_BandBbsCategory>>{};
    for (final category in categories) {
      byParent.putIfAbsent(category.parentId, () => []).add(category);
    }
    final blockedIds = <int>{};
    void markBlocked(_BandBbsCategory category) {
      if (!blockedIds.add(category.id)) return;
      for (final child in byParent[category.id] ?? const []) {
        markBlocked(child);
      }
    }

    for (final category in categories) {
      if (!showAllCategories && _isBlockedCategory(category.title)) {
        markBlocked(category);
      }
    }
    return categories
        .where(
          (category) =>
              category.title.isNotEmpty &&
              category.resourceCount > 0 &&
              !blockedIds.contains(category.id),
        )
        .map(
          (category) => CommunityResourceDevice(
            codename: '$_categoryFilterPrefix${category.id}',
            name: category.title,
            description: category.codename,
          ),
        )
        .toList();
  }

  /// Categories not worth surfacing: Xiaomi Band 6 and older, plus
  /// non-Xiaomi/misc sections.
  static bool _isBlockedCategory(String title) {
    const blockedTitles = {'BlueOS穿戴系列', '安卓智能手表', '黑加手环', '小米手表Color', '论坛杂务'};
    const blockedBrands = ['荣耀', '华为', '黑鲨'];
    if (blockedTitles.contains(title)) return true;
    if (blockedBrands.any(title.contains)) return true;
    final match = RegExp(r'小米手环\s*(\d+)').firstMatch(title);
    if (match == null) return false;
    final generation = int.tryParse(match.group(1)!);
    return generation != null && generation <= 6;
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    final url = request.file.downloadUrl;
    if (url == null) {
      throw StateError('BandBBS resource file has no download URL');
    }
    request.onProgress?.call(0);
    final response = await _api.downloadFile(
      url.toString(),
      onReceiveProgress: (received, total) {
        if (total > 0) request.onProgress?.call((received / total) * 0.55);
      },
    );
    final encrypted = Uint8List.fromList(response.data ?? const []);
    if (encrypted.isEmpty) {
      throw StateError('BandBBS resource download returned empty data');
    }
    final payload = await _decryptIfLicensed(
      resourceId: request.resource.ref.id,
      encryptedBytes: encrypted,
      onProgress: request.onProgress,
    );
    final fileName = _sanitizeFileName(
      payload.fileName.trim().isEmpty
          ? request.file.fileName
          : payload.fileName,
    );
    request.onProgress?.call(1, status: 'finished');
    if (kIsWeb) {
      return CommunityResourceDownloadResult(
        path: '/zerobox_downloads/$fileName',
        fileName: fileName,
        bytes: payload.bytes,
      );
    }
    final directory = Directory(
      '${(await getTemporaryDirectory()).path}/zerobox_downloads/${request.resource.ref.id}',
    );
    await directory.create(recursive: true);
    final path = '${directory.path}/$fileName';
    await File(path).writeAsBytes(payload.bytes, flush: true);
    return CommunityResourceDownloadResult(path: path, fileName: fileName);
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async {
    if (file.size != null) return file.size;
    if (file.downloadUrl == null) return null;
    final response = await _api.headFile(file.downloadUrl.toString());
    return int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
  }

  Future<List<_BandBbsCategory>> _categories() {
    return _categoryRequest ??= _loadCategories();
  }

  Future<List<_BandBbsCategory>> _loadCategories() async {
    final root = await _api.getFlattenedCategories();
    final raw =
        root['categories_flat'] ??
        root['resource_categories'] ??
        root['categories'] ??
        root['resourceCategories'];
    final values = raw is List
        ? raw.whereType<Map>()
        : raw is Map
        ? raw.values.whereType<Map>()
        : const Iterable<Map<dynamic, dynamic>>.empty();
    return values
        .map((entry) {
          final value = entry.cast<String, dynamic>();
          final map = _objectMap(value['category'] ?? value);
          final title = map['title']?.toString().trim() ?? '';
          return _BandBbsCategory(
            id: _intValue(map['resource_category_id']) ?? 0,
            title: title,
            codename: normalizeXiaomiWearableCodename(title),
            resourceCount: _intValue(map['resource_count']) ?? 0,
            parentId: _intValue(map['parent_category_id']) ?? 0,
            depth: _intValue(value['depth']) ?? 0,
          );
        })
        .where((category) => category.id > 0)
        .toList();
  }

  /// Builds the category tree (up to three levels) with aggregate resource
  /// counts, pruning branches that contain no resources.
  Future<List<BandBbsCategoryNode>> getCategoryTree() async {
    final categories = await _categories();
    final roots = <_NodeHolder>[];
    final stack = <_NodeHolder>[];
    for (final category in categories) {
      final holder = _NodeHolder(category);
      while (stack.isNotEmpty && stack.last.category.depth >= category.depth) {
        stack.removeLast();
      }
      if (stack.isEmpty) {
        roots.add(holder);
      } else {
        stack.last.children.add(holder);
      }
      stack.add(holder);
    }
    int aggregate(_NodeHolder holder) {
      if (!showAllCategories && _isBlockedCategory(holder.category.title)) {
        holder.children = const [];
        holder.aggregate = 0;
        return 0;
      }
      var sum = holder.category.resourceCount;
      final kept = <_NodeHolder>[];
      for (final child in holder.children) {
        final childSum = aggregate(child);
        if (childSum > 0) {
          kept.add(child);
          sum += childSum;
        }
      }
      holder.children = kept;
      holder.aggregate = sum;
      return sum;
    }

    BandBbsCategoryNode convert(_NodeHolder holder) => BandBbsCategoryNode(
      id: holder.category.id,
      title: holder.category.title,
      resourceCount: holder.aggregate,
      children: [for (final child in holder.children) convert(child)],
    );

    return [
      for (final root in roots)
        if (aggregate(root) > 0) convert(root),
    ];
  }

  Future<List<int>> _categoryIdsFor(Set<String> requested) async {
    if (requested.isEmpty) return const [];
    final explicitIds = requested
        .where((value) => value.startsWith(_categoryFilterPrefix))
        .map(
          (value) =>
              int.tryParse(value.substring(_categoryFilterPrefix.length)),
        )
        .whereType<int>()
        .where((id) => id > 0)
        .toSet();
    if (explicitIds.isNotEmpty) {
      return explicitIds.toList();
    }

    final wanted = requested
        .map(normalizeXiaomiWearableCodename)
        .where((id) => id.isNotEmpty)
        .toSet();
    return (await _categories())
        .where((category) => wanted.contains(category.codename))
        .map((category) => category.id)
        .toSet()
        .toList();
  }

  CommunityResource? _summaryFromResource(Map<String, dynamic> resource) {
    final id = resource['resource_id']?.toString() ?? '';
    final name = resource['title']?.toString().trim() ?? '';
    final type = _typeFromResource(resource);
    if (id.isEmpty || name.isEmpty || type == null) return null;
    final category = _objectMap(resource['Category']);
    final codename = normalizeXiaomiWearableCodename(
      category['title']?.toString() ?? '',
    );
    final icon = _uri(resource['icon_url']);
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: id),
      name: name,
      type: type,
      paidType: _paidFromResource(resource),
      authors: _authorsFromResource(resource),
      supportedDevices: codename.isEmpty ? const {} : {codename},
      iconUrl: icon,
      coverUrl: icon,
      summary: resource['tag_line']?.toString().trim() ?? '',
      updatedAt: _dateFromUnix(resource['last_update']),
      publicUrl: _uri(resource['view_url']),
      tags: _tagsFromResource(resource, category),
      downloadCount: _intValue(resource['download_count']),
      version: resource['version']?.toString(),
      priceLabel: _priceLabelFromResource(resource),
    );
  }

  CommunityResourceDetail _detailFromResource(Map<String, dynamic> resource) {
    final summary = _summaryFromResource(resource);
    if (summary == null) {
      throw const FormatException(
        'BandBBS resource response missing identity or type',
      );
    }
    final files = <CommunityResourceFile>[];
    for (final value in _files(resource)) {
      final fileName = value['filename']?.toString() ?? '';
      if (fileName.isEmpty) {
        continue;
      }
      final id = value['id']?.toString() ?? fileName;
      final codename = normalizeXiaomiWearableCodename(fileName);
      files.add(
        CommunityResourceFile(
          id: id,
          fileName: fileName,
          displayName: fileName,
          version: resource['version']?.toString() ?? '',
          downloadUrl: _uri(value['download_url']),
          size: _intValue(value['size']),
          supportedDevices: codename.isEmpty
              ? summary.supportedDevices
              : {codename},
        ),
      );
    }
    final html = resource['description_parsed']?.toString().trim() ?? '';
    final raw = resource['description']?.toString().trim() ?? '';
    final previewImages = _previews(resource);
    return CommunityResourceDetail(
      ref: summary.ref,
      name: summary.name,
      type: summary.type,
      paidType: summary.paidType,
      authors: summary.authors,
      supportedDevices: summary.supportedDevices,
      iconUrl: summary.iconUrl,
      coverUrl: summary.coverUrl,
      summary: summary.summary,
      updatedAt: summary.updatedAt,
      publicUrl: summary.publicUrl,
      tags: summary.tags,
      downloadCount: summary.downloadCount,
      version: summary.version,
      priceLabel: summary.priceLabel,
      content: CommunityResourceContent(
        format: html.isNotEmpty
            ? ResourceContentFormat.html
            : ResourceContentFormat.plainText,
        value: html.isNotEmpty ? html : raw,
        baseUri: Uri.parse('https://www.bandbbs.cn/'),
      ),
      previews: previewImages.map((image) => image.url).toList(),
      previewImages: previewImages,
      links: _linksFromResource(resource, summary),
      files: files,
      canDownload: resource['can_download'] == true,
    );
  }

  List<CommunityResourceLink> _linksFromResource(
    Map<String, dynamic> resource,
    CommunityResource summary,
  ) {
    final links = <CommunityResourceLink>[];
    final purchase = _uri(resource['external_purchase_url']);
    if (purchase != null) {
      links.add(
        CommunityResourceLink(title: '购买 (${purchase.host})', url: purchase),
      );
    }
    final external = _uri(resource['external_url']);
    if (external != null) {
      links.add(CommunityResourceLink(title: external.host, url: external));
    }
    if (summary.publicUrl != null) {
      links.add(
        CommunityResourceLink(title: 'BandBBS', url: summary.publicUrl!),
      );
    }
    return links;
  }

  bool _matches(CommunityResource item, CommunityResourceQuery query) {
    if (query.type != null && item.type != query.type) {
      return false;
    }
    if (query.hidePaid && item.paidType == CommunityPaidType.paid) {
      return false;
    }
    if (query.hideForcePaid && item.paidType == CommunityPaidType.forcePaid) {
      return false;
    }
    final selectedDeviceIds = query.selectedDevices
        .where((value) => !value.startsWith(_categoryFilterPrefix))
        .toSet();
    if (selectedDeviceIds.isNotEmpty &&
        item.supportedDevices.intersection(selectedDeviceIds).isEmpty) {
      return false;
    }
    return true;
  }

  CommunityResourceType? _typeFromResource(Map<String, dynamic> resource) {
    switch (_intValue(resource['prefix_id'])) {
      case 81:
        return CommunityResourceType.watchface;
      case 82:
        return CommunityResourceType.quickApp;
      case 85:
        return CommunityResourceType.firmware;
    }
    final prefix = resource['prefix']?.toString().toLowerCase() ?? '';
    if (prefix.contains('小程序') ||
        prefix.contains('快应用') ||
        prefix.contains('quick')) {
      return CommunityResourceType.quickApp;
    }
    if (prefix.contains('表盘') || prefix.contains('watchface')) {
      return CommunityResourceType.watchface;
    }
    if (prefix.contains('固件') || prefix.contains('firmware')) {
      return CommunityResourceType.firmware;
    }
    if (prefix.contains('字体') || prefix.contains('font')) {
      return CommunityResourceType.fontpack;
    }
    if (prefix.contains('图标') || prefix.contains('icon')) {
      return CommunityResourceType.iconpack;
    }
    return null;
  }

  CommunityPaidType _paidFromResource(Map<String, dynamic> resource) {
    final price = double.tryParse(resource['price']?.toString() ?? '') ?? 0;
    return price > 0 ? CommunityPaidType.paid : CommunityPaidType.free;
  }

  String? _priceLabelFromResource(Map<String, dynamic> resource) {
    final raw = resource['price']?.toString() ?? '';
    final price = double.tryParse(raw);
    if (price == null || price <= 0) return null;
    final symbol = switch (resource['currency']?.toString()) {
      'CNY' => '¥',
      'USD' => '\$',
      _ => '',
    };
    return '$symbol$raw';
  }

  List<String> _tagsFromResource(
    Map<String, dynamic> resource,
    Map<String, dynamic> category,
  ) {
    final values = <String>[
      category['title']?.toString().trim() ?? '',
      ..._stringList(resource['tags']),
    ];
    final seen = <String>{};
    return values.where((value) {
      final key = value.toLowerCase();
      return key.isNotEmpty && seen.add(key);
    }).toList();
  }

  List<CommunityResourceAuthor> _authorsFromResource(
    Map<String, dynamic> resource,
  ) {
    final user = _objectMap(resource['User']);
    final name =
        user['username']?.toString() ?? resource['username']?.toString() ?? '';
    if (name.isEmpty) return const [];
    final avatars = _objectMap(user['avatar_urls']);
    return [
      CommunityResourceAuthor(
        name: name,
        url: _uri(user['view_url']),
        avatarUrl: _uri(avatars['m']),
      ),
    ];
  }

  List<Map<String, dynamic>> _files(Map<String, dynamic> resource) =>
      resource['current_files'] is List
      ? (resource['current_files'] as List)
            .whereType<Map>()
            .map((entry) => entry.cast<String, dynamic>())
            .toList()
      : const [];

  List<CommunityResourceImage> _previews(Map<String, dynamic> resource) {
    if (resource['DescriptionAttachments'] is! List) return const [];
    return (resource['DescriptionAttachments'] as List)
        .whereType<Map>()
        .map((entry) => entry.cast<String, dynamic>())
        .map((entry) {
          final url = _uri(entry['direct_url']) ?? _uri(entry['thumbnail_url']);
          if (url == null) return null;
          return CommunityResourceImage(
            url: url,
            thumbnailUrl: _uri(entry['thumbnail_url']),
            width: _intValue(entry['width']),
            height: _intValue(entry['height']),
          );
        })
        .whereType<CommunityResourceImage>()
        .toList();
  }

  Future<_BandBbsPayload> _decryptIfLicensed({
    required String resourceId,
    required Uint8List encryptedBytes,
    void Function(double progress, {String status})? onProgress,
  }) async {
    final license = await _api.checkLicense(resourceId);
    if (!license.valid) {
      return _BandBbsPayload(bytes: encryptedBytes, fileName: '');
    }
    onProgress?.call(0.65, status: 'checking_license');
    final info = await _api.getDecryptInfo(
      encryptedFileHash: crypto.sha256.convert(encryptedBytes).toString(),
      verifyLicense: license.license,
      licenseIv: license.iv,
    );
    final decrypted = _aesGcmDecrypt(
      key: _decodeBinary(info.decryptToken),
      iv: _decodeBinary(info.decryptIv),
      tag: _decodeBinary(info.authTag),
      ciphertext: encryptedBytes,
    );
    final actualHash = crypto.sha256.convert(decrypted).toString();
    if (info.decryptedFileHash.isNotEmpty &&
        actualHash.toLowerCase() != info.decryptedFileHash.toLowerCase()) {
      throw StateError('BandBBS decrypted file hash mismatch');
    }
    onProgress?.call(0.9, status: 'decrypting');
    return _BandBbsPayload(bytes: decrypted, fileName: info.fileName);
  }

  Uint8List _aesGcmDecrypt({
    required Uint8List key,
    required Uint8List iv,
    required Uint8List tag,
    required Uint8List ciphertext,
  }) {
    if (key.length != 32 || tag.length != 16) {
      throw StateError('BandBBS decrypt payload is invalid');
    }
    final cipher = GCMBlockCipher(AESEngine())
      ..init(false, AEADParameters(KeyParameter(key), 128, iv, Uint8List(0)));
    final input = Uint8List(ciphertext.length + tag.length)
      ..setRange(0, ciphertext.length, ciphertext)
      ..setRange(ciphertext.length, ciphertext.length + tag.length, tag);
    final output = Uint8List(cipher.getOutputSize(input.length));
    var written = cipher.processBytes(input, 0, input.length, output, 0);
    written += cipher.doFinal(output, written);
    return Uint8List.sublistView(output, 0, written);
  }

  Uint8List _decodeBinary(String value) {
    final text = value.trim();
    if (RegExp(r'^[0-9a-fA-F]+$').hasMatch(text) && text.length.isEven) {
      return Uint8List.fromList([
        for (var i = 0; i < text.length; i += 2)
          int.parse(text.substring(i, i + 2), radix: 16),
      ]);
    }
    return Uint8List.fromList(base64.decode(text));
  }

  int? _prefixIdForType(CommunityResourceType? value) => switch (value) {
    CommunityResourceType.watchface => 81,
    CommunityResourceType.quickApp => 82,
    CommunityResourceType.firmware => 85,
    _ => null,
  };

  String _orderForSort(CommunitySortRule value) => switch (value) {
    CommunitySortRule.name => 'title',
    CommunitySortRule.time || CommunitySortRule.random => 'last_update',
  };

  String _directionForSort(CommunitySortRule value) => switch (value) {
    CommunitySortRule.name => 'asc',
    CommunitySortRule.time || CommunitySortRule.random => 'desc',
  };

  Map<String, dynamic> _objectMap(Object? value) =>
      value is Map<String, dynamic>
      ? value
      : value is Map
      ? value.cast<String, dynamic>()
      : const {};

  List<String> _stringList(Object? value) =>
      value is List ? value.map((item) => item.toString()).toList() : const [];
  int? _intValue(Object? value) =>
      value is int ? value : int.tryParse(value?.toString() ?? '');
  Uri? _uri(Object? value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    return uri.hasScheme
        ? uri
        : Uri.parse('https://www.bandbbs.cn').resolveUri(uri);
  }

  DateTime? _dateFromUnix(Object? value) {
    final seconds = _intValue(value);
    return seconds == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(seconds * 1000);
  }

  String _sanitizeFileName(String value) {
    final result = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    return result.isEmpty ? 'bandbbs-resource.bin' : result;
  }

  void _requireSource(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw ArgumentError.value(ref, 'ref', 'Wrong resource source');
    }
  }
}

class _BandBbsCategory {
  const _BandBbsCategory({
    required this.id,
    required this.title,
    required this.codename,
    required this.resourceCount,
    required this.parentId,
    required this.depth,
  });
  final int id;
  final String title;
  final String codename;
  final int resourceCount;
  final int parentId;
  final int depth;
}

class _NodeHolder {
  _NodeHolder(this.category);
  final _BandBbsCategory category;
  List<_NodeHolder> children = [];
  int aggregate = 0;
}

/// A node of the BandBBS resource category tree, with [resourceCount]
/// aggregated over the whole subtree.
class BandBbsCategoryNode {
  const BandBbsCategoryNode({
    required this.id,
    required this.title,
    required this.resourceCount,
    this.children = const [],
  });

  final int id;
  final String title;
  final int resourceCount;
  final List<BandBbsCategoryNode> children;
}

class _BandBbsPayload {
  const _BandBbsPayload({required this.bytes, required this.fileName});
  final Uint8List bytes;
  final String fileName;
}
