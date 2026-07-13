import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';

Map<String, Object?> communityResourceFileToJson(CommunityResourceFile file) =>
    {
      'id': file.id,
      'fileName': file.fileName,
      'version': file.version,
      if (file.displayName != null) 'displayName': file.displayName,
      if (file.downloadUrl != null) 'downloadUrl': file.downloadUrl.toString(),
      if (file.size != null) 'size': file.size,
      'devices': file.supportedDevices.toList(growable: false),
    };

CommunityResourceFile communityResourceFileFromJson(
  Map<String, Object?> json,
) => CommunityResourceFile(
  id: json['id']?.toString() ?? '',
  fileName: json['fileName']?.toString() ?? '',
  version: json['version']?.toString() ?? '',
  displayName: json['displayName']?.toString(),
  downloadUrl: _uri(json['downloadUrl']),
  size: (json['size'] as num?)?.toInt(),
  supportedDevices: _strings(json['devices']).toSet(),
);

Map<String, Object?> communityResourceToJson(CommunityResource resource) => {
  'ref': resource.ref.key,
  'name': resource.name,
  'type': resource.type.name,
  'paidType': resource.paidType.name,
  'authors': resource.authors
      .map(
        (author) => {
          'name': author.name,
          if (author.url != null) 'url': author.url.toString(),
          if (author.avatarUrl != null)
            'avatarUrl': author.avatarUrl.toString(),
        },
      )
      .toList(growable: false),
  'devices': resource.supportedDevices.toList(growable: false),
  if (resource.iconUrl != null) 'iconUrl': resource.iconUrl.toString(),
  if (resource.coverUrl != null) 'coverUrl': resource.coverUrl.toString(),
  if (resource.summary.isNotEmpty) 'summary': resource.summary,
  if (resource.updatedAt != null)
    'updatedAt': resource.updatedAt!.toIso8601String(),
  if (resource.publicUrl != null) 'publicUrl': resource.publicUrl.toString(),
  if (resource.tags.isNotEmpty) 'tags': resource.tags,
  if (resource.downloadCount != null) 'downloadCount': resource.downloadCount,
  if (resource.version != null) 'version': resource.version,
  if (resource.priceLabel != null) 'priceLabel': resource.priceLabel,
};

Map<String, Object?> communityResourceDetailToJson(
  CommunityResourceDetail detail,
) => {
  ...communityResourceToJson(detail),
  'content': {
    'format': detail.content.format.name,
    'value': detail.content.value,
    if (detail.content.baseUri != null)
      'baseUri': detail.content.baseUri.toString(),
  },
  'files': detail.files
      .map(communityResourceFileToJson)
      .toList(growable: false),
  'previews': detail.previews.map((uri) => uri.toString()).toList(),
  'previewImages': detail.previewImages
      .map(
        (image) => {
          'url': image.url.toString(),
          if (image.thumbnailUrl != null)
            'thumbnailUrl': image.thumbnailUrl.toString(),
          if (image.width != null) 'width': image.width,
          if (image.height != null) 'height': image.height,
        },
      )
      .toList(growable: false),
  'links': detail.links
      .map((link) => {'title': link.title, 'url': link.url.toString()})
      .toList(growable: false),
  'canDownload': detail.canDownload,
};

CommunityResource communityResourceFromJson(Map<String, Object?> json) {
  final common = _common(json);
  return CommunityResource(
    ref: common.ref,
    name: common.name,
    type: common.type,
    paidType: common.paidType,
    authors: common.authors,
    supportedDevices: common.supportedDevices,
    iconUrl: common.iconUrl,
    coverUrl: common.coverUrl,
    summary: common.summary,
    updatedAt: common.updatedAt,
    publicUrl: common.publicUrl,
    tags: common.tags,
    downloadCount: common.downloadCount,
    version: common.version,
    priceLabel: common.priceLabel,
  );
}

