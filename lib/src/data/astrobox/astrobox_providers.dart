import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/network/dio_provider.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/astrobox/astrobox_repo_community_repository.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/data/community/community_resource_repository.dart';
import 'package:zerobox/src/data/community/community_source.dart';

final communitySourceProvider = Provider<CommunitySourceId>((ref) {
  return ref.watch(appSettingsProvider).communitySource;
});

final communityRepositoryProvider = Provider<CommunityResourceRepository>((
  ref,
) {
  final source = ref.watch(communitySourceProvider);
  final dio = ref.watch(appDioProvider);
  return switch (source) {
    CommunitySourceId.astroboxRepo => AstroBoxRepoCommunityRepository(dio: dio),
  };
});

final astroBoxRepositoryProvider = Provider<CommunityResourceRepository>((ref) {
  return ref.watch(communityRepositoryProvider);
});

final astroBoxIndexProvider =
    FutureProvider.autoDispose<List<AstroBoxIndexItem>>((ref) async {
      final repo = ref.watch(astroBoxRepositoryProvider);
      return repo.fetchIndex();
    });

final astroBoxDeviceMapProvider = FutureProvider.autoDispose<AstroBoxDeviceMap>(
  (ref) async {
    final repo = ref.watch(astroBoxRepositoryProvider);
    return repo.fetchDeviceMap();
  },
);

final astroBoxManifestProvider = FutureProvider.autoDispose
    .family<AstroBoxManifest?, AstroBoxIndexItem>((ref, item) async {
      final repo = ref.watch(astroBoxRepositoryProvider);
      return repo.fetchManifest(item);
    });
