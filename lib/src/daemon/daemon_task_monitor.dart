import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_task_models.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

final daemonTasksProvider = StreamProvider<List<DaemonTaskView>>(
  (ref) => watchHostTasks(ref.watch(applicationHostProvider)),
);

Stream<List<DaemonTaskView>> watchHostTasks(ZeroBoxCommandBus host) async* {
  final tasks = <String, DaemonTaskView>{};
  Future<void> load() async {
    final initial = await host.execute(
      const ZeroBoxCommand(method: 'queue.list'),
    );
    if (!initial.ok || initial.value is! List) return;
    tasks.clear();
    for (final row in (initial.value as List).whereType<Map>()) {
      final task = DaemonTaskView.fromJson(row.cast<String, Object?>());
      tasks[task.id] = task;
    }
  }

  await load();
  yield _sorted(tasks);
  final updates = StreamController<List<DaemonTaskView>>();
  final subscription = host.events.listen((event) {
    if (event.event == 'host.connected') {
      unawaited(
        load().then((_) {
          if (!updates.isClosed) updates.add(_sorted(tasks));
        }),
      );
      return;
    }
    if (event.event == 'task.removed') {
      tasks.remove(event.data['id']?.toString());
      updates.add(_sorted(tasks));
      return;
    }
    if (event.event != 'task') return;
    final task = DaemonTaskView.fromJson(event.data);
    tasks[task.id] = task;
    updates.add(_sorted(tasks));
  });
  try {
    yield* updates.stream;
  } finally {
    await subscription.cancel();
    await updates.close();
  }
}

List<DaemonTaskView> _sorted(Map<String, DaemonTaskView> tasks) =>
    tasks.values.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));

Future<void> cancelHostTask(ZeroBoxCommandBus host, String id) =>
    _taskCommand(host, 'queue.cancel', id);
Future<void> removeHostTask(ZeroBoxCommandBus host, String id) =>
    _taskCommand(host, 'queue.remove', id);
Future<void> clearHostTasks(ZeroBoxCommandBus host) async {
  final result = await host.execute(
    const ZeroBoxCommand(method: 'queue.clear'),
  );
  if (!result.ok) throw StateError(result.error!.message);
}

Future<void> _taskCommand(
  ZeroBoxCommandBus host,
  String method,
  String id,
) async {
  final result = await host.execute(
    ZeroBoxCommand(method: method, params: {'id': id}),
  );
  if (!result.ok) throw StateError(result.error!.message);
}
