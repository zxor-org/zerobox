// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'astrobox_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AstroBoxIndexItem _$AstroBoxIndexItemFromJson(Map<String, dynamic> json) =>
    _AstroBoxIndexItem(
      id: json['id'] as String,
      name: json['name'] as String,
      type: $enumDecode(_$AstroBoxResourceTypeEnumMap, json['restype']),
      repoOwner: json['repoOwner'] as String,
      repoName: json['repoName'] as String,
      repoCommitHash: json['repoCommitHash'] as String,
      icon: json['icon'] as String,
      cover: json['cover'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      deviceVendors:
          (json['device_vendors'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      devices:
          (json['devices'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      paidType: $enumDecode(_$AstroBoxPaidTypeEnumMap, json['paid_type']),
    );

Map<String, dynamic> _$AstroBoxIndexItemToJson(_AstroBoxIndexItem instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'restype': _$AstroBoxResourceTypeEnumMap[instance.type]!,
      'repoOwner': instance.repoOwner,
      'repoName': instance.repoName,
      'repoCommitHash': instance.repoCommitHash,
      'icon': instance.icon,
      'cover': instance.cover,
      'tags': instance.tags,
      'device_vendors': instance.deviceVendors,
      'devices': instance.devices,
      'paid_type': _$AstroBoxPaidTypeEnumMap[instance.paidType]!,
    };

const _$AstroBoxResourceTypeEnumMap = {
  AstroBoxResourceType.quickApp: 'quick_app',
  AstroBoxResourceType.watchface: 'watchface',
  AstroBoxResourceType.firmware: 'firmware',
  AstroBoxResourceType.fontpack: 'fontpack',
  AstroBoxResourceType.iconpack: 'iconpack',
};

const _$AstroBoxPaidTypeEnumMap = {
  AstroBoxPaidType.free: 'free',
  AstroBoxPaidType.paid: 'paid',
  AstroBoxPaidType.forcePaid: 'force_paid',
};

_AstroBoxManifest _$AstroBoxManifestFromJson(Map<String, dynamic> json) =>
    _AstroBoxManifest(
      item: AstroBoxManifestItem.fromJson(json['item'] as Map<String, dynamic>),
      links:
          (json['links'] as List<dynamic>?)
              ?.map(
                (e) => AstroBoxManifestLink.fromJson(e as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      downloads:
          (json['downloads'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(
              k,
              AstroBoxManifestDownload.fromJson(e as Map<String, dynamic>),
            ),
          ) ??
          const {},
      ext: json['ext'] as Map<String, dynamic>? ?? const {},
    );

Map<String, dynamic> _$AstroBoxManifestToJson(_AstroBoxManifest instance) =>
    <String, dynamic>{
      'item': instance.item,
      'links': instance.links,
      'downloads': instance.downloads,
      'ext': instance.ext,
    };

_AstroBoxManifestItem _$AstroBoxManifestItemFromJson(
  Map<String, dynamic> json,
) => _AstroBoxManifestItem(
  id: json['id'] as String,
  restype: $enumDecode(_$AstroBoxResourceTypeEnumMap, json['restype']),
  name: json['name'] as String,
  description: json['description'] as String,
  descriptionHtml: json['descriptionHtml'] as String?,
  descriptionBaseUrl: json['descriptionBaseUrl'] as String?,
  preview:
      (json['preview'] as List<dynamic>?)?.map((e) => e as String).toList() ??
      const [],
  icon: json['icon'] as String,
  cover: json['cover'] as String,
  paidType: $enumDecodeNullable(_$AstroBoxPaidTypeEnumMap, json['paidType']),
  author:
      (json['author'] as List<dynamic>?)
          ?.map(
            (e) => AstroBoxManifestAuthor.fromJson(e as Map<String, dynamic>),
          )
          .toList() ??
      const [],
);

Map<String, dynamic> _$AstroBoxManifestItemToJson(
  _AstroBoxManifestItem instance,
) => <String, dynamic>{
  'id': instance.id,
  'restype': _$AstroBoxResourceTypeEnumMap[instance.restype]!,
  'name': instance.name,
  'description': instance.description,
  'descriptionHtml': instance.descriptionHtml,
  'descriptionBaseUrl': instance.descriptionBaseUrl,
  'preview': instance.preview,
  'icon': instance.icon,
  'cover': instance.cover,
  'paidType': _$AstroBoxPaidTypeEnumMap[instance.paidType],
  'author': instance.author,
};

_AstroBoxManifestAuthor _$AstroBoxManifestAuthorFromJson(
  Map<String, dynamic> json,
) => _AstroBoxManifestAuthor(
  name: json['name'] as String,
  bindAbAccount: json['bindABAccount'] as bool? ?? false,
);

Map<String, dynamic> _$AstroBoxManifestAuthorToJson(
  _AstroBoxManifestAuthor instance,
) => <String, dynamic>{
  'name': instance.name,
  'bindABAccount': instance.bindAbAccount,
};

_AstroBoxManifestLink _$AstroBoxManifestLinkFromJson(
  Map<String, dynamic> json,
) => _AstroBoxManifestLink(
  icon: json['icon'] as String?,
  title: json['title'] as String,
  url: json['url'] as String,
);

Map<String, dynamic> _$AstroBoxManifestLinkToJson(
  _AstroBoxManifestLink instance,
) => <String, dynamic>{
  'icon': instance.icon,
  'title': instance.title,
  'url': instance.url,
};

_AstroBoxManifestDownload _$AstroBoxManifestDownloadFromJson(
  Map<String, dynamic> json,
) => _AstroBoxManifestDownload(
  version: json['version'] as String,
  fileName: json['file_name'] as String,
  versionCode: _versionCodeFromJson(json['version_code']),
  url: json['url'] as String?,
  sha256: json['sha256'] as String?,
  displayName: json['displayName'] as String?,
);

Map<String, dynamic> _$AstroBoxManifestDownloadToJson(
  _AstroBoxManifestDownload instance,
) => <String, dynamic>{
  'version': instance.version,
  'file_name': instance.fileName,
  'version_code': instance.versionCode,
  'url': instance.url,
  'sha256': instance.sha256,
  'displayName': instance.displayName,
};

_AstroBoxDeviceMap _$AstroBoxDeviceMapFromJson(Map<String, dynamic> json) =>
    _AstroBoxDeviceMap(
      xiaomi:
          (json['xiaomi'] as Map<String, dynamic>?)?.map(
            (k, e) =>
                MapEntry(k, AstroBoxDevice.fromJson(e as Map<String, dynamic>)),
          ) ??
          const {},
    );

Map<String, dynamic> _$AstroBoxDeviceMapToJson(_AstroBoxDeviceMap instance) =>
    <String, dynamic>{'xiaomi': instance.xiaomi};

_AstroBoxDevice _$AstroBoxDeviceFromJson(Map<String, dynamic> json) =>
    _AstroBoxDevice(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      chip: $enumDecode(_$AstroBoxDeviceChipEnumMap, json['chip']),
      fetch: json['fetch'] as bool? ?? false,
    );

Map<String, dynamic> _$AstroBoxDeviceToJson(_AstroBoxDevice instance) =>
    <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'description': instance.description,
      'chip': _$AstroBoxDeviceChipEnumMap[instance.chip]!,
      'fetch': instance.fetch,
    };

const _$AstroBoxDeviceChipEnumMap = {
  AstroBoxDeviceChip.xring: 'xring',
  AstroBoxDeviceChip.bes: 'bes',
};
