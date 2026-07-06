import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/data/community/community_resource_repository.dart';

enum ResourceMode { home, library, creator }

enum ResourceSortRule { random, name, time }

class ResourceFilters {
  const ResourceFilters({
    this.query = '',
    this.type,
    this.sort = ResourceSortRule.random,
    this.hidePaid = false,
    this.hideForcePaid = false,
    this.selectedDevices = const {},
  });

  final String query;
  final AstroBoxResourceType? type;
  final ResourceSortRule sort;
  final bool hidePaid;
  final bool hideForcePaid;
  final Set<String> selectedDevices;

  ResourceFilters copyWith({
    String? query,
    AstroBoxResourceType? type,
    ResourceSortRule? sort,
    bool? hidePaid,
    bool? hideForcePaid,
    Set<String>? selectedDevices,
  }) {
    return ResourceFilters(
      query: query ?? this.query,
      type: type ?? this.type,
      sort: sort ?? this.sort,
      hidePaid: hidePaid ?? this.hidePaid,
      hideForcePaid: hideForcePaid ?? this.hideForcePaid,
      selectedDevices: selectedDevices ?? this.selectedDevices,
    );
  }
}

class ResourceModeController extends Notifier<ResourceMode> {
  @override
  ResourceMode build() => ResourceMode.home;

  void setMode(ResourceMode mode) => state = mode;
}

final resourceModeControllerProvider =
    NotifierProvider<ResourceModeController, ResourceMode>(
      ResourceModeController.new,
    );

final resourceFiltersProvider =
    NotifierProvider<ResourceFiltersNotifier, ResourceFilters>(
      ResourceFiltersNotifier.new,
    );

class ResourceFiltersNotifier extends Notifier<ResourceFilters> {
  @override
  ResourceFilters build() => const ResourceFilters();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setType(AstroBoxResourceType? value) =>
      state = state.copyWith(type: value);
  void setSort(ResourceSortRule value) => state = state.copyWith(sort: value);
  void setHidePaid(bool value) => state = state.copyWith(hidePaid: value);
  void setHideForcePaid(bool value) =>
      state = state.copyWith(hideForcePaid: value);

  void toggleDevice(String device) {
    final updated = Set<String>.from(state.selectedDevices);
    if (updated.contains(device)) {
      updated.remove(device);
    } else {
      updated.add(device);
    }
    state = state.copyWith(selectedDevices: updated);
  }

  void toggleDeviceGroup(Iterable<String> devices) {
    final ids = devices.where((id) => id.isNotEmpty).toSet();
    if (ids.isEmpty) return;

    final updated = Set<String>.from(state.selectedDevices);
    if (ids.any(updated.contains)) {
      updated.removeAll(ids);
    } else {
      updated.addAll(ids);
    }
    state = state.copyWith(selectedDevices: updated);
  }

  void clearDevices() => state = state.copyWith(selectedDevices: const {});
}

final filteredAstroBoxIndexProvider =
    FutureProvider.autoDispose<List<AstroBoxIndexItem>>((ref) async {
      final repo = ref.watch(astroBoxRepositoryProvider);
      final filters = ref.watch(resourceFiltersProvider);

      return repo.getPage(
        page: 0,
        limit: 100000,
        search: CommunitySearchConfig(
          query: filters.query,
          sort: switch (filters.sort) {
            ResourceSortRule.random => CommunitySortRule.random,
            ResourceSortRule.name => CommunitySortRule.name,
            ResourceSortRule.time => CommunitySortRule.time,
          },
          type: filters.type,
          hidePaid: filters.hidePaid,
          hideForcePaid: filters.hideForcePaid,
          selectedDevices: filters.selectedDevices,
        ),
      );
    });
