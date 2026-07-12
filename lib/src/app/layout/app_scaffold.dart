import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final l10n = AppLocalizations.of(context)!;
    final badgeCount = _queueBadgeCount(ref);
    final railPosition = ref.watch(
      appSettingsProvider.select((state) => state.wideNavigationRailPosition),
    );

    if (useWideLayout(width)) {
      return _buildSideMenu(context, l10n, badgeCount, railPosition);
    }
    return _buildBottomMenu(context, l10n, badgeCount);
  }

  Widget _buildBottomMenu(
    BuildContext context,
    AppLocalizations l10n,
    int badgeCount,
  ) {
    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            selectedIcon: const Icon(Icons.apps),
            icon: const Icon(Icons.apps_outlined),
            label: l10n.exploreTab,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.watch),
            icon: const Icon(Icons.watch_outlined),
            label: l10n.devicesTab,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.format_list_bulleted),
            icon: badgeCount > 0
                ? Badge(
                    label: Text('$badgeCount'),
                    child: const Icon(Icons.format_list_bulleted),
                  )
                : const Icon(Icons.format_list_bulleted),
            label: l10n.settingsQueue,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.settings),
            icon: const Icon(Icons.settings_outlined),
            label: l10n.settingsTab,
          ),
        ],
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index != navigationShell.currentIndex) {
            navigationShell.goBranch(index);
          }
        },
      ),
    );
  }

  Widget _buildSideMenu(
    BuildContext context,
    AppLocalizations l10n,
    int badgeCount,
    WideNavigationRailPosition railPosition,
  ) {
    final destinations = _navigationRailDestinations(l10n, badgeCount);
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          SizedBox(
            width: 80,
            child: _WideNavigationRail(
              position: railPosition,
              destinations: destinations,
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: (index) {
                if (index != navigationShell.currentIndex) {
                  navigationShell.goBranch(index);
                }
              },
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(28),
                  bottomLeft: Radius.circular(28),
                ),
                child: navigationShell,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<NavigationRailDestination> _navigationRailDestinations(
    AppLocalizations l10n,
    int badgeCount,
  ) {
    return [
      NavigationRailDestination(
        selectedIcon: const Icon(Icons.apps),
        icon: const Icon(Icons.apps_outlined),
        label: Text(l10n.exploreTab),
      ),
      NavigationRailDestination(
        selectedIcon: const Icon(Icons.watch),
        icon: const Icon(Icons.watch_outlined),
        label: Text(l10n.devicesTab),
      ),
      NavigationRailDestination(
        selectedIcon: const Icon(Icons.format_list_bulleted),
        icon: badgeCount > 0
            ? Badge(
                label: Text('$badgeCount'),
                child: const Icon(Icons.format_list_bulleted),
              )
            : const Icon(Icons.format_list_bulleted),
        label: Text(l10n.settingsQueue),
      ),
      NavigationRailDestination(
        selectedIcon: const Icon(Icons.settings),
        icon: const Icon(Icons.settings_outlined),
        label: Text(l10n.settingsTab),
      ),
    ];
  }

  int _queueBadgeCount(WidgetRef ref) {
    final downloadCount = ref.watch(
      downloadQueueProvider.select(
        (tasks) =>
            tasks.where((t) => t.status != ResourceTaskStatus.completed).length,
      ),
    );
    final installCount = ref.watch(
      installQueueProvider.select(
        (state) => state.tasks
            .where((t) => t.status != ResourceTaskStatus.completed)
            .length,
      ),
    );
    return downloadCount + installCount;
  }
}

class _WideNavigationRail extends StatelessWidget {
  const _WideNavigationRail({
    required this.position,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final WideNavigationRailPosition position;
  final List<NavigationRailDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainer;
    if (position != WideNavigationRailPosition.split) {
      return NavigationRail(
        backgroundColor: color,
        groupAlignment: switch (position) {
          WideNavigationRailPosition.center => 0,
          _ => 1,
        },
        labelType: NavigationRailLabelType.selected,
        destinations: destinations,
        selectedIndex: selectedIndex,
        onDestinationSelected: onDestinationSelected,
      );
    }

    return Material(
      color: color,
      child: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: NavigationRail(
                backgroundColor: color,
                groupAlignment: 0,
                labelType: NavigationRailLabelType.selected,
                destinations: destinations.take(3).toList(growable: false),
                selectedIndex: selectedIndex < 3 ? selectedIndex : null,
                onDestinationSelected: onDestinationSelected,
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SizedBox(
                height: 96,
                child: NavigationRail(
                  backgroundColor: color,
                  groupAlignment: 0,
                  labelType: NavigationRailLabelType.selected,
                  destinations: [destinations[3]],
                  selectedIndex: selectedIndex == 3 ? 0 : null,
                  onDestinationSelected: (_) => onDestinationSelected(3),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
