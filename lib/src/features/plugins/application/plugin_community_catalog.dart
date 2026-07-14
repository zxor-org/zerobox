import 'dart:convert';

import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/plugins/application/plugin_manager.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

class PluginCommunityCatalog implements CommunityResourceCatalog {
  PluginCommunityCatalog({required this.manager, required this.sourceId})
    : assert(sourceId.isPlugin);

  final PluginManager manager;

  @override
  final CommunitySourceId sourceId;

  String get _providerName => sourceId.pluginProviderName!;

  @override
  String get displayName => sourceId.displayName;

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(serverSort: true, typeFilter: false);

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final value = await manager.callProvider(_providerName, 'page', [
      jsonEncode(query.page),
      jsonEncode(query.pageSize),
      jsonEncode({
        if (query.query.isNotEmpty) 'filter': query.query,
        'sort': query.sort.name,
        if (query.selectedDevices.isNotEmpty)
          'category': query.selectedDevices.toList(growable: false),
        if (query.hidePaid || query.hideForcePaid) 'hidden_paid': true,
      }),
    ]);
    final rows = _json(value);
    if (rows is! List) {
      throw const FormatException('Plugin provider page must be a list');
    }
    final items = rows
        .whereType<Map>()
        .map((row) => _resource(row.cast<String, Object?>()))
        .where((item) => query.type == null || item.type == query.type)
        .toList(growable: false);
    return CommunityResourcePage(
      items: items,
      page: query.page,
      hasMore: rows.length >= query.pageSize,
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _checkRef(ref);
    final value = await manager.callProvider(_providerName, 'item', [
      jsonEncode(ref.id),
    ]);
    final manifest = _jsonMap(value, 'Plugin provider item');
    final item = _jsonMap(manifest['item'], 'Plugin provider item metadata');
    final resource = _resource(item, fallbackName: ref.id);
    final downloads = _jsonMap(
      manifest['downloads'],
      'Plugin provider downloads',
    );
    final files = downloads.entries
        .map((entry) {
          final download = _jsonMap(entry.value, 'Plugin provider download');
          final device = entry.key;
          return CommunityResourceFile(
            id: device,
            fileName: download['file_name']?.toString() ?? '$device.bin',
            version: download['version']?.toString() ?? '',
            displayName: device,
            supportedDevices: device.isEmpty ? const {} : {device},
          );
        })
        .toList(growable: false);
    return CommunityResourceDetail(
      ref: resource.ref,
      name: resource.name,
      type: resource.type,
      paidType: resource.paidType,
      authors: resource.authors,
      supportedDevices: resource.supportedDevices,
      iconUrl: resource.iconUrl,
      coverUrl: resource.coverUrl,
      summary: resource.summary,
      publicUrl: resource.publicUrl,
      tags: resource.tags,
      content: CommunityResourceContent(
        format: ResourceContentFormat.plainText,
        value: resource.summary,
      ),
      files: files,
      previews: _uris(item['preview']),
      links: resource.publicUrl == null
          ? const []
          : [
              CommunityResourceLink(
                title: resource.publicUrl!.host,
                url: resource.publicUrl!,
              ),
            ],
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final value = await manager.callProvider(
      _providerName,
      'categories',
      const [],
    );
    final categories = _json(value);
    if (categories is! List) return const [];
    return categories
        .map((value) => value.toString())
        .where((value) => value.isNotEmpty)
        .map((value) => CommunityResourceDevice(codename: value, name: value))
        .toList(growable: false);
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    _checkRef(request.resource.ref);
    final value = await manager.callProvider(_providerName, 'download', [
      jsonEncode(request.resource.ref.id),
      jsonEncode(request.targetDevice ?? request.file.id),
      jsonEncode('zerobox-progress'),
    ]);
    final path = _string(value);
    if (path.isEmpty) {
      throw const FormatException('Plugin provider returned no download path');
    }
    request.onProgress?.call(1, status: 'completed');
    return CommunityResourceDownloadResult(
      path: path,
      fileName: manager.virtualFileName(path) ?? request.file.fileName,
      bytes: manager.virtualFileBytes(path),
    );
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async => null;

  CommunityResource _resource(
    Map<String, Object?> json, {
    String? fallbackName,
  }) {
    final name = json['name']?.toString().trim();
    final resolvedName = name?.isNotEmpty == true ? name! : fallbackName ?? '';
    if (resolvedName.isEmpty) {
      throw const FormatException('Plugin provider resource has no name');
    }
    final previews = _uris(json['preview']);
    final icon = _uri(json['icon']);
    final supportedDevice = json['_bandbbs_ext_supported_device']
        ?.toString()
        .trim();
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: resolvedName),
      name: resolvedName,
      type: _resourceType(json['restype']),
      paidType: _paidType(json['paid_type']),
      authors: (json['author'] as List? ?? const [])
          .whereType<Map>()
          .map((raw) {
            final author = raw.cast<String, Object?>();
            return CommunityResourceAuthor(
              name: author['name']?.toString() ?? '',
              url: _uri(author['author_url']),
            );
          })
          .toList(growable: false),
      supportedDevices: supportedDevice?.isNotEmpty == true
          ? {supportedDevice!}
          : const {},
      iconUrl: icon,
      coverUrl: previews.firstOrNull ?? icon,
      summary: json['description']?.toString() ?? '',
      publicUrl: _uri(json['source_url']),
      tags: const [],
    );
  }

  void _checkRef(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw StateError('Resource belongs to another plugin provider');
    }
  }

  Object? _json(Object? value) {
    if (value is! String) return value;
    final text = value.trim();
    if (text.isEmpty) return null;
    return jsonDecode(text);
  }

  Map<String, Object?> _jsonMap(Object? value, String label) {
    final decoded = _json(value);
    if (decoded is! Map) throw FormatException('$label must be an object');
    return decoded.cast<String, Object?>();
  }

  String _string(Object? value) {
    if (value is! String) return value?.toString() ?? '';
    final text = value.trim();
    if (text.startsWith('"') && text.endsWith('"')) {
      final decoded = jsonDecode(text);
      if (decoded is String) return decoded;
    }
    return value;
  }

  CommunityResourceType _resourceType(Object? value) {
    final normalized = value?.toString().toLowerCase().replaceAll('_', '');
    return switch (normalized) {
      'watchface' || 'face' => CommunityResourceType.watchface,
      'firmware' => CommunityResourceType.firmware,
      'fontpack' => CommunityResourceType.fontpack,
      'iconpack' => CommunityResourceType.iconpack,
      _ => CommunityResourceType.quickApp,
    };
  }

  CommunityPaidType _paidType(Object? value) {
    final normalized = value?.toString().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'force_paid' || 'forcepaid' => CommunityPaidType.forcePaid,
      'paid' => CommunityPaidType.paid,
      _ => CommunityPaidType.free,
    };
  }

  List<Uri> _uris(Object? value) =>
      (value as List? ?? const []).map(_uri).nonNulls.toList(growable: false);

  Uri? _uri(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : Uri.tryParse(text);
  }
}
