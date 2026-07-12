import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
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
    this.bytes,
    this.resource,
    this.file,
    this.deleteAfterInstall = false,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  factory InstallTask.local({
    required String path,
    required String fileName,
    required LocalDeviceInstallType type,
    Uint8List? bytes,
  }) {
    return InstallTask(
      id: path,
      name: fileName,
      description: _localTypeDescription(type),
      type: type,
      filePath: path,
      bytes: bytes,
    );
  }

  factory InstallTask.resource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
    required String filePath,
    Uint8List? bytes,
  }) {
    return InstallTask(
      id: '${resource.ref.key}:${file.id}:$codename',
      name: resource.name,
      description: codename,
      type: _installTypeForResource(resource.type),
      filePath: filePath,
      bytes: bytes,
      resource: resource,
      file: file,
      deleteAfterInstall: true,
    );
  }

  final String id;
  final String name;
  final String description;
  final LocalDeviceInstallType type;
  final String filePath;
  final Uint8List? bytes;
  final CommunityResourceDetail? resource;
  final CommunityResourceFile? file;
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
      bytes: bytes,
      resource: resource,
      file: file,
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

  void enqueueLocalFile(XFile file) {
    final service = ResourceInstallService();
    final fileName = file.name;

    Future<void>(() async {
      Uint8List bytes;
      try {
        bytes = await file.readAsBytes();
      } catch (e) {
        final task = InstallTask(
          id: file.path,
          name: fileName,
          description: 'Read failed',
          type: LocalDeviceInstallType.app,
          filePath: file.path,
          status: ResourceTaskStatus.failed,
          error: 'Read failed: $e',
        );
        _addTask(task);
        return;
      }
      final type = service.detectLocalInstallType(fileName, bytes);
      if (type == null) {
        final task = InstallTask(
          id: file.path,
          name: fileName,
          description: 'Unsupported file',
          type: LocalDeviceInstallType.app,
          filePath: file.path,
          bytes: bytes,
          status: ResourceTaskStatus.failed,
          error: 'Unsupported or unrecognized file type',
        );
        _addTask(task);
        return;
      }
      _addTask(
        InstallTask.local(
          path: file.path,
          fileName: fileName,
          type: type,
          bytes: bytes,
        ),
      );
    });
  }

  void enqueueResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
    required String filePath,
    Uint8List? bytes,
  }) {
    _addTask(
      InstallTask.resource(
        resource: resource,
        file: file,
        codename: codename,
        filePath: filePath,
        bytes: bytes,
      ),
    );
    if (ref.read(appSettingsProvider).autoInstall && _deviceReady()) {
      start();
    }
  }

  bool _deviceReady() {
    final deviceState = ref.read(deviceManagerProvider);
    return deviceState.protocolState == proto.ProtocolState.ready &&
        deviceState.currentDevice != null &&
        !deviceState.currentDevice!.disconnected;
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

  void clearTerminal() {
    state = state.copyWith(
      tasks: state.tasks
          .where(
            (task) =>
                task.status != ResourceTaskStatus.completed &&
                task.status != ResourceTaskStatus.failed,
          )
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
    final hasPending = state.tasks.any(
      (task) => task.status == ResourceTaskStatus.pending,
    );
    if (!hasPending) {
      state = state.copyWith(
        tasks: [
          for (final task in state.tasks)
            if (task.status == ResourceTaskStatus.failed)
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
        (task) => task?.status == ResourceTaskStatus.pending,
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
      _updateTask(task.id, ResourceTaskStatus.failed, 0, 'Device not ready');
      return;
    }
    final deviceManager = ref.read(deviceManagerProvider.notifier);

    if (task.resource != null && task.file != null) {
      await service.installDownloadedResource(
        resource: task.resource!,
        file: task.file!,
        filePath: task.filePath,
        bytes: task.bytes,
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
      bytes: task.bytes,
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
    final current = state.tasks.cast<InstallTask?>().firstWhere(
      (task) => task?.id == taskId,
      orElse: () => null,
    );
    if (current == null) return;
    final currentIsTerminal =
        current.status == ResourceTaskStatus.failed ||
        current.status == ResourceTaskStatus.completed;
    final nextIsTerminal =
        status == ResourceTaskStatus.failed ||
        status == ResourceTaskStatus.completed;
    if (currentIsTerminal && !nextIsTerminal) {
      return;
    }

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
    LocalDeviceInstallType.app => 'Local app install',
    LocalDeviceInstallType.watchface => 'Local watchface install',
    LocalDeviceInstallType.firmware => 'Local firmware install',
  };
}

LocalDeviceInstallType _installTypeForResource(CommunityResourceType type) {
  return switch (type) {
    CommunityResourceType.quickApp => LocalDeviceInstallType.app,
    CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
    CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
    CommunityResourceType.fontpack || CommunityResourceType.iconpack =>
      throw UnsupportedError('$type install not implemented yet'),
  };
}

final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );
