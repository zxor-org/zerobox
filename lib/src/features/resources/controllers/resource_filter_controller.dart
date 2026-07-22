import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';

enum ResourceMode { home, library, creator }

const Object _unset = Object();

class ResourceFilters {
  const ResourceFilters({
    this.query = '',
    this.type,
    this.sort = CommunitySortRule.random,
    this.hidePaid = false,
    this.hideForcePaid = false,
    this.selectedDevices = const {},
  });

  final String query;
  final CommunityResourceType? type;
  final CommunitySortRule sort;
  final bool hidePaid;
  final bool hideForcePaid;
  final Set<String> selectedDevices;

  ResourceFilters copyWith({
    String? query,
    Object? type = _unset,
    CommunitySortRule? sort,
    bool? hidePaid,
    bool? hideForcePaid,
    Set<String>? selectedDevices,
  }) {
    return ResourceFilters(
      query: query ?? this.query,
      type: identical(type, _unset)
          ? this.type
          : type as CommunityResourceType?,
      sort: sort ?? this.sort,
      hidePaid: hidePaid ?? this.hidePaid,
      hideForcePaid: hideForcePaid ?? this.hideForcePaid,
      selectedDevices: selectedDevices ?? this.selectedDevices,
    );
  }
}

class ResourceModeController extends Notifier<ResourceMode> {
  @override
  ResourceMode build() => ResourceMode.library;

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

class ResourceRefreshController extends Notifier<int> {
  @override
  int build() => 0;

  void refresh() => state++;
}

final resourceRefreshProvider =
    NotifierProvider<ResourceRefreshController, int>(
      ResourceRefreshController.new,
    );

class ResourceFiltersNotifier extends Notifier<ResourceFilters> {
  @override
  ResourceFilters build() => const ResourceFilters();

  void reset() => state = ResourceFilters();

  void setQuery(String value) => state = state.copyWith(query: value);
  void setType(CommunityResourceType? value) =>
      state = state.copyWith(type: value);
  void setSort(CommunitySortRule value) => state = state.copyWith(sort: value);
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

  void selectDevice(String device) {
    if (state.selectedDevices.length == 1 &&
        state.selectedDevices.contains(device)) {
      return;
    }
    state = state.copyWith(selectedDevices: {device});
  }

  void setNumericDevice(int deviceSource) {
    if (deviceSource <= 0) return;
    final updated = Set<String>.from(state.selectedDevices)
      ..removeWhere((id) => int.tryParse(id) != null)
      ..add(deviceSource.toString());
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

  void clearNumericDevices() {
    final updated = Set<String>.from(state.selectedDevices)
      ..removeWhere((id) => int.tryParse(id) != null);
    state = state.copyWith(selectedDevices: updated);
  }
}
