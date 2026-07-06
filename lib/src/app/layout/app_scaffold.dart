import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
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

    if (width >= LayoutBreakpoint.medium) {
      return _wrapPredictiveBack(
        context,
        _buildSideMenu(context, l10n, badgeCount),
      );
    }
    return _wrapPredictiveBack(
      context,
      _buildBottomMenu(context, l10n, badgeCount),
    );
  }

  Widget _wrapPredictiveBack(BuildContext context, Widget child) {
    final routerCanPop = GoRouter.of(context).canPop();
    final isHomeBranch = navigationShell.currentIndex == 0;

    return PopScope(
      canPop: routerCanPop || isHomeBranch,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop || navigationShell.currentIndex == 0) return;
        navigationShell.goBranch(0);
      },
      child: child,
    );
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
            label: l10n.resourcesTab,
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
  ) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: Row(
        children: [
          NavigationRail(
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            groupAlignment: 1,
            labelType: NavigationRailLabelType.selected,
            destinations: [
              NavigationRailDestination(
                selectedIcon: const Icon(Icons.apps),
                icon: const Icon(Icons.apps_outlined),
                label: Text(l10n.resourcesTab),
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
            ],
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              if (index != navigationShell.currentIndex) {
                navigationShell.goBranch(index);
              }
            },
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
