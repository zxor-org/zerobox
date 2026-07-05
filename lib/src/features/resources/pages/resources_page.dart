import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/network_img_layer.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/device/core/xiaomi_wearable_catalog.dart';
import 'package:zerobox/src/features/resources/controllers/resource_filter_controller.dart';

class ResourcesPage extends ConsumerWidget {
  const ResourcesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final mode = ref.watch(resourceModeControllerProvider);

    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.resourcesTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(astroBoxIndexProvider);
              ref.invalidate(astroBoxDeviceMapProvider);
            },
            tooltip: l10n.refresh,
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
                  onSelectionChanged: (selected) {
                    ref
                        .read(resourceModeControllerProvider.notifier)
                        .setMode(selected.first);
                  },
                ),
              ),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: mode == ResourceMode.library
                  ? const _ResourceLibraryView(key: ValueKey('library'))
                  : const Placeholder(key: ValueKey('creator')),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResourceLibraryView extends ConsumerWidget {
  const _ResourceLibraryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final indexAsync = ref.watch(filteredAstroBoxIndexProvider);

    Future<void> onRefresh() async {
      ref.invalidate(astroBoxIndexProvider);
      ref.invalidate(astroBoxDeviceMapProvider);
      await ref.read(astroBoxIndexProvider.future);
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: PageContainer(
              padding: const EdgeInsets.symmetric(
                horizontal: StyleConstants.pagePadding,
                vertical: StyleConstants.pagePadding,
              ),
              child: Column(
                children: [
                  SearchBar(
                    hintText: l10n.search,
                    leading: const Icon(Icons.search),
                    trailing: [
                      if (filters.query.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            ref
                                .read(resourceFiltersProvider.notifier)
                                .setQuery('');
                          },
                        ),
                    ],
                    onChanged: (value) {
                      ref
                          .read(resourceFiltersProvider.notifier)
                          .setQuery(value);
                    },
                  ),
                  const SizedBox(height: 12),
                  _FilterBar(),
                ],
              ),
            ),
          ),
          indexAsync.when(
            data: (items) => SliverToBoxAdapter(
              child: PageContainer(
                padding: const EdgeInsets.symmetric(
                  horizontal: StyleConstants.pagePadding,
                ),
                child: _ResourceGrid(items: items),
              ),
            ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, _) => SliverFillRemaining(
              child: Center(child: Text('${l10n.error}: $err')),
            ),
          ),
          const SliverPadding(padding: EdgeInsets.only(bottom: 32)),
        ],
      ),
    );
  }
}

