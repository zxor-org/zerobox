import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/network/dio_provider.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/astrobox/astrobox_repo_resource_provider.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/data/huami/huami_app_store_resource_provider.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

final selectedCommunitySourceProvider = Provider<CommunitySourceId>((ref) {
  return ref.watch(
    appSettingsProvider.select((settings) => settings.communitySource),
  );
});

final communityCatalogProviderForSource =
    Provider.family<CommunityResourceCatalog, CommunitySourceId>((ref, source) {
      final dio = ref.watch(appDioProvider);
      return switch (source) {
        CommunitySourceId.astroboxRepo => AstroBoxRepoCatalog(
          dio: dio,
          cdn: ref.watch(
            appSettingsProvider.select((settings) => settings.cdn),
          ),
        ),
        CommunitySourceId.bandbbs => BandBbsCatalog(
          dio: dio,
          auth: ref.read(bandBbsAuthProvider.notifier),
          showAllCategories: ref.watch(
            appSettingsProvider.select(
              (settings) => settings.bandbbsShowAllCategories,
            ),
          ),
        ),
        CommunitySourceId.huamiAppStore => HuamiAppStoreCatalog(
          dio: dio,
          auth: ref.read(huamiAuthProvider.notifier),
        ),
      };
    });

final communityCatalogProvider = Provider<CommunityResourceCatalog>((ref) {
  return ref.watch(
    communityCatalogProviderForSource(
      ref.watch(selectedCommunitySourceProvider),
    ),
  );
});

final communityCatalogDevicesProvider =
    FutureProvider.autoDispose<List<CommunityResourceDevice>>((ref) {
      return ref.watch(communityCatalogProvider).getDevices();
    });

final communityResourceDetailProvider = FutureProvider.autoDispose
    .family<CommunityResourceDetail, ResourceRef>((ref, refValue) {
      return ref
          .watch(communityCatalogProviderForSource(refValue.source))
          .getDetail(refValue);
    });

final bandbbsCategoryTreeProvider =
    FutureProvider.autoDispose<List<BandBbsCategoryNode>>((ref) {
      final catalog = ref.watch(
        communityCatalogProviderForSource(CommunitySourceId.bandbbs),
      );
      return (catalog as BandBbsCatalog).getCategoryTree();
    });

final huamiPublisherResourcesProvider =
    FutureProvider.autoDispose.family<List<CommunityResource>, String>((
      ref,
      publisherName,
    ) {
      final catalog = ref.watch(
        communityCatalogProviderForSource(CommunitySourceId.huamiAppStore),
      );
      return (catalog as HuamiAppStoreCatalog).getPublisherResources(
        publisherName: publisherName,
      );
    });