CommunityResourceDetail communityResourceDetailFromJson(
  Map<String, Object?> json,
) {
  final common = _common(json);
  final content = _map(json['content']);
  return CommunityResourceDetail(
    ref: common.ref,
    name: common.name,
    type: common.type,
    paidType: common.paidType,
    authors: common.authors,
    supportedDevices: common.supportedDevices,
    iconUrl: common.iconUrl,
    coverUrl: common.coverUrl,
    summary: common.summary,
    updatedAt: common.updatedAt,
    publicUrl: common.publicUrl,
    tags: common.tags,
    downloadCount: common.downloadCount,
    version: common.version,
    priceLabel: common.priceLabel,
    content: CommunityResourceContent(
      format: _enum(ResourceContentFormat.values, content['format']),
      value: content['value']?.toString() ?? '',
      baseUri: _uri(content['baseUri']),
    ),
    files: _list(
      json['files'],
    ).map((row) => communityResourceFileFromJson(_map(row))).toList(),
    previews: _strings(json['previews']).map(Uri.parse).toList(),
    previewImages: _list(json['previewImages']).map((row) {
      final image = _map(row);
      return CommunityResourceImage(
        url: Uri.parse(image['url']!.toString()),
        thumbnailUrl: _uri(image['thumbnailUrl']),
        width: (image['width'] as num?)?.toInt(),
        height: (image['height'] as num?)?.toInt(),
      );
    }).toList(),
    links: _list(json['links']).map((row) {
      final link = _map(row);
      return CommunityResourceLink(
        title: link['title']?.toString() ?? '',
        url: Uri.parse(link['url']!.toString()),
      );
    }).toList(),
    canDownload: json['canDownload'] != false,
  );
}

ResourceRef resourceRefFromKey(String key) {
  final separator = key.indexOf(':');
  if (separator <= 0 || separator == key.length - 1) {
    throw FormatException('Invalid resource ref', key);
  }
  final source = communitySourceIdByName(key.substring(0, separator));
  if (source == null) throw FormatException('Unknown resource source', key);
  return ResourceRef(source: source, id: key.substring(separator + 1));
}

class _CommonResourceFields {
  const _CommonResourceFields({
    required this.ref,
    required this.name,
    required this.type,
    required this.paidType,
    required this.authors,
    required this.supportedDevices,
    required this.summary,
    required this.tags,
    this.iconUrl,
    this.coverUrl,
    this.updatedAt,
    this.publicUrl,
    this.downloadCount,
    this.version,
    this.priceLabel,
  });

  final ResourceRef ref;
  final String name;
  final CommunityResourceType type;
  final CommunityPaidType paidType;
  final List<CommunityResourceAuthor> authors;
  final Set<String> supportedDevices;
  final Uri? iconUrl;
  final Uri? coverUrl;
  final String summary;
  final DateTime? updatedAt;
  final Uri? publicUrl;
  final List<String> tags;
  final int? downloadCount;
  final String? version;
  final String? priceLabel;
}

_CommonResourceFields _common(Map<String, Object?> json) =>
    _CommonResourceFields(
      ref: resourceRefFromKey(json['ref']!.toString()),
      name: json['name']?.toString() ?? '',
      type: _enum(CommunityResourceType.values, json['type']),
      paidType: _enum(CommunityPaidType.values, json['paidType']),
      authors: _list(json['authors']).map((row) {
        final author = row is Map ? _map(row) : {'name': row};
        return CommunityResourceAuthor(
          name: author['name']?.toString() ?? '',
          url: _uri(author['url']),
          avatarUrl: _uri(author['avatarUrl']),
        );
      }).toList(),
      supportedDevices: _strings(json['devices']).toSet(),
      iconUrl: _uri(json['iconUrl']),
      coverUrl: _uri(json['coverUrl']),
      summary: json['summary']?.toString() ?? '',
      updatedAt: DateTime.tryParse(json['updatedAt']?.toString() ?? ''),
      publicUrl: _uri(json['publicUrl']),
      tags: _strings(json['tags']),
      downloadCount: (json['downloadCount'] as num?)?.toInt(),
      version: json['version']?.toString(),
      priceLabel: json['priceLabel']?.toString(),
    );

T _enum<T extends Enum>(List<T> values, Object? raw) => values.firstWhere(
  (value) => value.name == raw?.toString(),
  orElse: () => values.first,
);

Map<String, Object?> _map(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};
List<Object?> _list(Object? value) => value is List ? value : const [];
List<String> _strings(Object? value) =>
    _list(value).map((item) => item.toString()).toList();
Uri? _uri(Object? value) {
  final raw = value?.toString() ?? '';
  return raw.isEmpty ? null : Uri.tryParse(raw);
}
