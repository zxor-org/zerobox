import 'dart:async';
import 'dart:io';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/community_resource_codec.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';
import 'package:zerobox/src/host/application_host_provider.dart';
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
    this.installMode = ResourceInstallMode.automatic,
    required this.filePath,
    this.bytes,
    this.resource,
    this.file,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String id;
  final String name;
  final String description;
  final LocalDeviceInstallType type;
  final ResourceInstallMode installMode;
  final String filePath;
  final Uint8List? bytes;
  final CommunityResourceDetail? resource;
  final CommunityResourceFile? file;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;
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
  double get progress => tasks.isEmpty
      ? 1
      : tasks.fold<double>(0, (sum, task) => sum + task.progress) /
            tasks.length;
}

class InstallQueueNotifier extends Notifier<InstallQueueState> {
  StreamSubscription<CommandEvent>? _subscription;

  @override
  InstallQueueState build() {
    if (kIsWeb) {
      ref.listen(deviceManagerProvider, (_, _) {});
      return const InstallQueueState();
    }
    final host = ref.watch(applicationHostProvider);
    _subscription = host.events.listen(_handleEvent);
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    scheduleMicrotask(_refresh);
    return const InstallQueueState();
  }

  Future<void> _refresh() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const ZeroBoxCommand(method: 'queue.list'));
    if (!result.ok || result.value is! List) return;
    _replaceFromRows((result.value as List).whereType<Map>());
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'host.connected') {
      unawaited(_refresh());
      return;
    }
    if (event.event == 'task.removed') {
      final id = event.data['id']?.toString();
      state = InstallQueueState(
        tasks: state.tasks.where((task) => task.id != id).toList(),
        runStatus: state.runStatus,
      );
      return;
    }
    if (event.event != 'task') return;
    final view = DaemonTaskView.fromJson(event.data);
    if (view.method != 'install.local') return;
    final task = _fromView(view);
    final tasks = [...state.tasks];
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    _setTasks(tasks);
  }

  void _replaceFromRows(Iterable<Map> rows) {
    _setTasks(
      rows
          .map((row) => DaemonTaskView.fromJson(row.cast<String, Object?>()))
          .where((view) => view.method == 'install.local')
          .map(_fromView)
          .toList(),
    );
  }

  void _setTasks(List<InstallTask> tasks) {
    final running = tasks.any(
      (task) =>
          task.status == ResourceTaskStatus.installing ||
          task.status == ResourceTaskStatus.downloading,
    );
    state = InstallQueueState(
      tasks: tasks,
      runStatus: running ? QueueRunStatus.running : QueueRunStatus.pending,
    );
  }

  InstallTask _fromView(DaemonTaskView view) {
    final typeName = view.params['type']?.toString() ?? 'quickapp';
    final resourceJson = view.params['resource'];
    final resource = resourceJson is Map
        ? communityResourceDetailFromJson(resourceJson.cast<String, Object?>())
        : null;
    final fileId = view.params['file']?.toString();
    final resourceFile = resource?.files
        .where((file) => file.id == fileId)
        .firstOrNull;
    return InstallTask(
      id: view.id,
      name:
          view.params['title']?.toString() ??
          view.path?.split(Platform.pathSeparator).last ??
          'Local install',
      description: view.params['description']?.toString().isNotEmpty == true
          ? view.params['description']!.toString()
          : typeName,
      type: switch (typeName) {
        'watchface' => LocalDeviceInstallType.watchface,
        'firmware' => LocalDeviceInstallType.firmware,
        _ => LocalDeviceInstallType.app,
      },
      installMode: ResourceInstallMode.values.firstWhere(
        (mode) => mode.name == view.params['installMode']?.toString(),
        orElse: () => ResourceInstallMode.automatic,
      ),
      filePath: view.path ?? '',
      resource: resource,
      file: resourceFile,
      status: switch (view.status) {
        'running' => ResourceTaskStatus.installing,
        'completed' => ResourceTaskStatus.completed,
        'failed' || 'cancelled' => ResourceTaskStatus.failed,
        _ => ResourceTaskStatus.pending,
      },
      progress: view.progress,
      error: view.error,
    );
  }

  void enqueueLocalFile(XFile file) {
    unawaited(_enqueueLocalFile(file));
  }

  Future<void> _enqueueLocalFile(XFile file) async {
    final bytes = await file.readAsBytes();
    if (kIsWeb) {
      final type = ResourceInstallService().detectLocalInstallType(
        file.name,
        bytes,
      );
      final task = InstallTask(
        id: file.path,
        name: file.name,
        description: type?.name ?? 'Unsupported file',
        type: type ?? LocalDeviceInstallType.app,
        filePath: file.path,
        bytes: bytes,
        status: type == null
            ? ResourceTaskStatus.failed
            : ResourceTaskStatus.pending,
        error: type == null ? 'Unsupported or unrecognized file type' : null,
      );
      _addWebTask(task);
      return;
    }
    final path = await _stage(file.name, bytes);
    await _enqueue(
      ZeroBoxCommand(
        method: 'install.local',
        params: {
          'type': 'auto',
          'path': path,
          'title': file.name,
          'deleteAfter': true,
          'autoClean': true,
        },
      ),
    );
  }

  Future<void> enqueueConfirmedLocalFile(
    XFile file, {
    required LocalDeviceInstallType type,
    required ResourceInstallMode installMode,
  }) async {
    final bytes = await file.readAsBytes();
    if (kIsWeb) {
      _addWebTask(
        InstallTask(
          id: '${file.path}:${DateTime.now().microsecondsSinceEpoch}',
          name: file.name,
          description: type.name,
          type: type,
          installMode: installMode,
          filePath: file.path,
          bytes: bytes,
        ),
      );
      start();
      return;
    }
    final path = await _stage(file.name, bytes);
    await _enqueue(
      ZeroBoxCommand(
        method: 'install.local',
        params: {
          'type': type.name,
          'installMode': installMode.name,
          'path': path,
          'title': file.name,
          'deleteAfter': true,
          'autoClean': true,
        },
      ),
    );
    await ref
        .read(applicationHostProvider)
        .execute(const ZeroBoxCommand(method: 'queue.start'));
  }

  Future<String> _stage(String name, Uint8List bytes) async {
    final directory = await getTemporaryDirectory();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final file = File(
      '${directory.path}${Platform.pathSeparator}'
      'zerobox_queue_${DateTime.now().microsecondsSinceEpoch}_$safeName',
    );
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> _enqueue(ZeroBoxCommand command) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          ZeroBoxCommand(
            method: 'task.enqueue',
            params: {'held': true, 'command': command.toJson()},
          ),
        );
    if (!result.ok) throw StateError(result.error!.message);
    await _refresh();
  }

  void enqueueResource({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
    required String filePath,
    Uint8List? bytes,
  }) {
    assert(kIsWeb);
    _addWebTask(
      InstallTask(
        id: '${resource.ref.key}:${file.id}:$codename',
        name: resource.name,
        description: codename,
        type: switch (resource.type) {
          CommunityResourceType.quickApp => LocalDeviceInstallType.app,
          CommunityResourceType.watchface => LocalDeviceInstallType.watchface,
          CommunityResourceType.firmware => LocalDeviceInstallType.firmware,
          CommunityResourceType.fontpack || CommunityResourceType.iconpack =>
            throw UnsupportedError('${resource.type} install not implemented'),
        },
        filePath: filePath,
        bytes: bytes,
        resource: resource,
        file: file,
      ),
    );
    if (ref.read(appSettingsProvider).autoInstall && _webDeviceReady()) {
      start();
    }
  }

  void _addWebTask(InstallTask task) {
    if (state.tasks.any(
      (item) =>
          item.id == task.id && item.status != ResourceTaskStatus.completed,
    )) {
      return;
    }
    state = InstallQueueState(
      tasks: [...state.tasks, task],
      runStatus: state.runStatus,
    );
  }

  bool _webDeviceReady() {
    final device = ref.read(deviceManagerProvider);
    return device.protocolState == proto.ProtocolState.ready &&
        device.currentDevice != null &&
        !device.currentDevice!.disconnected;
  }

  void remove(String taskId) => unawaited(_remove(taskId));
  Future<void> _remove(String taskId) async {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: state.tasks.where((task) => task.id != taskId).toList(),
        runStatus: state.tasks.length <= 1
            ? QueueRunStatus.pending
            : state.runStatus,
      );
      return;
    }
    final task = state.tasks.where((task) => task.id == taskId).firstOrNull;
    final terminal =
        task == null ||
        task.status == ResourceTaskStatus.completed ||
        task.status == ResourceTaskStatus.failed;
    final host = ref.read(applicationHostProvider);
    await host.execute(
      ZeroBoxCommand(
        method: terminal ? 'queue.remove' : 'queue.cancel',
        params: {'id': taskId},
      ),
    );
    if (!terminal) {
      await host.execute(
        ZeroBoxCommand(method: 'queue.remove', params: {'id': taskId}),
      );
    }
  }

  void clearTerminal() {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: state.tasks
            .where(
              (task) =>
                  task.status != ResourceTaskStatus.completed &&
                  task.status != ResourceTaskStatus.failed,
            )
            .toList(),
        runStatus: state.runStatus,
      );
      return;
    }
    for (final task in state.tasks.where(
      (task) =>
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    )) {
      unawaited(_remove(task.id));
    }
  }

  void retry(String taskId) {
    if (kIsWeb) {
      state = InstallQueueState(
        tasks: [
          for (final task in state.tasks)
            if (task.id == taskId)
              InstallTask(
                id: task.id,
                name: task.name,
                description: task.description,
                type: task.type,
                installMode: task.installMode,
                filePath: task.filePath,
                bytes: task.bytes,
                resource: task.resource,
                file: task.file,
              )
            else
              task,
        ],
        runStatus: state.runStatus,
      );
      return;
    }
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(
            ZeroBoxCommand(method: 'queue.retry', params: {'id': taskId}),
          ),
    );
  }

  void start() {
    if (kIsWeb) {
      if (state.isRunning || !state.hasRunnableTasks || !_webDeviceReady()) {
        return;
      }
      state = InstallQueueState(
        tasks: state.tasks,
        runStatus: QueueRunStatus.running,
      );
      unawaited(_runWeb());
      return;
    }
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const ZeroBoxCommand(method: 'queue.start')),
    );
  }

  void pause() {
    if (kIsWeb) {
      if (!state.isRunning) return;
      state = InstallQueueState(
        tasks: state.tasks,
        runStatus: QueueRunStatus.stopping,
      );
      return;
    }
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const ZeroBoxCommand(method: 'queue.pause')),
    );
  }

  Future<void> _runWeb() async {
    while (state.runStatus == QueueRunStatus.running) {
      final task = state.tasks
          .where((item) => item.status == ResourceTaskStatus.pending)
          .firstOrNull;
      if (task == null) break;
      await _runWebTask(task);
      if (state.runStatus == QueueRunStatus.stopping) break;
    }
    state = InstallQueueState(
      tasks: state.tasks,
      runStatus: QueueRunStatus.pending,
    );
  }

  Future<void> _runWebTask(InstallTask task) async {
    final manager = ref.read(deviceManagerProvider.notifier);
    void update(ResourceTaskStatus status, double progress, String? error) {
      state = InstallQueueState(
        tasks: [
          for (final item in state.tasks)
            if (item.id == task.id)
              InstallTask(
                id: item.id,
                name: item.name,
                description: item.description,
                type: item.type,
                installMode: item.installMode,
                filePath: item.filePath,
                bytes: item.bytes,
                resource: item.resource,
                file: item.file,
                status: status,
                progress: progress,
                error: error,
              )
            else
              item,
        ],
        runStatus: state.runStatus,
      );
    }

    if (task.resource != null && task.file != null) {
      await ResourceInstallService().installDownloadedResource(
        resource: task.resource!,
        file: task.file!,
        filePath: task.filePath,
        bytes: task.bytes,
        deviceManager: manager,
        onUpdate: update,
      );
    } else {
      final service = ResourceInstallService();
      final bytes = task.bytes;
      if (bytes == null) {
        update(ResourceTaskStatus.failed, 0, 'Missing resource bytes');
        return;
      }
      try {
        switch (task.installMode) {
          case ResourceInstallMode.automatic:
            await service.installLocalPayload(
              type: task.type,
              fileName: task.name,
              bytes: bytes,
              deviceManager: manager,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
          case ResourceInstallMode.forceType:
            await service.installForcedPayload(
              type: task.type,
              fileName: task.name,
              bytes: bytes,
              deviceManager: manager,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
          case ResourceInstallMode.forcePlatform:
            final analysis = service.analyzePayload(
              fileName: task.name,
              bytes: bytes,
              hint: task.type,
              source: 'web-queue-force-platform',
            );
            if (analysis == null) {
              throw FormatException('Unrecognized resource: ${task.name}');
            }
            await service.installAnalyzedPayload(
              analysis: analysis,
              fileName: task.name,
              deviceManager: manager,
              forcePlatform: true,
              onProgress: (progress) =>
                  update(ResourceTaskStatus.installing, progress, null),
            );
        }
        update(ResourceTaskStatus.completed, 1, null);
      } catch (error) {
        update(ResourceTaskStatus.failed, 0, error.toString());
      }
    }
  }
}

final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );
