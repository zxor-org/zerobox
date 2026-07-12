import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/smooth_linear_progress_indicator.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/features/resources/services/download_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';

class QueuePage extends ConsumerWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.settingsQueue)),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 840;
          final downloadList = const _DownloadQueuePanel();
          final installList = const _InstallQueuePanel();

          return PageContainer(
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.pagePadding,
            ),
            child: isWide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _PanelWrapper(child: downloadList)),
                      Container(
                        width: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: Theme.of(
                          context,
                        ).colorScheme.outlineVariant.withValues(alpha: 0.5),
                      ),
                      Expanded(child: _PanelWrapper(child: installList)),
                    ],
                  )
                : Column(
                    children: [
                      Expanded(child: downloadList),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Divider(height: 1),
                      ),
                      Expanded(child: installList),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _PanelWrapper extends StatelessWidget {
  const _PanelWrapper({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      child: child,
    );
  }
}

class _DownloadQueuePanel extends ConsumerWidget {
  const _DownloadQueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final tasks = ref.watch(downloadQueueProvider);
    final notifier = ref.read(downloadQueueProvider.notifier);

    return _QueuePanel(
      title: l10n.downloadQueueTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (tasks.isNotEmpty)
            IconButton(
              onPressed: notifier.clearTerminal,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.queueClear,
            ),
        ],
      ),
      emptyText: l10n.downloadQueueEmpty,
      children: [
        for (final task in tasks)
          _QueueTile(
            key: ValueKey('download-${task.id}'),
            icon: Icons.downloading,
            title: task.title,
            subtitle: task.subtitle,
            status: task.status,
            progress: task.progress,
            error: task.error,
            onRemove: () => notifier.remove(task.id),
            onRetry: () => notifier.retry(task.id),
          ),
      ],
    );
  }
}

class _InstallQueuePanel extends ConsumerWidget {
  const _InstallQueuePanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(installQueueProvider);
    final notifier = ref.read(installQueueProvider.notifier);
    final running = state.runStatus == QueueRunStatus.running;
    final stopping = state.runStatus == QueueRunStatus.stopping;
    final canStart = state.hasRunnableTasks && !running && !stopping;

    return _QueuePanel(
      title: l10n.installQueueTitle,
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.tasks.isNotEmpty)
            IconButton(
              onPressed: notifier.clearTerminal,
              icon: const Icon(Icons.delete_outline),
              tooltip: l10n.queueClear,
            ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: running
                ? notifier.pause
                : canStart
                ? notifier.start
                : null,
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
            tooltip: running ? l10n.queuePause : l10n.queueStart,
          ),
        ],
      ),
      emptyText: l10n.installQueueEmpty,
      children: [
        for (final task in state.tasks)
          _QueueTile(
            key: ValueKey('install-${task.id}'),
            icon: _installIcon(task.type),
            title: task.name,
            subtitle: _installTaskDescription(l10n, task),
            status: task.status,
            progress: task.progress,
            error: task.error,
            onRemove: () => notifier.remove(task.id),
            onRetry: () => notifier.retry(task.id),
          ),
      ],
    );
  }
}

class _QueuePanel extends StatelessWidget {
  const _QueuePanel({
    required this.title,
    required this.emptyText,
    required this.children,
    this.action,
  });

  final String title;
  final String emptyText;
  final List<Widget> children;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (action != null) action!,
            ],
          ),
        ),
        Expanded(
          child: children.isEmpty
              ? Center(child: Text(emptyText))
              : ListView.separated(
                  itemCount: children.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 8),
                  itemBuilder: (context, index) => children[index],
                ),
        ),
      ],
    );
  }
}

class _QueueTile extends StatelessWidget {
  const _QueueTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.progress,
    this.error,
    required this.onRemove,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;
  final VoidCallback onRemove;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final active =
        status == ResourceTaskStatus.downloading ||
        status == ResourceTaskStatus.installing;

    return Material(
      color: colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        leading: Icon(
          _statusIcon(status, icon),
          color: status == ResourceTaskStatus.failed
              ? colorScheme.error
              : colorScheme.onSurfaceVariant,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (active || status == ResourceTaskStatus.completed) ...[
              const SizedBox(height: 8),
              SmoothLinearProgressIndicator(
                value: progress > 0 ? progress : null,
              ),
              const SizedBox(height: 2),
              Text(
                _statusLabel(l10n, status, progress),
                style: textTheme.bodySmall,
              ),
            ],
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                localizedErrorMessage(l10n, error),
                style: textTheme.bodySmall?.copyWith(color: colorScheme.error),
              ),
            ],
          ],
        ),
        trailing: status == ResourceTaskStatus.failed
            ? IconButton(icon: const Icon(Icons.refresh), onPressed: onRetry)
            : IconButton(icon: const Icon(Icons.close), onPressed: onRemove),
      ),
    );
  }
}

IconData _installIcon(LocalDeviceInstallType type) {
  return switch (type) {
    LocalDeviceInstallType.app => Icons.apps_outlined,
    LocalDeviceInstallType.watchface => Icons.watch_outlined,
    LocalDeviceInstallType.firmware => Icons.memory_outlined,
  };
}

IconData _statusIcon(ResourceTaskStatus status, IconData fallback) {
  return switch (status) {
    ResourceTaskStatus.pending => fallback,
    ResourceTaskStatus.downloading => Icons.downloading,
    ResourceTaskStatus.installing => Icons.memory,
    ResourceTaskStatus.completed => Icons.check_circle_outline,
    ResourceTaskStatus.failed => Icons.error_outline,
  };
}

String _installTaskDescription(AppLocalizations l10n, InstallTask task) {
  if (task.resource != null) return task.description;
  return switch (task.description) {
    'Read failed' => l10n.installQueueReadFailed,
    'Unsupported file' => l10n.installQueueUnsupportedFile,
    _ => switch (task.type) {
      LocalDeviceInstallType.app => l10n.localAppInstall,
      LocalDeviceInstallType.watchface => l10n.localWatchfaceInstall,
      LocalDeviceInstallType.firmware => l10n.localFirmwareInstall,
    },
  };
}

String _statusLabel(
  AppLocalizations l10n,
  ResourceTaskStatus status,
  double progress,
) {
  final percent = (progress * 100).toStringAsFixed(0);
  return switch (status) {
    ResourceTaskStatus.pending => l10n.queueStatusPending,
    ResourceTaskStatus.downloading => l10n.queueStatusDownloading(percent),
    ResourceTaskStatus.installing => l10n.queueStatusInstalling(percent),
    ResourceTaskStatus.completed => l10n.queueStatusCompleted,
    ResourceTaskStatus.failed => l10n.queueStatusFailed,
  };
}
