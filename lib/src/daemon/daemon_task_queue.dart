import 'dart:async';
import 'dart:convert';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

class DaemonTaskQueue {
  DaemonTaskQueue(
    this.bus, {
    this.onCancelRunning,
    this.beginExecution,
    this.onCompleted,
    this.shouldRemoveCompleted,
  }) {
    _restore();
  }

  static const _storageKey = 'daemon.tasks';
  final ZeroBoxCommandBus bus;
  final Future<void> Function()? onCancelRunning;
  final Future<Future<void> Function()> Function(DaemonTask)? beginExecution;
  final Future<void> Function(DaemonTask, CommandResult)? onCompleted;
  final Future<bool> Function(DaemonTask, CommandResult)? shouldRemoveCompleted;
  final _tasks = <String, DaemonTask>{};
  final _waiters = <String, List<Completer<DaemonTask>>>{};
  final _events = StreamController<CommandEvent>.broadcast();
  String? _runningId;
  bool _pumpScheduled = false;
  Future<void> _persistTail = Future<void>.value();
  Stream<CommandEvent> get events => _events.stream;

  List<Map<String, Object?>> list() =>
      _tasks.values.map((task) => task.toJson()).toList(growable: false)
        ..sort((a, b) => '${b['createdAt']}'.compareTo('${a['createdAt']}'));

  String enqueue(ZeroBoxCommand command, {bool held = false}) {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}';
    _tasks[id] = DaemonTask(
      id: id,
      command: command,
      status: held ? 'held' : 'pending',
      createdAt: now,
    );
    _notify(_tasks[id]!);
    _schedulePump();
    return id;
  }

  void _schedulePump() {
    if (_pumpScheduled || _runningId != null) return;
    _pumpScheduled = true;
    scheduleMicrotask(() async {
      _pumpScheduled = false;
      await _pump();
    });
  }

  Future<void> _pump() async {
    if (_runningId != null) return;
    final next = _tasks.values
        .where((task) => task.status == 'pending')
        .firstOrNull;
    if (next == null) return;
    _runningId = next.id;
    await _run(next.id);
    _runningId = null;
    _schedulePump();
  }

  Future<void> _run(String id) async {
    var task = _tasks[id];
    if (task == null || task.status != 'pending') return;
    task = task.copyWith(status: 'running', startedAt: DateTime.now());
    _tasks[id] = task;
    _notify(task);
    var lastProgressBucket = -1;
    final progressSubscription = bus.events.listen((event) {
      final raw = event.data['progress'];
      if (raw is! num) return;
      final progress = (raw <= 1 ? raw.toDouble() : raw.toDouble() / 100)
          .clamp(0, 1)
          .toDouble();
      final bucket = (progress * 20).floor();
      if (bucket == lastProgressBucket) return;
      lastProgressBucket = bucket;
      final current = _tasks[id];
      if (current == null || current.status != 'running') return;
      final updated = current.copyWith(progress: progress);
      _tasks[id] = updated;
      _notify(updated);
    });
    Future<void> Function()? endExecution;
    late CommandResult result;
    try {
      endExecution = await beginExecution?.call(task);
      result = await bus.execute(task.command);
    } catch (error, stackTrace) {
      result = CommandResult.failure(
        CommandError(
          'task_execution',
          error.toString(),
          details: '$stackTrace',
        ),
      );
    } finally {
      await progressSubscription.cancel();
      await endExecution?.call();
    }
    if (result.ok && onCompleted != null) {
      try {
        await onCompleted!(task, result);
      } catch (error, stackTrace) {
        result = CommandResult.failure(
          CommandError(
            'task_completion',
            error.toString(),
            details: '$stackTrace',
          ),
        );
      }
    }
    task = _tasks[id];
    if (task == null) return;
    final status = task.cancelRequested
        ? 'cancelled'
        : result.ok
        ? 'completed'
        : 'failed';
    task = task.copyWith(
      status: status,
      finishedAt: DateTime.now(),
      result: result.toJson(),
      progress: result.ok ? 1 : task.progress,
    );
    _tasks[id] = task;
    _notify(task);
    _completeWaiters(task);
    if (status == 'completed' &&
        await shouldRemoveCompleted?.call(task, result) == true) {
      remove(id);
    }
  }

  bool cancel(String id) {
    final task = _tasks[id];
    if (task == null ||
        {'completed', 'failed', 'cancelled'}.contains(task.status)) {
      return false;
    }
    final updated = task.status == 'pending' || task.status == 'held'
        ? task.copyWith(status: 'cancelled', finishedAt: DateTime.now())
        : task.copyWith(cancelRequested: true);
    _tasks[id] = updated;
    _notify(updated);
    if (task.status == 'running') {
      unawaited(onCancelRunning?.call());
    }
    if (updated.status == 'cancelled') _completeWaiters(updated);
    return true;
  }

  int startHeld() {
    var count = 0;
    for (final entry in _tasks.entries.toList()) {
      if (entry.value.status != 'held' && entry.value.status != 'failed') {
        continue;
      }
      _tasks[entry.key] = entry.value.copyWith(
        status: 'pending',
        progress: 0,
        clearResult: true,
      );
      _notify(_tasks[entry.key]!);
      count += 1;
    }
    _schedulePump();
    return count;
  }

  int holdPending() {
    var count = 0;
    for (final entry in _tasks.entries.toList()) {
      if (entry.value.status != 'pending') continue;
      _tasks[entry.key] = entry.value.copyWith(status: 'held');
      _notify(_tasks[entry.key]!);
      count += 1;
    }
    return count;
  }

  bool retry(String id) {
    final task = _tasks[id];
    if (task == null || !{'failed', 'cancelled'}.contains(task.status)) {
      return false;
    }
    final updated = task.copyWith(
      status: 'pending',
      progress: 0,
      clearResult: true,
    );
    _tasks[id] = updated;
    _notify(updated);
    _schedulePump();
    return true;
  }

  DaemonTask? get(String id) => _tasks[id];

  Future<DaemonTask?> wait(String id) async {
    final task = _tasks[id];
    if (task == null) return null;
    if (_isTerminal(task.status)) return task;
    final completer = Completer<DaemonTask>();
    _waiters.putIfAbsent(id, () => []).add(completer);
    return completer.future;
  }

  void clear() {
    final removed = _tasks.values
        .where((task) => _isTerminal(task.status))
        .map((task) => task.id)
        .toList();
    _tasks.removeWhere(
      (_, task) => {'completed', 'failed', 'cancelled'}.contains(task.status),
    );
    _persist();
    for (final id in removed) {
      _events.add(CommandEvent('task.removed', data: {'id': id}));
    }
  }

  bool remove(String id) {
    final task = _tasks[id];
    if (task == null || !_isTerminal(task.status)) return false;
    _tasks.remove(id);
    _persist();
    _events.add(CommandEvent('task.removed', data: {'id': id}));
    return true;
  }

  void _notify(DaemonTask task) {
    _persist();
    _events.add(CommandEvent('task', data: task.toJson()));
  }

  bool _isTerminal(String status) =>
      {'completed', 'failed', 'cancelled'}.contains(status);

  void _completeWaiters(DaemonTask task) {
    for (final waiter in _waiters.remove(task.id) ?? const []) {
      if (!waiter.isCompleted) waiter.complete(task);
    }
  }

  void _restore() {
    final rows =
        SharedPrefsService.instance.getStringList(_storageKey) ?? const [];
    var droppedInstallTasks = false;
    for (final row in rows) {
      try {
        final task = DaemonTask.fromJson(
          (jsonDecode(row) as Map).cast<String, Object?>(),
        );
        // Install tasks never survive a restart: a half-finished install
        // against a possibly disconnected device is worse than a clean queue.
        if (task.command.method.startsWith('install.')) {
          droppedInstallTasks = true;
          continue;
        }
        _tasks[task.id] = task.status == 'running'
            ? task.copyWith(
                status: 'pending',
                progress: 0,
                cancelRequested: false,
                clearStartedAt: true,
                clearFinishedAt: true,
                clearResult: true,
              )
            : task;
      } catch (_) {}
    }
    if (droppedInstallTasks) _persist();
    _schedulePump();
  }

  Future<void> _persist() => _persistTail = _persistTail.then(
    (_) => SharedPrefsService.instance.setStringList(
      _storageKey,
      _tasks.values.map((task) => jsonEncode(task.toJson())).toList(),
    ),
  );

  Future<void> close() async {
    for (final waiters in _waiters.values) {
      for (final waiter in waiters) {
        if (!waiter.isCompleted) {
          waiter.completeError(StateError('Daemon task queue closed'));
        }
      }
    }
    _waiters.clear();
    await _persistTail;
    await _events.close();
  }
}

