import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
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
                : ListView(
                    children: [
                      SizedBox(height: 420, child: downloadList),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Divider(height: 1),
                      ),
                      SizedBox(height: 520, child: installList),
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
    final tasks = ref.watch(downloadQueueProvider);
    final notifier = ref.read(downloadQueueProvider.notifier);

    return _QueuePanel(
      title: '下载队列',
      action: tasks.any((task) => task.status == ResourceTaskStatus.completed)
          ? TextButton(
              onPressed: notifier.clearCompleted,
              child: const Text('清除已完成'),
            )
          : null,
      emptyText: '暂无下载任务',
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
    final state = ref.watch(installQueueProvider);
    final notifier = ref.read(installQueueProvider.notifier);
    final running = state.runStatus == QueueRunStatus.running;
    final stopping = state.runStatus == QueueRunStatus.stopping;
    final canStart = state.hasRunnableTasks && !running && !stopping;

    return _QueuePanel(
      title: '安装队列',
      action: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (state.tasks.any(
            (task) => task.status == ResourceTaskStatus.completed,
          ))
            TextButton(
              onPressed: notifier.clearCompleted,
              child: const Text('清除已完成'),
            ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: running
                ? notifier.pause
                : canStart
                ? notifier.start
                : null,
            icon: Icon(running ? Icons.pause : Icons.play_arrow),
            label: Text(running ? '暂停' : '开始'),
          ),
        ],
      ),
      emptyText: '暂无安装任务',
      children: [
        for (final task in state.tasks)
          _QueueTile(
            key: ValueKey('install-${task.id}'),
            icon: _installIcon(task.type),
            title: task.name,
            subtitle: task.description,
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
              Text(_statusLabel(status, progress), style: textTheme.bodySmall),
            ],
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                error!,
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

String _statusLabel(ResourceTaskStatus status, double progress) {
  final percent = (progress * 100).toStringAsFixed(0);
  return switch (status) {
    ResourceTaskStatus.pending => '等待中',
    ResourceTaskStatus.downloading => '下载中 $percent%',
    ResourceTaskStatus.installing => '安装中 $percent%',
    ResourceTaskStatus.completed => '已完成',
    ResourceTaskStatus.failed => '失败',
  };
}
