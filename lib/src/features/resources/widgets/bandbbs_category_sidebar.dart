import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/data/bandbbs/bandbbs_resource_provider.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/controllers/resource_filter_controller.dart';

/// Responsive category sidebar for the BandBBS source, modeled after the
/// bandbbs.cn category tree: expandable groups with aggregate resource
/// counts, single-selection filtering.
class BandBbsCategorySidebar extends ConsumerStatefulWidget {
  const BandBbsCategorySidebar({super.key});

  static const categoryFilterPrefix = 'bandbbs-category:';

  @override
  ConsumerState<BandBbsCategorySidebar> createState() =>
      _BandBbsCategorySidebarState();
}

class _BandBbsCategorySidebarState
    extends ConsumerState<BandBbsCategorySidebar> {
  final _expanded = <int>{};
  var _initialized = false;

  void _initExpanded(List<BandBbsCategoryNode> roots) {
    if (_initialized) return;
    _initialized = true;
    _expanded.addAll(roots.map((node) => node.id));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final selected = ref.watch(
      resourceFiltersProvider.select((filters) => filters.selectedDevices),
    );
    final tree = ref.watch(bandbbsCategoryTreeProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      child: Material(
        color: theme.colorScheme.surfaceContainerLow.withValues(alpha: .5),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: tree.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const SizedBox.shrink(),
          data: (roots) {
            _initExpanded(roots);
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
              children: [
                _CategoryTile(
                  title: l10n.all,
                  count: null,
                  depth: 0,
                  selected: selected.isEmpty,
                  onTap: () =>
                      ref.read(resourceFiltersProvider.notifier).clearDevices(),
                ),
                for (final root in roots)
                  _CategoryNodeTile(
                    node: root,
                    depth: 0,
                    expanded: _expanded,
                    selected: selected,
                    onToggle: (id) => setState(() {
                      if (!_expanded.add(id)) _expanded.remove(id);
                    }),
                    onSelect: (node) {
                      ref
                          .read(resourceFiltersProvider.notifier)
                          .selectDevice(
                            '${BandBbsCategorySidebar.categoryFilterPrefix}${node.id}',
                          );
                    },
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CategoryNodeTile extends StatelessWidget {
  const _CategoryNodeTile({
    required this.node,
    required this.depth,
    required this.expanded,
    required this.selected,
    required this.onToggle,
    required this.onSelect,
  });

  final BandBbsCategoryNode node;
  final int depth;
  final Set<int> expanded;
  final Set<String> selected;
  final ValueChanged<int> onToggle;
  final ValueChanged<BandBbsCategoryNode> onSelect;

  @override
  Widget build(BuildContext context) {
    final hasChildren = node.children.isNotEmpty;
    final isExpanded = expanded.contains(node.id);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CategoryTile(
          title: node.title,
          count: node.resourceCount,
          depth: depth,
          selected: selected.contains(
            '${BandBbsCategorySidebar.categoryFilterPrefix}${node.id}',
          ),
          expanded: hasChildren ? isExpanded : null,
          onTap: () {
            onSelect(node);
            if (hasChildren && !isExpanded) onToggle(node.id);
          },
          onExpandTap: hasChildren ? () => onToggle(node.id) : null,
        ),
        if (hasChildren && isExpanded)
          for (final child in node.children)
            _CategoryNodeTile(
              node: child,
              depth: depth + 1,
              expanded: expanded,
              selected: selected,
              onToggle: onToggle,
              onSelect: onSelect,
            ),
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.title,
    required this.count,
    required this.depth,
    required this.selected,
    required this.onTap,
    this.expanded,
    this.onExpandTap,
  });

  final String title;
  final int? count;
  final int depth;
  final bool selected;
  final VoidCallback onTap;
  final bool? expanded;
  final VoidCallback? onExpandTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected ? color.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.fromLTRB(12.0 + depth * 16, 8, 8, 8),
            child: Row(
              children: [
                if (onExpandTap != null)
                  InkWell(
                    onTap: onExpandTap,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        expanded == true
                            ? Icons.expand_more
                            : Icons.chevron_right,
                        size: 18,
                        color: selected
                            ? color.onPrimaryContainer
                            : color.onSurfaceVariant,
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 22),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: selected
                          ? color.onPrimaryContainer
                          : color.onSurface,
                      fontWeight: selected ? FontWeight.w700 : null,
                    ),
                  ),
                ),
                if (count != null)
                  Text(
                    _formatCount(count!),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: selected
                          ? color.onPrimaryContainer
                          : color.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000) return '${count ~/ 1000}K';
    return '$count';
  }
}