class DaemonTask {
  const DaemonTask({
    required this.id,
    required this.command,
    required this.status,
    required this.createdAt,
    this.startedAt,
    this.finishedAt,
    this.cancelRequested = false,
    this.progress = 0,
    this.result,
  });

  final String id;
  final ZeroBoxCommand command;
  final String status;
  final DateTime createdAt;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final bool cancelRequested;
  final double progress;
  final Map<String, Object?>? result;

  DaemonTask copyWith({
    String? status,
    DateTime? startedAt,
    DateTime? finishedAt,
    bool? cancelRequested,
    Map<String, Object?>? result,
    double? progress,
    bool clearStartedAt = false,
    bool clearFinishedAt = false,
    bool clearResult = false,
  }) => DaemonTask(
    id: id,
    command: command,
    status: status ?? this.status,
    createdAt: createdAt,
    startedAt: clearStartedAt ? null : startedAt ?? this.startedAt,
    finishedAt: clearFinishedAt ? null : finishedAt ?? this.finishedAt,
    cancelRequested: cancelRequested ?? this.cancelRequested,
    progress: progress ?? this.progress,
    result: clearResult ? null : result ?? this.result,
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'command': command.toJson(),
    'status': status,
    'createdAt': createdAt.toIso8601String(),
    if (startedAt != null) 'startedAt': startedAt!.toIso8601String(),
    if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    if (cancelRequested) 'cancelRequested': true,
    'progress': progress,
    if (result != null) 'result': result,
  };

  factory DaemonTask.fromJson(Map<String, Object?> json) => DaemonTask(
    id: json['id']!.toString(),
    command: ZeroBoxCommand.fromJson(
      (json['command'] as Map).cast<String, Object?>(),
    ),
    status: json['status']!.toString(),
    createdAt: DateTime.parse(json['createdAt']!.toString()),
    startedAt: json['startedAt'] == null
        ? null
        : DateTime.parse(json['startedAt']!.toString()),
    finishedAt: json['finishedAt'] == null
        ? null
        : DateTime.parse(json['finishedAt']!.toString()),
    cancelRequested: json['cancelRequested'] == true,
    progress: (json['progress'] as num?)?.toDouble() ?? 0,
    result: (json['result'] as Map?)?.cast<String, Object?>(),
  );
}
