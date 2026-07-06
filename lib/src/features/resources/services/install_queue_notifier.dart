import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/protocols/common/device_protocol.dart' as proto;

export 'package:zerobox/src/features/resources/services/resource_install_service.dart'
    show LocalDeviceInstallType, ResourceTaskStatus;

enum QueueRunStatus { pending, running, stopping }

class InstallTask {
  const InstallTask({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    required this.filePath,
    this.item,
    this.manifest,
    this.download,
    this.deleteAfterInstall = false,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  factory InstallTask.local({
    required String path,
    required String fileName,
    required LocalDeviceInstallType type,
  }) {
    return InstallTask(
      id: path,
      name: fileName,
      description: _localTypeDescription(type),
      type: type,
      filePath: path,
    );
  }

  factory InstallTask.resource({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required String codename,
    required String filePath,
  }) {
    return InstallTask(
      id: '${item.id}_$codename',
      name: item.name,
      description: codename,
      type: _installTypeForResource(item.type),
      filePath: filePath,
      item: item,
      manifest: manifest,
      download: download,
      deleteAfterInstall: true,
    );
  }

  final String id;
  final String name;
  final String description;
  final LocalDeviceInstallType type;
  final String filePath;
  final AstroBoxIndexItem? item;
  final AstroBoxManifest? manifest;
  final AstroBoxManifestDownload? download;
  final bool deleteAfterInstall;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;

  InstallTask copyWith({
    ResourceTaskStatus? status,
    double? progress,
    String? error,
  }) {
    return InstallTask(
      id: id,
      name: name,
      description: description,
      type: type,
      filePath: filePath,
      item: item,
      manifest: manifest,
      download: download,
      deleteAfterInstall: deleteAfterInstall,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error,
    );
  }
}

class InstallQueueState {
  const InstallQueueState({
    this.tasks = const [],
    this.runStatus = QueueRunStatus.pending,
  });

  final List<InstallTask> tasks;
  final QueueRunStatus runStatus;

  bool get isRunning => runStatus == QueueRunStatus.running;
  bool get isStopping => runStatus == QueueRunStatus.stopping;
  bool get hasRunnableTasks => tasks.any(
    (task) =>
        task.status == ResourceTaskStatus.pending ||
        task.status == ResourceTaskStatus.failed,
  );
  double get progress {
    if (tasks.isEmpty) return 1;
    return tasks.fold<double>(0, (sum, task) => sum + task.progress) /
        tasks.length;
  }

  InstallQueueState copyWith({
    List<InstallTask>? tasks,
    QueueRunStatus? runStatus,
  }) {
    return InstallQueueState(
      tasks: tasks ?? this.tasks,
      runStatus: runStatus ?? this.runStatus,
    );
  }
}

class InstallQueueNotifier extends Notifier<InstallQueueState> {
  @override
  InstallQueueState build() => const InstallQueueState();

  void enqueueLocalFile(String path) {
    final service = ResourceInstallService();
    final fileName = Uri.decodeComponent(Uri.file(path).pathSegments.last);

    // Type detection reads the file, so do it asynchronously without blocking
    // the drop event. Unsupported files become failed tasks instead of silent no-ops.
    Future<void>(() async {
      final bytes = await File(path).readAsBytes();
      final type = service.detectLocalInstallType(fileName, bytes);
      if (type == null) {
        final task = InstallTask(
          id: path,
          name: fileName,
          description: '不支持的文件',
          type: LocalDeviceInstallType.app,
          filePath: path,
          status: ResourceTaskStatus.failed,
          error: '不支持或无法识别的文件类型',
        );
        _addTask(task);
        return;
      }
      _addTask(InstallTask.local(path: path, fileName: fileName, type: type));
    });
  }

  void enqueueResource({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required String codename,
    required String filePath,
  }) {
    _addTask(
      InstallTask.resource(
        item: item,
        manifest: manifest,
        download: download,
        codename: codename,
        filePath: filePath,
      ),
    );
    if (ref.read(appSettingsProvider).autoInstall) {
      start();
    }
  }

  void _addTask(InstallTask task) {
    if (state.tasks.any(
      (existing) =>
          existing.id == task.id &&
          existing.status != ResourceTaskStatus.completed,
    )) {
      return;
    }
    state = state.copyWith(tasks: [...state.tasks, task]);
  }

  void remove(String taskId) {
    state = state.copyWith(
      tasks: state.tasks.where((task) => task.id != taskId).toList(),
      runStatus: state.tasks.length <= 1
          ? QueueRunStatus.pending
          : state.runStatus,
    );
  }

  void clearCompleted() {
    state = state.copyWith(
      tasks: state.tasks
          .where((task) => task.status != ResourceTaskStatus.completed)
          .toList(),
    );
  }

  void retry(String taskId) {
    state = state.copyWith(
      tasks: [
        for (final task in state.tasks)
          if (task.id == taskId)
            task.copyWith(
              status: ResourceTaskStatus.pending,
              progress: 0,
              error: null,
            )
          else
            task,
      ],
    );
  }

  void start() {
    if (state.isRunning || !state.hasRunnableTasks) return;
    state = state.copyWith(runStatus: QueueRunStatus.running);
    _run();
  }

  void pause() {
    if (!state.isRunning) return;
    state = state.copyWith(runStatus: QueueRunStatus.stopping);
  }

  Future<void> _run() async {
    while (state.runStatus == QueueRunStatus.running) {
      final next = state.tasks.cast<InstallTask?>().firstWhere(
        (task) =>
            task?.status == ResourceTaskStatus.pending ||
            task?.status == ResourceTaskStatus.failed,
        orElse: () => null,
      );
      if (next == null) break;

      await _runTask(next);

      if (state.runStatus == QueueRunStatus.stopping) {
        state = state.copyWith(runStatus: QueueRunStatus.pending);
        return;
      }
    }

    final settings = ref.read(appSettingsProvider);
    if (!settings.disableAutoClean) {
      state = state.copyWith(
        tasks: state.tasks
            .where((task) => task.status != ResourceTaskStatus.completed)
            .toList(),
        runStatus: QueueRunStatus.pending,
      );
      return;
    }
    state = state.copyWith(runStatus: QueueRunStatus.pending);
  }

  Future<void> _runTask(InstallTask task) async {
    final service = ResourceInstallService();
    final deviceState = ref.read(deviceManagerProvider);
    if (deviceState.protocolState != proto.ProtocolState.ready ||
        deviceState.currentDevice == null ||
        deviceState.currentDevice!.disconnected) {
      _updateTask(task.id, ResourceTaskStatus.failed, 0, '未连接设备');
      return;
    }
    final deviceManager = ref.read(deviceManagerProvider.notifier);

    if (task.item != null && task.manifest != null && task.download != null) {
      await service.installDownloadedResource(
        item: task.item!,
        manifest: task.manifest!,
        download: task.download!,
        filePath: task.filePath,
        deviceManager: deviceManager,
        deleteAfterInstall: task.deleteAfterInstall,
        onUpdate: (status, progress, error) {
          _updateTask(task.id, status, progress, error);
        },
      );
      return;
    }

    await service.installLocalFile(
      filePath: task.filePath,
      deviceManager: deviceManager,
      onUpdate: (status, progress, error) {
        _updateTask(task.id, status, progress, error);
      },
    );
  }

  void _updateTask(
    String taskId,
    ResourceTaskStatus status,
    double progress,
    String? error,
  ) {
    state = state.copyWith(
      tasks: [
        for (final task in state.tasks)
          if (task.id == taskId)
            task.copyWith(status: status, progress: progress, error: error)
          else
            task,
      ],
    );
  }
}

String _localTypeDescription(LocalDeviceInstallType type) {
  return switch (type) {
    LocalDeviceInstallType.app => '本地应用安装',
    LocalDeviceInstallType.watchface => '本地表盘安装',
    LocalDeviceInstallType.firmware => '本地固件安装',
  };
}

LocalDeviceInstallType _installTypeForResource(AstroBoxResourceType type) {
  return switch (type) {
    AstroBoxResourceType.quickApp => LocalDeviceInstallType.app,
    AstroBoxResourceType.watchface => LocalDeviceInstallType.watchface,
    AstroBoxResourceType.firmware => LocalDeviceInstallType.firmware,
    AstroBoxResourceType.fontpack || AstroBoxResourceType.iconpack =>
      throw UnsupportedError('$type install not implemented yet'),
  };
}

final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );
