import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/resources/domain/community_resource.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';

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

  ResourceTask copyWith({
    ResourceTaskStatus? status,
    double? progress,
    String? error,
  }) => ResourceTask(
    id: id,
    resource: resource,
    file: file,
    codename: codename,
    status: status ?? this.status,
    progress: progress ?? this.progress,
    error: error ?? this.error,
  );
}

class DownloadQueueNotifier extends Notifier<List<ResourceTask>> {
  CancelToken? _cancelToken;

  @override
  List<ResourceTask> build() => const [];

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
    final id = '${resource.ref.key}:${file.id}:$codename';
    if (state.any(
      (task) => task.id == id && task.status != ResourceTaskStatus.completed,
    )) {
      return;
    }
    state = [
      ...state,
      ResourceTask(id: id, resource: resource, file: file, codename: codename),
    ];
    _startNext();
  }

  void remove(String id) {
    final task = state.where((task) => task.id == id).firstOrNull;
    if (task == null) return;
    if (task == runningTask) _cancelToken?.cancel('Removed from queue');
    state = state.where((entry) => entry.id != id).toList();
    _startNext();
  }

  void clearTerminal() => state = state
      .where(
        (task) =>
            task.status != ResourceTaskStatus.completed &&
            task.status != ResourceTaskStatus.failed,
      )
      .toList();

  void retry(String id) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(
            status: ResourceTaskStatus.pending,
            progress: 0,
            error: null,
          )
        else
          task,
    ];
    _startNext();
  }

  void _startNext() {
    if (runningTask != null) return;
    final next = state
        .where((task) => task.status == ResourceTaskStatus.pending)
        .firstOrNull;
    if (next != null) _run(next);
  }

  Future<void> _run(ResourceTask task) async {
    _cancelToken = CancelToken();
    _update(task.id, ResourceTaskStatus.downloading, 0, null);
    try {
      final catalog = ref.read(
        communityCatalogProviderForSource(task.resource.ref.source),
      );
      final downloaded = await ResourceInstallService().downloadResource(
        resource: task.resource,
        file: task.file,
        catalog: catalog,
        targetDevice: task.codename,
        onUpdate: (status, progress, error) =>
            _update(task.id, status, progress, error),
      );
      if (downloaded != null) {
        // A removed task may finish after its source request has completed.
        // Do not let that stale result create an install task.
        if (!state.any((entry) => entry.id == task.id)) return;
        ref
            .read(installQueueProvider.notifier)
            .enqueueResource(
              resource: task.resource,
              file: task.file,
              codename: task.codename,
              filePath: downloaded.path,
              bytes: downloaded.bytes,
            );
        state = state.where((entry) => entry.id != task.id).toList();
      }
    } finally {
      _cancelToken = null;
      _startNext();
    }
  }

  void _update(
    String id,
    ResourceTaskStatus status,
    double progress,
    String? error,
  ) {
    state = [
      for (final task in state)
        if (task.id == id)
          task.copyWith(status: status, progress: progress, error: error)
        else
          task,
    ];
  }
}

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<ResourceTask>>(
      DownloadQueueNotifier.new,
    );
