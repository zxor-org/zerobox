import 'dart:typed_data';

import 'package:zerobox/src/data/community/community_source.dart';

enum CommunityResourceType { quickApp, watchface, firmware, fontpack, iconpack }

enum CommunityPaidType { free, paid, forcePaid }

enum ResourceContentFormat { plainText, html }

class ResourceRef {
  const ResourceRef({required this.source, required this.id});

  final CommunitySourceId source;
  final String id;

  String get key => '${source.storageKey}:$id';

  @override
  bool operator ==(Object other) =>
      other is ResourceRef && other.source == source && other.id == id;

  @override
  int get hashCode => Object.hash(source, id);
}

class CommunityResourceAuthor {
  const CommunityResourceAuthor({required this.name, this.url, this.avatarUrl});

  final String name;
  final Uri? url;
  final Uri? avatarUrl;
}

class CommunityResourceLink {
  const CommunityResourceLink({required this.title, required this.url});

  final String title;
  final Uri url;
}

class CommunityResourceFile {
  const CommunityResourceFile({
    required this.id,
    required this.fileName,
    required this.version,
    this.displayName,
    this.downloadUrl,
    this.size,
    this.supportedDevices = const {},
  });

  final String id;
  final String fileName;
  final String version;
  final String? displayName;
  final Uri? downloadUrl;
  final int? size;
  final Set<String> supportedDevices;

  String get label =>
      displayName?.trim().isNotEmpty == true ? displayName!.trim() : fileName;
}

class CommunityResource {
  const CommunityResource({
    required this.ref,
    required this.name,
    required this.type,
    required this.paidType,
    required this.authors,
    required this.supportedDevices,
    this.iconUrl,
    this.coverUrl,
    this.summary = '',
    this.updatedAt,
    this.publicUrl,
    this.tags = const [],
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

  String get authorName => authors.firstOrNull?.name ?? '';
}

class CommunityResourceContent {
  const CommunityResourceContent({
    required this.format,
    required this.value,
    this.baseUri,
  });

  final ResourceContentFormat format;
  final String value;
  final Uri? baseUri;
}

class CommunityResourceImage {
  const CommunityResourceImage({
    required this.url,
    this.thumbnailUrl,
    this.width,
    this.height,
  });

  final Uri url;
  final Uri? thumbnailUrl;
  final int? width;
  final int? height;
}

class CommunityResourceDetail extends CommunityResource {
  const CommunityResourceDetail({
    required super.ref,
    required super.name,
    required super.type,
    required super.paidType,
    required super.authors,
    required super.supportedDevices,
    required this.content,
    required this.files,
    super.iconUrl,
    super.coverUrl,
    super.summary,
    super.updatedAt,
    super.publicUrl,
    super.tags,
    super.downloadCount,
    super.version,
    super.priceLabel,
    this.previews = const [],
    this.previewImages = const [],
    this.links = const [],
    this.canDownload = true,
  });

  final CommunityResourceContent content;
  final List<CommunityResourceFile> files;
  final List<Uri> previews;
  final List<CommunityResourceImage> previewImages;
  final List<CommunityResourceLink> links;
  final bool canDownload;
}

class CommunityResourceDevice {
  const CommunityResourceDevice({
    required this.codename,
    required this.name,
    this.description = '',
  });

  final String codename;
  final String name;
  final String description;
}

class CommunityResourceDownloadResult {
  const CommunityResourceDownloadResult({
    required this.path,
    required this.fileName,
    this.bytes,
  });

  final String path;
  final String fileName;
  final Uint8List? bytes;
}
