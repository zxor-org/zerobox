import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';

enum CommunitySortRule { random, name, time }

class CommunityResourceQuery {
  const CommunityResourceQuery({
    this.page = 0,
    this.pageSize = 30,
    this.query = '',
    this.sort = CommunitySortRule.time,
    this.type,
    this.hidePaid = false,
    this.hideForcePaid = false,
    this.selectedDevices = const {},
  });

  final int page;
  final int pageSize;
  final String query;
  final CommunitySortRule sort;
  final CommunityResourceType? type;
  final bool hidePaid;
  final bool hideForcePaid;
  final Set<String> selectedDevices;
}

class CommunityResourcePage {
  const CommunityResourcePage({
    required this.items,
    required this.page,
    required this.hasMore,
    this.total,
  });

  final List<CommunityResource> items;
  final int page;
  final bool hasMore;
  final int? total;
}

class CommunityCatalogCapabilities {
  const CommunityCatalogCapabilities({
    this.search = true,
    this.deviceFilter = true,
    this.typeFilter = true,
    this.serverSort = false,
  });

  final bool search;
  final bool deviceFilter;
  final bool typeFilter;
  final bool serverSort;
}

class CommunityDownloadRequest {
  const CommunityDownloadRequest({
    required this.resource,
    required this.file,
    this.targetDevice,
    this.onProgress,
  });

  final CommunityResourceDetail resource;
  final CommunityResourceFile file;
  final String? targetDevice;
  final void Function(double progress, {String status})? onProgress;
}

abstract class CommunityResourceCatalog {
  CommunitySourceId get sourceId;

  String get displayName;

  CommunityCatalogCapabilities get capabilities;

  Future<CommunityResourcePage> getPage(CommunityResourceQuery query);

  Future<CommunityResourceDetail> getDetail(ResourceRef ref);

  Future<List<CommunityResourceDevice>> getDevices();

  Future<CommunityResourceDownloadResult> download(
    CommunityDownloadRequest request,
  );

  Future<int?> probeDownloadSize(CommunityResourceFile file);
}
