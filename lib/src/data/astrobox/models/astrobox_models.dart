import 'package:freezed_annotation/freezed_annotation.dart';

part 'astrobox_models.freezed.dart';
part 'astrobox_models.g.dart';

enum AstroBoxResourceType {
  @JsonValue('quick_app')
  quickApp,
  @JsonValue('watchface')
  watchface,
  @JsonValue('firmware')
  firmware,
  @JsonValue('fontpack')
  fontpack,
  @JsonValue('iconpack')
  iconpack,
}

enum AstroBoxPaidType {
  @JsonValue('free')
  free,
  @JsonValue('paid')
  paid,
  @JsonValue('force_paid')
  forcePaid,
}

@freezed
abstract class AstroBoxIndexItem with _$AstroBoxIndexItem {
  const factory AstroBoxIndexItem({
    required String id,
    required String name,
    @JsonKey(name: 'restype') required AstroBoxResourceType type,
    required String repoOwner,
    required String repoName,
    required String repoCommitHash,
    required String icon,
    required String cover,
    @Default([]) List<String> tags,
    @JsonKey(name: 'device_vendors') @Default([]) List<String> deviceVendors,
    @Default([]) List<String> devices,
    @JsonKey(name: 'paid_type') required AstroBoxPaidType paidType,
  }) = _AstroBoxIndexItem;

  factory AstroBoxIndexItem.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxIndexItemFromJson(json);
}

@freezed
abstract class AstroBoxManifest with _$AstroBoxManifest {
  const factory AstroBoxManifest({
    required AstroBoxManifestItem item,
    @Default([]) List<AstroBoxManifestLink> links,
    @Default({}) Map<String, AstroBoxManifestDownload> downloads,
    @Default({}) Map<String, dynamic> ext,
  }) = _AstroBoxManifest;

  factory AstroBoxManifest.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxManifestFromJson(json);
}

@freezed
abstract class AstroBoxManifestItem with _$AstroBoxManifestItem {
  const factory AstroBoxManifestItem({
    required String id,
    required AstroBoxResourceType restype,
    required String name,
    required String description,
    String? descriptionHtml,
    String? descriptionBaseUrl,
    @Default([]) List<String> preview,
    required String icon,
    required String cover,
    AstroBoxPaidType? paidType,
    @Default([]) List<AstroBoxManifestAuthor> author,
  }) = _AstroBoxManifestItem;

  factory AstroBoxManifestItem.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxManifestItemFromJson(json);
}

@freezed
abstract class AstroBoxManifestAuthor with _$AstroBoxManifestAuthor {
  const factory AstroBoxManifestAuthor({
    required String name,
    @JsonKey(name: 'bindABAccount') @Default(false) bool bindAbAccount,
  }) = _AstroBoxManifestAuthor;

  factory AstroBoxManifestAuthor.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxManifestAuthorFromJson(json);
}

@freezed
abstract class AstroBoxManifestLink with _$AstroBoxManifestLink {
  const factory AstroBoxManifestLink({
    String? icon,
    required String title,
    required String url,
  }) = _AstroBoxManifestLink;

  factory AstroBoxManifestLink.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxManifestLinkFromJson(json);
}

@freezed
abstract class AstroBoxManifestDownload with _$AstroBoxManifestDownload {
  const factory AstroBoxManifestDownload({
    required String version,
    @JsonKey(name: 'file_name') required String fileName,
    @JsonKey(name: 'version_code', fromJson: _versionCodeFromJson)
    int? versionCode,
    String? url,
    String? sha256,
    String? displayName,
  }) = _AstroBoxManifestDownload;

  factory AstroBoxManifestDownload.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxManifestDownloadFromJson(json);
}

@freezed
abstract class AstroBoxDeviceMap with _$AstroBoxDeviceMap {
  const factory AstroBoxDeviceMap({
    @Default({}) Map<String, AstroBoxDevice> xiaomi,
  }) = _AstroBoxDeviceMap;

  factory AstroBoxDeviceMap.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxDeviceMapFromJson(json);
}

@freezed
abstract class AstroBoxDevice with _$AstroBoxDevice {
  const factory AstroBoxDevice({
    required String id,
    required String name,
    required String description,
    required AstroBoxDeviceChip chip,
    @Default(false) bool fetch,
  }) = _AstroBoxDevice;

  factory AstroBoxDevice.fromJson(Map<String, dynamic> json) =>
      _$AstroBoxDeviceFromJson(json);
}

enum AstroBoxDeviceChip { xring, bes }

int? _versionCodeFromJson(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value.trim());
  return null;
}
