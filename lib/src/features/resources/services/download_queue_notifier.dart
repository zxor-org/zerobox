import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/domain/community_resource_codec.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

export 'package:zerobox/src/features/resources/services/resource_install_service.dart'
    show ResourceTaskStatus;

class ResourceTask {
  const ResourceTask({
    required this.id,
    required this.resource,
    required this.file,
    required this.codename,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String id;
  final CommunityResourceDetail resource;
  final CommunityResourceFile file;
  final String codename;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;

  String get title => resource.name;
  String get subtitle => '${resource.authorName} · $codename';
}

class DownloadQueueNotifier extends Notifier<List<ResourceTask>> {
  StreamSubscription<CommandEvent>? _subscription;

  @override
  List<ResourceTask> build() {
    final host = ref.watch(applicationHostProvider);
    _subscription = host.events.listen(_handleEvent);
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    scheduleMicrotask(_refresh);
    return const [];
  }

  ResourceTask? get runningTask => state
      .where(
        (task) =>
            task.status == ResourceTaskStatus.downloading ||
            task.status == ResourceTaskStatus.installing,
      )
      .firstOrNull;

  void enqueue({
    required CommunityResourceDetail resource,
    required CommunityResourceFile file,
    required String codename,
  }) {
    if (state.any(
      (task) =>
          task.resource.ref == resource.ref &&
          task.file.id == file.id &&
          task.codename == codename &&
          task.status != ResourceTaskStatus.completed,
    )) {
      return;
    }
    unawaited(_enqueue(resource, file, codename));
  }

  Future<void> _enqueue(
    CommunityResourceDetail resource,
    CommunityResourceFile file,
    String codename,
  ) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          ZeroBoxCommand(
            method: 'task.enqueue',
            params: {
              'command': ZeroBoxCommand(
                method: 'resource.download',
                params: {
                  'ref': resource.ref.key,
                  'file': file.id,
                  'targetDevice': codename,
                  'title': resource.name,
                  'resource': communityResourceDetailToJson(resource),
                  'queueInstall': true,
                  'autoClean': true,
                },
              ).toJson(),
            },
          ),
        );
    if (!result.ok) throw StateError(result.error!.message);
    await _refresh();
  }

  void remove(String id) => unawaited(_remove(id));

  Future<void> _remove(String id) async {
    final task = state.where((task) => task.id == id).firstOrNull;
    if (task == null) return;
    final host = ref.read(applicationHostProvider);
    if (task.status == ResourceTaskStatus.completed ||
        task.status == ResourceTaskStatus.failed) {
      await host.execute(
        ZeroBoxCommand(method: 'queue.remove', params: {'id': id}),
      );
    } else {
      await host.execute(
        ZeroBoxCommand(method: 'queue.cancel', params: {'id': id}),
      );
      await host.execute(
        ZeroBoxCommand(method: 'queue.remove', params: {'id': id}),
      );
    }
  }

  void clearTerminal() {
    for (final task in state.where(
      (task) =>
          task.status == ResourceTaskStatus.completed ||
          task.status == ResourceTaskStatus.failed,
    )) {
      unawaited(_remove(task.id));
    }
  }

  void retry(String id) {
    unawaited(
      ref
          .read(applicationHostProvider)
          .execute(ZeroBoxCommand(method: 'queue.retry', params: {'id': id})),
    );
  }

  Future<void> _refresh() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const ZeroBoxCommand(method: 'queue.list'));
    if (!result.ok || result.value is! List) return;
    state = (result.value as List)
        .whereType<Map>()
        .map((row) => DaemonTaskView.fromJson(row.cast<String, Object?>()))
        .where((view) => view.method == 'resource.download')
        .map(_fromView)
        .whereType<ResourceTask>()
        .toList();
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'host.connected') {
      unawaited(_refresh());
      return;
    }
    if (event.event == 'task.removed') {
      final id = event.data['id']?.toString();
      state = state.where((task) => task.id != id).toList();
      return;
    }
    if (event.event != 'task') return;
    final view = DaemonTaskView.fromJson(event.data);
    if (view.method != 'resource.download') return;
    final task = _fromView(view);
    if (task == null) return;
    final tasks = [...state];
    final index = tasks.indexWhere((item) => item.id == task.id);
    if (index < 0) {
      tasks.add(task);
    } else {
      tasks[index] = task;
    }
    state = tasks;
  }

  ResourceTask? _fromView(DaemonTaskView view) {
    final resourceJson = view.params['resource'];
    if (resourceJson is! Map) return null;
    final resource = communityResourceDetailFromJson(
      resourceJson.cast<String, Object?>(),
    );
    final fileId = view.params['file']?.toString();
    final file = resource.files.where((file) => file.id == fileId).firstOrNull;
    if (file == null) return null;
    return ResourceTask(
      id: view.id,
      resource: resource,
      file: file,
      codename: view.params['targetDevice']?.toString() ?? '',
      status: switch (view.status) {
        'running' => ResourceTaskStatus.downloading,
        'completed' => ResourceTaskStatus.completed,
        'failed' || 'cancelled' => ResourceTaskStatus.failed,
        _ => ResourceTaskStatus.pending,
      },
      progress: view.progress,
      error: view.error,
    );
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<ResourceTask>>(
      DownloadQueueNotifier.new,
    );
