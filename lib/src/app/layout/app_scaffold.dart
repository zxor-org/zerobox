import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';

class AppScaffold extends ConsumerWidget {
  const AppScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final l10n = AppLocalizations.of(context)!;

    if (width >= LayoutBreakpoint.medium) {
      return _wrapPredictiveBack(context, _buildSideMenu(context, l10n));
    }
    return _wrapPredictiveBack(context, _buildBottomMenu(context, l10n, ref));
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
    WidgetRef ref,
  ) {
    final badgeCount = ref.watch(
      downloadQueueProvider.select(
        (tasks) =>
            tasks.where((t) => t.status != ResourceTaskStatus.completed).length,
      ),
    );

    return Scaffold(
      body: Container(
        color: Theme.of(context).colorScheme.surfaceContainer,
        child: navigationShell,
      ),
      bottomNavigationBar: NavigationBar(
        destinations: [
          NavigationDestination(
            selectedIcon: const Icon(Icons.home),
            icon: const Icon(Icons.home_outlined),
            label: l10n.homeTab,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.apps),
            icon: const Icon(Icons.apps_outlined),
            label: l10n.resourcesTab,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.watch),
            icon: badgeCount > 0
                ? Badge(child: const Icon(Icons.watch_outlined))
                : const Icon(Icons.watch_outlined),
            label: l10n.devicesTab,
          ),
          NavigationDestination(
            selectedIcon: const Icon(Icons.settings),
            icon: const Icon(Icons.settings_outlined),
            label: l10n.settingsTab,
          ),
        ],
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) {
          if (index == navigationShell.currentIndex) {
            _onSameTabSelected(context, index);
          } else {
            navigationShell.goBranch(index);
          }
        },
      ),
    );
  }

  Widget _buildSideMenu(BuildContext context, AppLocalizations l10n) {
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
                selectedIcon: const Icon(Icons.home),
                icon: const Icon(Icons.home_outlined),
                label: Text(l10n.homeTab),
              ),
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
                selectedIcon: const Icon(Icons.settings),
                icon: const Icon(Icons.settings_outlined),
                label: Text(l10n.settingsTab),
              ),
            ],
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: (index) {
              if (index == navigationShell.currentIndex) {
                _onSameTabSelected(context, index);
              } else {
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

  void _onSameTabSelected(BuildContext context, int index) {
    if (index == 2) {
      showDeviceQueueSheet(context);
    }
  }
}

void showDeviceQueueSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const DeviceTaskQueueSheet(),
  );
}

class DeviceTaskQueueSheet extends StatelessWidget {
  const DeviceTaskQueueSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '下载/安装队列',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Consumer(
                    builder: (context, ref, child) {
                      final hasCompleted = ref.watch(
                        downloadQueueProvider.select(
                          (tasks) => tasks.any(
                            (t) => t.status == ResourceTaskStatus.completed,
                          ),
                        ),
                      );
                      if (!hasCompleted) return const SizedBox.shrink();
                      return TextButton(
                        onPressed: () {
                          ref
                              .read(downloadQueueProvider.notifier)
                              .clearCompleted();
                        },
                        child: const Text('清除已完成'),
                      );
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Consumer(
                builder: (context, ref, child) {
                  final tasks = ref.watch(downloadQueueProvider);
                  if (tasks.isEmpty) {
                    return const Center(child: Text('暂无任务'));
                  }
                  return ListView.builder(
                    controller: scrollController,
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return _TaskTile(task: task);
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TaskTile extends ConsumerWidget {
  const _TaskTile({required this.task});

  final ResourceTask task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListTile(
      leading: _leadingIcon(task.status, colorScheme),
      title: Text(task.item.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${task.manifest.item.author.firstOrNull?.name ?? task.item.repoOwner} · ${task.codename}',
          ),
          if (task.status == ResourceTaskStatus.downloading ||
              task.status == ResourceTaskStatus.installing) ...[
            const SizedBox(height: 6),
            SmoothLinearProgressIndicator(value: task.progress),
            const SizedBox(height: 2),
            Text(
              task.status == ResourceTaskStatus.downloading
                  ? '下载中 ${(task.progress * 100).toInt()}%'
                  : '安装中 ${(task.progress * 100).toInt()}%',
              style: textTheme.bodySmall,
            ),
          ],
          if (task.error != null && task.error!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              task.error!,
              style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
            ),
          ],
        ],
      ),
      trailing: _trailingButton(context, ref),
      isThreeLine: task.error != null && task.error!.isNotEmpty,
    );
  }

  Widget _leadingIcon(ResourceTaskStatus status, ColorScheme colorScheme) {
    return switch (status) {
      ResourceTaskStatus.pending => const Icon(Icons.hourglass_empty),
      ResourceTaskStatus.downloading => const Icon(Icons.downloading),
      ResourceTaskStatus.installing => const Icon(Icons.memory),
      ResourceTaskStatus.completed => Icon(
        Icons.check_circle,
        color: colorScheme.primary,
      ),
      ResourceTaskStatus.failed => Icon(Icons.error, color: colorScheme.error),
    };
  }

  Widget? _trailingButton(BuildContext context, WidgetRef ref) {
    return switch (task.status) {
      ResourceTaskStatus.pending => IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          ref.read(downloadQueueProvider.notifier).remove(task.id);
        },
      ),
      ResourceTaskStatus.downloading ||
      ResourceTaskStatus.installing => IconButton(
        icon: const Icon(Icons.stop_circle_outlined),
        onPressed: () {
          ref.read(downloadQueueProvider.notifier).remove(task.id);
        },
      ),
      ResourceTaskStatus.failed => IconButton(
        icon: const Icon(Icons.refresh),
        onPressed: () {
          ref.read(downloadQueueProvider.notifier).retry(task.id);
        },
      ),
      ResourceTaskStatus.completed => IconButton(
        icon: const Icon(Icons.delete_outline),
        onPressed: () {
          ref.read(downloadQueueProvider.notifier).remove(task.id);
        },
      ),
    };
  }
}
