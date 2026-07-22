import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/accounts/application/host_accounts.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/controllers/resource_filter_controller.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/resource_catalog.dart';
import 'package:zerobox/src/features/resources/widgets/bandbbs_category_sidebar.dart';
import 'package:zerobox/src/features/resources/widgets/bandbbs_resource_card.dart';

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(resourceModeControllerProvider);
    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.exploreTab),
        actions: [
          if (mode == ResourceMode.library) const _CommunitySourceMenu(),
          IconButton(
            tooltip: l10n.refresh,
            icon: const Icon(Icons.refresh),
            onPressed: () {
              final catalog = ref.read(communityCatalogProvider);
              if (catalog is BandBbsCatalog) {
                catalog.clearCategoryCache();
                ref.invalidate(bandbbsCategoryTreeProvider);
              }
              ref.invalidate(communityCatalogDevicesProvider);
              ref.read(resourceRefreshProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: StyleConstants.pageMaxWidth,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                  vertical: StyleConstants.pagePadding,
                ),
                child: SegmentedButton<ResourceMode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(
                      value: ResourceMode.home,
                      label: Text(l10n.homeTab),
                      icon: const Icon(Icons.home_outlined),
                    ),
                    ButtonSegment(
                      value: ResourceMode.library,
                      label: Text(l10n.resourceLibrary),
                      icon: const Icon(Icons.library_books_outlined),
                    ),
                    ButtonSegment(
                      value: ResourceMode.creator,
                      label: Text(l10n.creatorCenter),
                      icon: const Icon(Icons.create_outlined),
                    ),
                  ],
                  selected: {mode},
                  onSelectionChanged: (value) => ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(value.first),
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: switch (mode) {
                ResourceMode.home => const _ResourceHomePlaceholder(
                  key: ValueKey('home'),
                ),
                ResourceMode.library => const _ResourceLibraryView(
                  key: ValueKey('library'),
                ),
                ResourceMode.creator => const _ResourceCreatorPlaceholder(
                  key: ValueKey('creator'),
                ),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceHomePlaceholder extends ConsumerWidget {
  const _ResourceHomePlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StyleConstants.pageMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(StyleConstants.pagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.resourceHomeEmptyTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.resourceHomeEmptySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(ResourceMode.library);
                },
                icon: const Icon(Icons.library_books_outlined),
                label: Text(l10n.openResourceLibrary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceCreatorPlaceholder extends ConsumerWidget {
  const _ResourceCreatorPlaceholder({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: StyleConstants.pageMaxWidth,
        ),
        child: Padding(
          padding: const EdgeInsets.all(StyleConstants.pagePadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction_outlined,
                size: 64,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.resourceCreatorEmptyTitle,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.resourceCreatorEmptySubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: () {
                  ref
                      .read(resourceModeControllerProvider.notifier)
                      .setMode(ResourceMode.library);
                },
                icon: const Icon(Icons.library_books_outlined),
                label: Text(l10n.openResourceLibrary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResourceLibraryView extends ConsumerStatefulWidget {
  const _ResourceLibraryView({super.key});
  @override
  ConsumerState<_ResourceLibraryView> createState() =>
      _ResourceLibraryViewState();
}

class _ResourceLibraryViewState extends ConsumerState<_ResourceLibraryView> {
  static const _pageSize = 30;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();
  var _searchText = '';
  bool? _sidebarExpanded;
  final _items = <CommunityResource>[];
  var _page = 0;
  var _hasMore = true;
  var _loading = true;
  var _loadingMore = false;
  var _waitingForSidebarLoad = false;
  Object? _error;
  var _generation = 0;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _searchFocus.addListener(() {
      if (!_searchFocus.hasFocus) _commitSearch();
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _reset());
  }

  @override
  void dispose() {
    _searchFocus.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _commitSearch() {
    final value = _searchController.text;
    if (value == ref.read(resourceFiltersProvider).query) return;
    ref.read(resourceFiltersProvider.notifier).setQuery(value);
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.extentAfter < 600) {
      _load(_generation);
    }
  }

  Future<void> _reset() async {
    final generation = ++_generation;
    setState(() {
      _items.clear();
      _page = 0;
      _hasMore = true;
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    await _load(generation);
  }

  Future<void> _load(int generation) async {
    if (!_hasMore || _loadingMore) return;
    _ensureBandBbsSidebarLoaded();
    setState(() => _loadingMore = true);
    try {
      final filters = ref.read(resourceFiltersProvider);
      final result = await ref
          .read(communityCatalogProvider)
          .getPage(
            CommunityResourceQuery(
              page: _page,
              pageSize: _pageSize,
              query: filters.query,
              sort: filters.sort,
              type: filters.type,
              hidePaid: filters.hidePaid,
              hideForcePaid: filters.hideForcePaid,
              selectedDevices: filters.selectedDevices,
            ),
          );
      if (!mounted || generation != _generation) return;
      setState(() {
        _items.addAll(
          result.items.where(
            (item) => !_items.any((current) => current.ref == item.ref),
          ),
        );
        _page += 1;
        _hasMore = result.hasMore;
        _loading = false;
        _loadingMore = false;
      });
    } catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _error = error;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  void _ensureBandBbsSidebarLoaded() {
    if (ref.read(selectedCommunitySourceProvider) !=
        CommunitySourceId.bandbbs) {
      return;
    }
    final tree = ref.read(bandbbsCategoryTreeProvider);
    if (tree.isLoading) {
      if (_waitingForSidebarLoad) return;
      _waitingForSidebarLoad = true;
      unawaited(
        _retryBandBbsSidebarAfter(ref.read(bandbbsCategoryTreeProvider.future)),
      );
      return;
    }
    final roots = tree.value;
    if (roots == null || roots.isEmpty) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  Future<void> _retryBandBbsSidebarAfter(
    Future<List<BandBbsCategoryNode>> request,
  ) async {
    var hasCategories = false;
    try {
      hasCategories = (await request).isNotEmpty;
    } catch (_) {
      // The resource list remains usable when category loading fails
    } finally {
      _waitingForSidebarLoad = false;
    }
    if (!mounted || hasCategories) return;
    if (ref.read(selectedCommunitySourceProvider) ==
        CommunitySourceId.bandbbs) {
      ref.invalidate(bandbbsCategoryTreeProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    ref.listen(resourceFiltersProvider, (_, _) => _reset());
    ref.listen(resourceRefreshProvider, (_, _) => _reset());
    ref.listen(
      appSettingsProvider.select(
        (settings) => settings.bandbbsShowAllCategories,
      ),
      (_, _) => _reset(),
    );
    final capabilities = ref.watch(communityCatalogProvider).capabilities;
    if (!_searchFocus.hasFocus && _searchController.text != filters.query) {
      _searchController.text = filters.query;
      _searchText = filters.query;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final isBandBbs = source == CommunitySourceId.bandbbs;
        final expanded =
            isBandBbs && (_sidebarExpanded ?? constraints.maxWidth >= 900);
        final list = _buildList(
          context,
          l10n,
          filters,
          source,
          capabilities,
          sidebarExpanded: expanded,
          onToggleSidebar: isBandBbs
              ? () => setState(() => _sidebarExpanded = !expanded)
              : null,
        );
        if (!isBandBbs) {
          return list;
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              width: expanded ? 260 : 0,
              clipBehavior: Clip.hardEdge,
              decoration: const BoxDecoration(),
              child: const OverflowBox(
                alignment: Alignment.topLeft,
                minWidth: 260,
                maxWidth: 260,
                child: BandBbsCategorySidebar(),
              ),
            ),
            Expanded(child: list),
          ],
        );
      },
    );
  }

  Widget _buildList(
    BuildContext context,
    AppLocalizations l10n,
    ResourceFilters filters,
    CommunitySourceId source,
    CommunityCatalogCapabilities capabilities, {
    bool sidebarExpanded = false,
    VoidCallback? onToggleSidebar,
  }) {
    return RefreshIndicator(
      onRefresh: _reset,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PageContainer(
              padding: const EdgeInsets.all(StyleConstants.pagePadding),
              child: Column(
                children: [
                  Row(
                    children: [
                      if (onToggleSidebar != null) ...[
                        IconButton(
                          icon: Icon(
                            sidebarExpanded ? Icons.menu_open : Icons.menu,
                          ),
                          tooltip: l10n.categories,
                          onPressed: onToggleSidebar,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: SearchBar(
                          enabled: capabilities.search,
                          elevation: const WidgetStatePropertyAll(0),
                          controller: _searchController,
                          focusNode: _searchFocus,
                          hintText: capabilities.search
                              ? l10n.search
                              : l10n.search,
                          leading: const Icon(Icons.search),
                          trailing: [
                            if (_searchText.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchText = '');
                                  ref
                                      .read(resourceFiltersProvider.notifier)
                                      .setQuery('');
                                },
                              ),
                          ],
                          onChanged: (value) =>
                              setState(() => _searchText = value),
                          onSubmitted: (_) => _commitSearch(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const _FilterBar(),
                ],
              ),
            ),
          ),
          if (_loading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_error != null)
            SliverFillRemaining(
              child: Center(child: Text(localizedErrorMessage(l10n, _error!))),
            )
          else ...[
            if (source == CommunitySourceId.bandbbs ||
                source == CommunitySourceId.huamiAppStore)
              SliverPadding(
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                ),
                sliver: SliverList.builder(
                  itemCount: _items.length,
                  itemBuilder: (context, index) => Padding(
                    padding: EdgeInsets.only(
                      bottom: index == _items.length - 1 ? 0 : 10,
                    ),
                    child: BandBbsResourceCard(
                      key: ValueKey(_items[index].ref.key),
                      item: _items[index],
                    ),
                  ),
                ),
              )
            else
              SliverToBoxAdapter(
                child: PageContainer(
                  padding: const EdgeInsets.symmetric(
                    horizontal: StyleConstants.pagePadding,
                  ),
                  child: _ResourceGrid(items: _items),
                ),
              ),
            if (_loadingMore)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (_items.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: Text(l10n.notFound)),
              ),
          ],
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _CommunitySourceMenu extends ConsumerWidget {
  const _CommunitySourceMenu();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final source = ref.watch(selectedCommunitySourceProvider);
    final loadedSources = ref.watch(communitySourcesProvider).value;
    final sourceById = <String, CommunitySourceId>{
      for (final candidate in loadedSources ?? CommunitySourceId.values)
        candidate.storageKey: candidate,
      source.storageKey: source,
    };
    final l10n = AppLocalizations.of(context)!;
    return MenuAnchor(
      menuChildren: sourceById.values
          .map(
            (candidate) => MenuItemButton(
              trailingIcon: candidate == source
                  ? Icon(
                      Icons.check,
                      color: Theme.of(context).colorScheme.primary,
                    )
                  : null,
              onPressed: candidate == source
                  ? null
                  : () async {
                      if (candidate == CommunitySourceId.bandbbs) {
                        final host = ref.read(hostAccountsProvider.notifier);
                        await host.refresh();
                        if (!context.mounted) return;
                        if (!ref
                            .read(hostAccountsProvider)
                            .bandbbs
                            .isSignedIn) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                l10n.settingsBandBbsAccountRequired,
                              ),
                            ),
                          );
                          return;
                        }
                      }
                      if (candidate == CommunitySourceId.huamiAppStore &&
                          !ref.read(hostAccountsProvider).amazfit.isSignedIn) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.settingsHuamiAccountRequired),
                          ),
                        );
                        return;
                      }
                      await ref
                          .read(appSettingsProvider.notifier)
                          .setCommunitySource(candidate);
                      ref.read(resourceFiltersProvider.notifier).reset();
                    },
              child: Text(_communitySourceLabel(l10n, candidate)),
            ),
          )
          .toList(),
      builder: (_, controller, _) => TextButton.icon(
        onPressed: controller.isOpen ? controller.close : controller.open,
        icon: const Icon(Icons.arrow_drop_down),
        label: Text(_communitySourceLabel(l10n, source)),
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  const _FilterBar();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final devices =
        ref.watch(communityCatalogDevicesProvider).value ??
        const <CommunityResourceDevice>[];
    final deviceOptions = _buildDeviceFilterOptions(devices);
    final selectedDeviceOptions = deviceOptions
        .where((option) => option.ids.any(filters.selectedDevices.contains))
        .toList();
    final knownDeviceIds = deviceOptions.expand((option) => option.ids).toSet();
    final unknownSelectedDevices = filters.selectedDevices
        .where((id) => !knownDeviceIds.contains(id))
        .toList();
    final categoryTitles = <String, String>{};
    final source = ref.watch(selectedCommunitySourceProvider);
    if (source == CommunitySourceId.bandbbs) {
      void collect(List<BandBbsCategoryNode> nodes) {
        for (final node in nodes) {
          categoryTitles['${BandBbsCategorySidebar.categoryFilterPrefix}${node.id}'] =
              node.title;
          collect(node.children);
        }
      }

      collect(ref.watch(bandbbsCategoryTreeProvider).value ?? const []);
    }
    final hasActiveFilters =
        filters.type != null ||
        filters.hidePaid ||
        (source == CommunitySourceId.astroboxRepo && filters.hideForcePaid) ||
        filters.selectedDevices.isNotEmpty;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: Text(l10n.filter),
            selected: hasActiveFilters,
            onPressed: () => _showFilters(context),
          ),
          const SizedBox(width: 8),
          ...selectedDeviceOptions.map(
            (option) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.label),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .toggleDeviceGroup(option.ids),
              ),
            ),
          ),
          ...unknownSelectedDevices.map(
            (codename) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(
                  source == CommunitySourceId.huamiAppStore &&
                          int.tryParse(codename) != null
                      ? '\u8bbe\u5907\u6e90 $codename'
                      : categoryTitles[codename] ?? codename,
                ),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .toggleDevice(codename),
              ),
            ),
          ),
          if (filters.type != null) ...[
            const SizedBox(width: 8),
            Padding(
              padding: EdgeInsets.zero,
              child: FilterChip(
                label: Text(_typeLabel(l10n, filters.type!, source: source)),
                selected: true,
                onSelected: (_) =>
                    ref.read(resourceFiltersProvider.notifier).setType(null),
              ),
            ),
          ],
          if (filters.hidePaid)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(l10n.paid),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHidePaid(false),
              ),
            ),
          if (source == CommunitySourceId.astroboxRepo && filters.hideForcePaid)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: FilterChip(
                label: Text(l10n.forcePaid),
                selected: true,
                onSelected: (_) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(false),
              ),
            ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        builder: (context, scrollController) {
          return _FilterSheet(scrollController: scrollController);
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final Widget label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: label,
      avatar: Icon(
        selected ? Icons.filter_list_off : Icons.filter_list,
        size: 18,
      ),
      onPressed: onPressed,
    );
  }
}

class _FilterSheet extends ConsumerWidget {
  const _FilterSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final source = ref.watch(selectedCommunitySourceProvider);
    final devices =
        ref.watch(communityCatalogDevicesProvider).value ??
        const <CommunityResourceDevice>[];
    final deviceOptions = _buildDeviceFilterOptions(devices);
    final deviceSectionTitle = source == CommunitySourceId.bandbbs
        ? l10n.categories
        : l10n.devices;

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        Text(l10n.filter, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        Text(l10n.all, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text(
                _typeLabel(
                  l10n,
                  CommunityResourceType.quickApp,
                  source: source,
                ),
              ),
              selected: filters.type == CommunityResourceType.quickApp,
              onSelected: (_) => ref
                  .read(resourceFiltersProvider.notifier)
                  .setType(
                    filters.type == CommunityResourceType.quickApp
                        ? null
                        : CommunityResourceType.quickApp,
                  ),
            ),
            FilterChip(
              label: Text(l10n.watchfaces),
              selected: filters.type == CommunityResourceType.watchface,
              onSelected: (_) => ref
                  .read(resourceFiltersProvider.notifier)
                  .setType(
                    filters.type == CommunityResourceType.watchface
                        ? null
                        : CommunityResourceType.watchface,
                  ),
            ),
            FilterChip(
              label: Text(l10n.firmwareTools),
              selected: filters.type == CommunityResourceType.firmware,
              onSelected: (_) => ref
                  .read(resourceFiltersProvider.notifier)
                  .setType(
                    filters.type == CommunityResourceType.firmware
                        ? null
                        : CommunityResourceType.firmware,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(deviceSectionTitle, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: deviceOptions
              .map(
                (option) => FilterChip(
                  label: Text(option.label),
                  selected: option.ids.any(filters.selectedDevices.contains),
                  onSelected: (_) {
                    ref
                        .read(resourceFiltersProvider.notifier)
                        .toggleDeviceGroup(option.ids);
                  },
                ),
              )
              .toList(),
        ),
        if (source == CommunitySourceId.huamiAppStore) ...[
          const SizedBox(height: 12),
          _HuamiDeviceSourceInput(filters: filters),
        ],
        const SizedBox(height: 16),
        Text(l10n.paid, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilterChip(
              label: Text('${l10n.hide}${l10n.paid}'),
              selected: filters.hidePaid,
              onSelected: (value) =>
                  ref.read(resourceFiltersProvider.notifier).setHidePaid(value),
            ),
            if (source == CommunitySourceId.astroboxRepo)
              FilterChip(
                label: Text('${l10n.hide}${l10n.forcePaid}'),
                selected: filters.hideForcePaid,
                onSelected: (value) => ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(value),
              ),
          ],
        ),
      ],
    );
  }
}

class _HuamiDeviceSourceInput extends ConsumerStatefulWidget {
  const _HuamiDeviceSourceInput({required this.filters});

  final ResourceFilters filters;

  @override
  ConsumerState<_HuamiDeviceSourceInput> createState() =>
      _HuamiDeviceSourceInputState();
}

class _HuamiDeviceSourceInputState
    extends ConsumerState<_HuamiDeviceSourceInput> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _firstNumericDeviceSource());
  }

  @override
  void didUpdateWidget(covariant _HuamiDeviceSourceInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final value = _firstNumericDeviceSource();
    if (value != _controller.text) {
      _controller.text = value;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: '\u8bbe\u5907\u6e90',
              hintText: '260',
              prefixIcon: const Icon(Icons.numbers),
              isDense: true,
              border: const OutlineInputBorder(),
              suffixIcon: widget.filters.selectedDevices.any(_isNumeric)
                  ? IconButton(
                      tooltip: MaterialLocalizations.of(
                        context,
                      ).deleteButtonTooltip,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _controller.clear();
                        ref
                            .read(resourceFiltersProvider.notifier)
                            .clearNumericDevices();
                      },
                    )
                  : null,
            ),
            onSubmitted: (_) => _apply(),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: color.primaryContainer,
            foregroundColor: color.onPrimaryContainer,
          ),
          onPressed: _apply,
          child: const Text('\u5e94\u7528'),
        ),
      ],
    );
  }

  void _apply() {
    final source = int.tryParse(_controller.text.trim());
    if (source == null || source <= 0) return;
    ref.read(resourceFiltersProvider.notifier).setNumericDevice(source);
  }

  String _firstNumericDeviceSource() =>
      widget.filters.selectedDevices.firstWhere(_isNumeric, orElse: () => '');

  bool _isNumeric(String value) {
    final parsed = int.tryParse(value);
    return parsed != null && parsed > 0;
  }
}

class _DeviceFilterOption {
  const _DeviceFilterOption({required this.label, required this.ids});

  final String label;
  final Set<String> ids;
}

List<_DeviceFilterOption> _buildDeviceFilterOptions(
  Iterable<CommunityResourceDevice> devices,
) {
  final grouped = <String, Set<String>>{};
  for (final device in devices) {
    final rawId = device.codename.trim();
    final identity = normalizeXiaomiWearableIdentity(rawId);
    final id = identity?.codename ?? rawId;
    if (id.isEmpty) continue;

    final label =
        identity?.displayName ??
        (device.name.trim().isNotEmpty ? device.name.trim() : id);
    grouped.putIfAbsent(label, () => <String>{}).add(id);
  }

  return grouped.entries
      .map((entry) => _DeviceFilterOption(label: entry.key, ids: entry.value))
      .toList()
    ..sort((a, b) => a.label.compareTo(b.label));
}

String _typeLabel(
  AppLocalizations l10n,
  CommunityResourceType type, {
  CommunitySourceId? source,
}) => switch (type) {
  CommunityResourceType.quickApp =>
    source == CommunitySourceId.huamiAppStore
        ? l10n.miniprograms
        : l10n.quickApps,
  CommunityResourceType.watchface => l10n.watchfaces,
  CommunityResourceType.firmware => l10n.firmwareTools,
  CommunityResourceType.fontpack => l10n.fontPack,
  CommunityResourceType.iconpack => l10n.iconPack,
};

String _communitySourceLabel(AppLocalizations l10n, CommunitySourceId source) =>
    switch (source) {
      CommunitySourceId.astroboxRepo => l10n.communitySourceAstroBoxRepo,
      CommunitySourceId.bandbbs => l10n.communitySourceBandBbs,
      CommunitySourceId.huamiAppStore => l10n.communitySourceHuamiAppStore,
      _ => source.displayName,
    };

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.items});
  final List<CommunityResource> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final spacing = 10.0;
        final minTrackWidth = 170.0;
        final crossAxisCount = ((width + spacing) / (minTrackWidth + spacing))
            .floor()
            .clamp(1, 1000);
        final trackWidth =
            (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardWidth = trackWidth > 300 ? 300.0 : trackWidth;
        final coverHeight = cardWidth * 2 / 3;

        return Wrap(
          alignment: WrapAlignment.start,
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: trackWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: cardWidth,
                  child: _ResourceCard(item: item, coverHeight: coverHeight),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResourceCard extends StatelessWidget {
  const _ResourceCard({required this.item, required this.coverHeight});
  final CommunityResource item;
  final double coverHeight;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    final image = item.coverUrl ?? item.iconUrl;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      child: InkWell(
        onTap: () =>
            context.push('/resources/detail/${item.ref.id}', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkImgLayer(
              src: image?.toString() ?? '',
              width: double.infinity,
              height: coverHeight,
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      _ResourceLabel(
                        label: _typeLabel(
                          AppLocalizations.of(context)!,
                          item.type,
                          source: item.ref.source,
                        ),
                        color: color.primary,
                      ),
                      if (item.paidType != CommunityPaidType.free)
                        _ResourceLabel(
                          label: _paidLabel(
                            AppLocalizations.of(context)!,
                            item.paidType,
                          ),
                          color: color.tertiary,
                        ),
                      if (item.ref.source == CommunitySourceId.bandbbs)
                        ...item.tags
                            .take(1)
                            .map(
                              (tag) => _ResourceLabel(
                                label: tag,
                                color: color.onSurfaceVariant,
                              ),
                            ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResourceLabel extends StatelessWidget {
  const _ResourceLabel({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(StyleConstants.chipRadius),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

String _paidLabel(AppLocalizations l10n, CommunityPaidType type) =>
    switch (type) {
      CommunityPaidType.free => l10n.free,
      CommunityPaidType.paid => l10n.paid,
      CommunityPaidType.forcePaid => l10n.forcePaid,
    };
