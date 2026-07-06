import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/data/community/community_source.dart';

enum CommunityProviderState { ready, updating, failed }

enum CommunitySortRule { random, name, time }

class CommunitySearchConfig {
  const CommunitySearchConfig({
    this.query,
    this.sort = CommunitySortRule.random,
    this.type,
    this.hidePaid = false,
    this.hideForcePaid = false,
    this.selectedDevices = const {},
  });

  final String? query;
  final CommunitySortRule sort;
  final AstroBoxResourceType? type;
  final bool hidePaid;
  final bool hideForcePaid;
  final Set<String> selectedDevices;
}

class CommunityProgressData {
  const CommunityProgressData({required this.progress, this.status = ''});

  final double progress;
  final String status;
}

class CommunityDownloadResult {
  const CommunityDownloadResult({required this.path, required this.fileName});

  final String path;
  final String fileName;
}

abstract class CommunityResourceRepository {
  CommunitySourceId get sourceId;

  String get providerName;

  CommunityProviderState get state;

  Future<void> refresh({String config = ''});

  Future<List<AstroBoxIndexItem>> fetchIndex();

  Future<AstroBoxDeviceMap> fetchDeviceMap();

  Future<AstroBoxManifest> fetchManifest(AstroBoxIndexItem item);

  Future<List<AstroBoxIndexItem>> getPage({
    required int page,
    required int limit,
    CommunitySearchConfig search = const CommunitySearchConfig(),
  });

  Future<List<String>> getCategories();

  Future<AstroBoxManifest> getItemManifest(String itemId);

  Future<CommunityDownloadResult> download({
    required String itemId,
    required String device,
    void Function(CommunityProgressData progress)? onProgress,
  });

  Future<int?> probeDownloadSize({
    required String itemId,
    required String device,
  });

  String resolveImageUrl(AstroBoxIndexItem item, String path);

  String resolveDownloadUrl(
    AstroBoxIndexItem item,
    AstroBoxManifestDownload download,
  );
}
