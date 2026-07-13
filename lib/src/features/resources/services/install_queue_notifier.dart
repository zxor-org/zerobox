import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:cross_file/cross_file.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/community_resource_codec.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

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
  final String filePath;
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

  void remove(String taskId) => unawaited(_remove(taskId));
  Future<void> _remove(String taskId) async {
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
    for (final task in state.tasks.where(
      (task) =>
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    )) {
      unawaited(_remove(task.id));
    }
  }

  void retry(String taskId) {
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(
            ZeroBoxCommand(method: 'queue.retry', params: {'id': taskId}),
          ),
    );
  }

  void start() {
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const ZeroBoxCommand(method: 'queue.start')),
    );
  }

  void pause() {
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(const ZeroBoxCommand(method: 'queue.pause')),
    );
  }
}

final installQueueProvider =
    NotifierProvider<InstallQueueNotifier, InstallQueueState>(
      InstallQueueNotifier.new,
    );