class _FilterBar extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final filters = ref.watch(resourceFiltersProvider);
    final deviceMapAsync = ref.watch(astroBoxDeviceMapProvider);

    final devices = deviceMapAsync.value?.xiaomi.entries.toList() ?? [];
    final deviceOptions = _buildDeviceFilterOptions(devices);
    final selectedDeviceOptions = deviceOptions
        .where((option) => option.ids.any(filters.selectedDevices.contains))
        .toList();
    final knownDeviceIds = deviceOptions.expand((option) => option.ids).toSet();
    final unknownSelectedDevices = filters.selectedDevices
        .where((id) => !knownDeviceIds.contains(id))
        .toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _FilterChip(
            label: l10n.filter,
            selected:
                filters.type != null ||
                filters.hidePaid ||
                filters.hideForcePaid ||
                filters.selectedDevices.isNotEmpty,
            onPressed: () => _showFilterSheet(context),
          ),
          const SizedBox(width: 8),
          ...selectedDeviceOptions.map((option) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(option.label),
                selected: true,
                onSelected: (_) {
                  ref
                      .read(resourceFiltersProvider.notifier)
                      .toggleDeviceGroup(option.ids);
                },
              ),
            );
          }),
          ...unknownSelectedDevices.map((codename) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(codename),
                selected: true,
                onSelected: (_) {
                  ref
                      .read(resourceFiltersProvider.notifier)
                      .toggleDevice(codename);
                },
              ),
            );
          }),
          if (filters.type != null) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(_typeLabel(context, filters.type!)),
              selected: true,
              onSelected: (_) {
                ref.read(resourceFiltersProvider.notifier).setType(null);
              },
            ),
          ],
          if (filters.hidePaid) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.paid),
              selected: true,
              onSelected: (_) {
                ref.read(resourceFiltersProvider.notifier).setHidePaid(false);
              },
            ),
          ],
          if (filters.hideForcePaid) ...[
            const SizedBox(width: 8),
            FilterChip(
              label: Text(l10n.forcePaid),
              selected: true,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(false);
              },
            ),
          ],
        ],
      ),
    );
  }

  String _typeLabel(BuildContext context, AstroBoxResourceType type) {
    final l10n = AppLocalizations.of(context)!;
    return switch (type) {
      AstroBoxResourceType.quickApp => l10n.quickApps,
      AstroBoxResourceType.watchface => l10n.watchfaces,
      AstroBoxResourceType.firmware => l10n.firmwareTools,
      AstroBoxResourceType.fontpack => l10n.fontPack,
      AstroBoxResourceType.iconpack => l10n.iconPack,
    };
  }

  void _showFilterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
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

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
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
    final deviceMapAsync = ref.watch(astroBoxDeviceMapProvider);
    final devices = deviceMapAsync.value?.xiaomi.entries.toList() ?? [];
    final deviceOptions = _buildDeviceFilterOptions(devices);

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
              label: Text(l10n.quickApps),
              selected: filters.type == AstroBoxResourceType.quickApp,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setType(
                      filters.type == AstroBoxResourceType.quickApp
                          ? null
                          : AstroBoxResourceType.quickApp,
                    );
              },
            ),
            FilterChip(
              label: Text(l10n.watchfaces),
              selected: filters.type == AstroBoxResourceType.watchface,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setType(
                      filters.type == AstroBoxResourceType.watchface
                          ? null
                          : AstroBoxResourceType.watchface,
                    );
              },
            ),
            FilterChip(
              label: Text(l10n.firmwareTools),
              selected: filters.type == AstroBoxResourceType.firmware,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setType(
                      filters.type == AstroBoxResourceType.firmware
                          ? null
                          : AstroBoxResourceType.firmware,
                    );
              },
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(l10n.devices, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: deviceOptions.map((option) {
            final selected = option.ids.any(filters.selectedDevices.contains);
            return FilterChip(
              label: Text(option.label),
              selected: selected,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .toggleDeviceGroup(option.ids);
              },
            );
          }).toList(),
        ),
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
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setHidePaid(!filters.hidePaid);
              },
            ),
            FilterChip(
              label: Text('${l10n.hide}${l10n.forcePaid}'),
              selected: filters.hideForcePaid,
              onSelected: (_) {
                ref
                    .read(resourceFiltersProvider.notifier)
                    .setHideForcePaid(!filters.hideForcePaid);
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _DeviceFilterOption {
  const _DeviceFilterOption({required this.label, required this.ids});

  final String label;
  final Set<String> ids;
}

List<_DeviceFilterOption> _buildDeviceFilterOptions(
  Iterable<MapEntry<String, AstroBoxDevice>> entries,
) {
  final grouped = <String, Set<String>>{};
  for (final entry in entries) {
    final device = entry.value;
    final rawId = device.id.trim().isNotEmpty ? device.id.trim() : entry.key;
    final identity = normalizeXiaomiWearableIdentity(rawId);
    final id = identity?.codename ?? rawId;
    if (id.isEmpty) continue;

    final label =
        identity?.displayName ??
        (device.name.trim().isNotEmpty ? device.name.trim() : id);
    grouped.putIfAbsent(label, () => <String>{}).add(id);
  }

  final options =
      grouped.entries
          .map(
            (entry) => _DeviceFilterOption(label: entry.key, ids: entry.value),
          )
          .toList()
        ..sort((a, b) => a.label.compareTo(b.label));
  return options;
}

class _ResourceGrid extends StatelessWidget {
  const _ResourceGrid({required this.items});

  final List<AstroBoxIndexItem> items;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 960
            ? 4
            : width >= 720
            ? 3
            : width >= 480
            ? 2
            : 1;
        final spacing = width >= 720 ? 16.0 : 12.0;
        final rawCardWidth =
            (width - (crossAxisCount - 1) * spacing) / crossAxisCount;
        final cardWidth = crossAxisCount == 1
            ? rawCardWidth.clamp(0.0, 320.0)
            : rawCardWidth;
        final coverHeight = cardWidth * 2 / 3;

        return Wrap(
          alignment: crossAxisCount == 1
              ? WrapAlignment.center
              : WrapAlignment.start,
          spacing: spacing,
          runSpacing: spacing,
          children: items.map((item) {
            return SizedBox(
              width: cardWidth,
              child: _ResourceCard(item: item, coverHeight: coverHeight),
            );
          }).toList(),
        );
      },
    );
  }
}

class _ResourceCard extends ConsumerWidget {
  const _ResourceCard({required this.item, required this.coverHeight});

  final AstroBoxIndexItem item;
  final double coverHeight;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final repo = ref.watch(astroBoxRepositoryProvider);
    final coverUrl = repo.resolveImageUrl(item, item.cover);

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(StyleConstants.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/resources/detail/${item.id}', extra: item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NetworkImgLayer(
              src: coverUrl,
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
                    style: textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _ResourceTypeBadge(type: item.type),
                      const SizedBox(width: 6),
                      if (item.paidType != AstroBoxPaidType.free)
                        _PaidBadge(paidType: item.paidType),
                      const Spacer(),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: colorScheme.outline,
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

class _ResourceTypeBadge extends StatelessWidget {
  const _ResourceTypeBadge({required this.type});

  final AstroBoxResourceType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final label = switch (type) {
      AstroBoxResourceType.quickApp => l10n.quickApp,
      AstroBoxResourceType.watchface => l10n.watchface,
      AstroBoxResourceType.firmware => l10n.firmwareTool,
      AstroBoxResourceType.fontpack => l10n.fontPack,
      AstroBoxResourceType.iconpack => l10n.iconPack,
    };
    return _Badge(label: label, color: colorScheme.primary);
  }
}

class _PaidBadge extends StatelessWidget {
  const _PaidBadge({required this.paidType});

  final AstroBoxPaidType paidType;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (paidType) {
      AstroBoxPaidType.free => l10n.free,
      AstroBoxPaidType.paid => l10n.paid,
      AstroBoxPaidType.forcePaid => l10n.forcePaid,
    };
    return _Badge(label: label, color: Colors.orange);
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

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
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
