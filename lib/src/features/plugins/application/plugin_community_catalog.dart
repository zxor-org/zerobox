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

  String get _providerId => sourceId.pluginProviderName!;

  @override
  String get displayName => manager.providerDisplayName(_providerId);

  @override
  CommunityCatalogCapabilities get capabilities =>
      const CommunityCatalogCapabilities(serverSort: true);

  @override
  Future<CommunityResourcePage> getPage(CommunityResourceQuery query) async {
    final value = await manager.callProvider(_providerId, 'query', [
      {
        'page': query.page,
        'pageSize': query.pageSize,
        'query': query.query,
        'sort': query.sort.name,
        if (query.type != null) 'type': query.type!.name,
        'hidePaid': query.hidePaid,
        'hideForcePaid': query.hideForcePaid,
        'selectedDevices': query.selectedDevices.toList(growable: false),
      },
    ]);
    final page = _map(value, 'Plugin provider query result');
    final rows = page['items'];
    if (rows is! List) {
      throw const FormatException('Plugin provider items must be a list');
    }
    return CommunityResourcePage(
      items: rows
          .map((row) => _resource(_map(row, 'Plugin provider resource')))
          .toList(growable: false),
      page: query.page,
      hasMore: page['hasMore'] == true,
      total: (page['total'] as num?)?.toInt(),
    );
  }

  @override
  Future<CommunityResourceDetail> getDetail(ResourceRef ref) async {
    _checkRef(ref);
    final value = await manager.callProvider(_providerId, 'detail', [
      {'id': ref.id},
    ]);
    final json = _map(value, 'Plugin provider detail');
    final resource = _resource(json);
    final content = _mapOrEmpty(json['content']);
    final files = (json['files'] as List? ?? const [])
        .map((value) {
          final file = _map(value, 'Plugin provider file');
          return CommunityResourceFile(
            id: _required(file, 'id'),
            fileName: _required(file, 'fileName'),
            version: file['version']?.toString() ?? '',
            displayName: file['displayName']?.toString(),
            size: (file['size'] as num?)?.toInt(),
            supportedDevices: _strings(file['supportedDevices']),
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
      version: resource.version,
      priceLabel: resource.priceLabel,
      content: CommunityResourceContent(
        format: content['format']?.toString() == 'html'
            ? ResourceContentFormat.html
            : ResourceContentFormat.plainText,
        value: content['value']?.toString() ?? resource.summary,
        baseUri: _uri(content['baseUrl']),
      ),
      files: files,
      previews: _uris(json['previews']),
      links: (json['links'] as List? ?? const [])
          .map((value) {
            final link = _map(value, 'Plugin provider link');
            final url = _uri(link['url']);
            if (url == null) {
              throw const FormatException('Plugin provider link has no URL');
            }
            return CommunityResourceLink(
              title: _required(link, 'title'),
              url: url,
            );
          })
          .toList(growable: false),
      canDownload: json['canDownload'] != false,
    );
  }

  @override
  Future<List<CommunityResourceDevice>> getDevices() async {
    final value = await manager.callProvider(
      _providerId,
      'categories',
      const [],
    );
    if (value is! List) {
      throw const FormatException('Plugin provider categories must be a list');
    }
    return value
        .map((value) {
          final category = _map(value, 'Plugin provider category');
          return CommunityResourceDevice(
            codename: _required(category, 'id'),
            name: _required(category, 'name'),
            description: category['description']?.toString() ?? '',
          );
        })
        .toList(growable: false);
  }

  @override
  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  ) async {
    _checkRef(request.resource.ref);
    final value = await manager.callProvider(_providerId, 'download', [
      {
        'id': request.resource.ref.id,
        'fileId': request.file.id,
        if (request.targetDevice != null) 'targetDevice': request.targetDevice,
      },
    ]);
    final result = _map(value, 'Plugin provider download result');
    final path = _required(result, 'path');
    final bytes = await manager.readProviderFile(_providerId, path);
    request.onProgress?.call(1, status: 'completed');
    return CommunityResourceDownloadResult(
      path: path,
      fileName:
          result['fileName']?.toString() ??
          path.split('/').lastOrNull ??
          request.file.fileName,
      bytes: bytes,
    );
  }

  @override
  Future<int?> probeDownloadSize(CommunityResourceFile file) async => file.size;

  CommunityResource _resource(Map<String, Object?> json) {
    final id = _required(json, 'id');
    return CommunityResource(
      ref: ResourceRef(source: sourceId, id: id),
      name: _required(json, 'name'),
      type: _resourceType(json['type']),
      paidType: _paidType(json['paidType']),
      authors: (json['authors'] as List? ?? const [])
          .map((value) {
            final author = _map(value, 'Plugin provider author');
            return CommunityResourceAuthor(
              name: _required(author, 'name'),
              url: _uri(author['url']),
              avatarUrl: _uri(author['avatarUrl']),
            );
          })
          .toList(growable: false),
      supportedDevices: _strings(json['supportedDevices']),
      iconUrl: _uri(json['iconUrl']),
      coverUrl: _uri(json['coverUrl']),
      summary: json['summary']?.toString() ?? '',
      publicUrl: _uri(json['publicUrl']),
      tags: _strings(json['tags']).toList(growable: false),
      version: json['version']?.toString(),
      priceLabel: json['priceLabel']?.toString(),
    );
  }

  void _checkRef(ResourceRef ref) {
    if (ref.source != sourceId) {
      throw StateError('Resource belongs to another plugin provider');
    }
  }

  Map<String, Object?> _map(Object? value, String label) {
    if (value is! Map) throw FormatException('$label must be an object');
    return value.cast<String, Object?>();
  }

  Map<String, Object?> _mapOrEmpty(Object? value) =>
      value is Map ? value.cast<String, Object?>() : const {};

  String _required(Map<String, Object?> json, String key) {
    final value = json[key]?.toString().trim() ?? '';
    if (value.isEmpty) {
      throw FormatException('Plugin provider $key is required');
    }
    return value;
  }

  Set<String> _strings(Object? value) =>
      (value as List? ?? const []).map((item) => item.toString()).toSet();

  CommunityResourceType _resourceType(Object? value) => switch (value) {
    'watchface' => CommunityResourceType.watchface,
    'firmware' => CommunityResourceType.firmware,
    'fontpack' => CommunityResourceType.fontpack,
    'iconpack' => CommunityResourceType.iconpack,
    'quickApp' || 'quickapp' => CommunityResourceType.quickApp,
    _ => throw FormatException('Unsupported plugin resource type: $value'),
  };

  CommunityPaidType _paidType(Object? value) => switch (value) {
    null || 'free' => CommunityPaidType.free,
    'paid' => CommunityPaidType.paid,
    'forcePaid' => CommunityPaidType.forcePaid,
    _ => throw FormatException('Unsupported plugin paid type: $value'),
  };

  List<Uri> _uris(Object? value) =>
      (value as List? ?? const []).map(_uri).nonNulls.toList(growable: false);

  Uri? _uri(Object? value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : Uri.tryParse(text);
  }
}
