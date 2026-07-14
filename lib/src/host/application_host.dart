import 'dart:async';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_task_queue.dart';

/// Owns ZeroBox application state and long-running tasks independently from
/// how callers reach it. Desktop exposes this module through IPC while mobile
/// keeps it in the GUI process.
class ApplicationHost implements ZeroBoxCommandBus {
  ApplicationHost(this.core, {this.onClose, this.beginTaskExecution}) {
    tasks = DaemonTaskQueue(
      core,
      onCancelRunning: core is ActiveOperationController
          ? (core as ActiveOperationController).cancelActiveOperation
          : null,
      beginExecution: beginTaskExecution,
      onCompleted: _onTaskCompleted,
      shouldRemoveCompleted: _shouldRemoveCompleted,
    );
    _coreSubscription = core.events.listen(_events.add);
    _taskSubscription = tasks.events.listen(_events.add);
  }

  final ZeroBoxCommandBus core;
  final FutureOr<void> Function()? onClose;
  final Future<Future<void> Function()> Function(DaemonTask)?
  beginTaskExecution;
  late final DaemonTaskQueue tasks;
  final _events = StreamController<CommandEvent>.broadcast();
  late final StreamSubscription<CommandEvent> _coreSubscription;
  late final StreamSubscription<CommandEvent> _taskSubscription;

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    return switch (command.method) {
      'task.enqueue' => CommandResult.success({
        'taskId': tasks.enqueue(
          ZeroBoxCommand.fromJson(
            (command.params['command'] as Map).cast<String, Object?>(),
          ),
          held: command.params['held'] == true,
        ),
      }),
      'queue.list' => CommandResult.success(tasks.list()),
      'queue.get' => _taskResult(command.params['id']?.toString()),
      'queue.wait' => _waitResult(command.params['id']?.toString()),
      'queue.cancel' => CommandResult.success({
        'cancelled': tasks.cancel(command.params['id']?.toString() ?? ''),
      }),
      'queue.clear' => _clearTasks(),
      'queue.start' => CommandResult.success({'started': tasks.startHeld()}),
      'queue.pause' => CommandResult.success({'held': tasks.holdPending()}),
      'queue.retry' => CommandResult.success({
        'retried': tasks.retry(command.params['id']?.toString() ?? ''),
      }),
      'queue.remove' => CommandResult.success({
        'removed': tasks.remove(command.params['id']?.toString() ?? ''),
      }),
      _ => core.execute(command),
    };
  }

  Future<void> cancelActiveOperation() async {
    final controller = core;
    if (controller is ActiveOperationController) {
      await (controller as ActiveOperationController).cancelActiveOperation();
    }
  }

  Future<void> _onTaskCompleted(DaemonTask task, CommandResult result) async {
    if (task.command.method != 'resource.download' ||
        task.command.params['queueInstall'] != true) {
      return;
    }
    final download = (result.value as Map).cast<String, Object?>();
    final autoInstall = await core.execute(
      const ZeroBoxCommand(
        method: 'settings.get',
        params: {'key': 'auto_install'},
      ),
    );
    if (!autoInstall.ok) throw StateError(autoInstall.error!.message);
    final setting = (autoInstall.value as Map)['value'] != false;
    tasks.enqueue(
      ZeroBoxCommand(
        method: 'install.local',
        params: {
          'type': download['type'],
          'path': download['path'],
          'title': task.command.params['title'] ?? download['fileName'],
          'description': task.command.params['targetDevice'] ?? '',
          'deleteAfter': true,
          'autoClean': true,
          if (task.command.params['resource'] != null)
            'resource': task.command.params['resource'],
          if (task.command.params['file'] != null)
            'file': task.command.params['file'],
        },
      ),
      held: !setting,
    );
  }

  Future<bool> _shouldRemoveCompleted(
    DaemonTask task,
    CommandResult result,
  ) async {
    if (task.command.params['autoClean'] != true) return false;
    final setting = await core.execute(
      const ZeroBoxCommand(
        method: 'settings.get',
        params: {'key': 'disable_auto_clean'},
      ),
    );
    return setting.ok && (setting.value as Map)['value'] != true;
  }

  CommandResult _taskResult(String? id) {
    final task = tasks.get(id ?? '');
    return task == null
        ? const CommandResult.failure(
            CommandError('not_found', 'Task not found'),
          )
        : CommandResult.success(task.toJson());
  }

  Future<CommandResult> _waitResult(String? id) async {
    final task = await tasks.wait(id ?? '');
    return task == null
        ? const CommandResult.failure(
            CommandError('not_found', 'Task not found'),
          )
        : CommandResult.success(task.toJson());
  }

  CommandResult _clearTasks() {
    tasks.clear();
    return const CommandResult.success({'cleared': true});
  }

  Map<String, Object?> get taskSummary {
    final snapshot = tasks.list();
    return {
      'total': snapshot.length,
      'running': snapshot.where((task) => task['status'] == 'running').length,
      'pending': snapshot.where((task) => task['status'] == 'pending').length,
    };
  }

  @override
  Future<void> close() async {
    await _coreSubscription.cancel();
    await _taskSubscription.cancel();
    await tasks.close();
    await core.close();
    await onClose?.call();
    await _events.close();
  }
}

abstract interface class ActiveOperationController {
  Future<void> cancelActiveOperation();
}
