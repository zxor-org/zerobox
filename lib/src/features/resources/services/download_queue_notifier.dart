import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/network/dio_provider.dart';
import 'package:zerobox/src/data/astrobox/astrobox_providers.dart';
import 'package:zerobox/src/data/astrobox/models/astrobox_models.dart';
import 'package:zerobox/src/features/resources/services/install_queue_notifier.dart';
import 'package:zerobox/src/features/resources/services/resource_install_service.dart';

export 'package:zerobox/src/features/resources/services/resource_install_service.dart'
    show ResourceTaskStatus;

class ResourceTask {
  const ResourceTask({
    required this.id,
    required this.item,
    required this.manifest,
    required this.download,
    required this.codename,
    this.status = ResourceTaskStatus.pending,
    this.progress = 0,
    this.error,
  });

  final String id;
  final AstroBoxIndexItem item;
  final AstroBoxManifest manifest;
  final AstroBoxManifestDownload download;
  final String codename;
  final ResourceTaskStatus status;
  final double progress;
  final String? error;

  String get title => item.name;
  String get subtitle =>
      '${manifest.item.author.firstOrNull?.name ?? item.repoOwner} · $codename';

  ResourceTask copyWith({
    ResourceTaskStatus? status,
    double? progress,
    String? error,
  }) {
    return ResourceTask(
      id: id,
      item: item,
      manifest: manifest,
      download: download,
      codename: codename,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class DownloadQueueNotifier extends Notifier<List<ResourceTask>> {
  @override
  List<ResourceTask> build() => [];

  CancelToken? _cancelToken;

  ResourceTask? get runningTask => state.cast<ResourceTask?>().firstWhere(
    (t) =>
        t?.status == ResourceTaskStatus.downloading ||
        t?.status == ResourceTaskStatus.installing,
    orElse: () => null,
  );

  List<ResourceTask> get pendingTasks =>
      state.where((t) => t.status == ResourceTaskStatus.pending).toList();

  List<ResourceTask> get activeOrPendingTasks =>
      state.where((t) => t.status != ResourceTaskStatus.completed).toList();

  bool get isBusy => runningTask != null;

  void enqueue({
    required AstroBoxIndexItem item,
    required AstroBoxManifest manifest,
    required AstroBoxManifestDownload download,
    required String codename,
  }) {
    final taskId = '${item.id}_$codename';
    if (state.any(
      (t) => t.id == taskId && t.status != ResourceTaskStatus.completed,
    )) {
      return;
    }

    final task = ResourceTask(
      id: taskId,
      item: item,
      manifest: manifest,
      download: download,
      codename: codename,
    );
    state = [...state, task];
    _tryStartNext();
  }

  void remove(String taskId) {
    final task = state.firstWhere(
      (t) => t.id == taskId,
      orElse: () => _dummyTask,
    );
    if (task == _dummyTask) return;

    if (task.status == ResourceTaskStatus.downloading ||
        task.status == ResourceTaskStatus.installing) {
      _cancelCurrent();
    }

    state = state.where((t) => t.id != taskId).toList();
    _tryStartNext();
  }

  void clearCompleted() {
    state = state
        .where((t) => t.status != ResourceTaskStatus.completed)
        .toList();
  }

  void retry(String taskId) {
    state = [
      for (final task in state)
        if (task.id == taskId)
          task.copyWith(
            status: ResourceTaskStatus.pending,
            progress: 0,
            error: null,
          )
        else
          task,
    ];
    _tryStartNext();
  }

  void _tryStartNext() {
    if (isBusy) return;

    final next = state.firstWhere(
      (t) => t.status == ResourceTaskStatus.pending,
      orElse: () => _dummyTask,
    );
    if (next == _dummyTask) return;

    _runTask(next);
  }

  Future<void> _runTask(ResourceTask task) async {
    _cancelToken = CancelToken();

    state = [
      for (final t in state)
        if (t.id == task.id)
          t.copyWith(status: ResourceTaskStatus.downloading, progress: 0)
        else
          t,
    ];

    final service = ResourceInstallService(
      dio: ref.read(appDioProvider),
      cancelToken: _cancelToken,
    );
    final repo = ref.read(astroBoxRepositoryProvider);

    final downloaded = await service.downloadResource(
      item: task.item,
      download: task.download,
      repo: repo,
      onUpdate: (status, progress, error) {
        _updateTask(task.id, status, progress, error);
      },
    );
    if (downloaded != null) {
      ref
          .read(installQueueProvider.notifier)
          .enqueueResource(
            item: task.item,
            manifest: task.manifest,
            download: task.download,
            codename: task.codename,
            filePath: downloaded.path,
          );
      state = state.where((t) => t.id != task.id).toList();
    }

    _cancelToken = null;
    _tryStartNext();
  }

  void _updateTask(
    String taskId,
    ResourceTaskStatus status,
    double progress,
    String? error,
  ) {
    state = [
      for (final t in state)
        if (t.id == taskId)
          t.copyWith(status: status, progress: progress, error: error)
        else
          t,
    ];
  }

  void _cancelCurrent() {
    _cancelToken?.cancel('removed from queue');
    _cancelToken = null;
  }
}

const _dummyTask = ResourceTask(
  id: '',
  item: AstroBoxIndexItem(
    id: '',
    name: '',
    type: AstroBoxResourceType.quickApp,
    repoOwner: '',
    repoName: '',
    repoCommitHash: '',
    icon: '',
    cover: '',
    paidType: AstroBoxPaidType.free,
  ),
  manifest: AstroBoxManifest(
    item: AstroBoxManifestItem(
      id: '',
      restype: AstroBoxResourceType.quickApp,
      name: '',
      description: '',
      icon: '',
      cover: '',
      author: [],
    ),
  ),
  download: AstroBoxManifestDownload(version: '', fileName: ''),
  codename: '',
);

final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, List<ResourceTask>>(
      DownloadQueueNotifier.new,
    );
