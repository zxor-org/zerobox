import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/cli/cli_models.dart';
import 'package:zerobox/src/cli/cli_parser.dart';
import 'package:zerobox/src/cli/resource_cli_command.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_client.dart';
import 'package:zerobox/src/daemon/daemon_server.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';

Future<bool> runCliIfRequested(List<String> args) async {
  CliInvocation invocation;
  try {
    invocation = parseCliInvocation(args);
  } on CliUsageException catch (error) {
    stderr.writeln(error.message);
    stderr.writeln(_usage);
    exit(CliExitCode.usage.code);
  }
  if (!invocation.noGui) return false;
  final code = await _run(invocation);
  exit(code.code);
}

Future<CliExitCode> _run(CliInvocation invocation) async {
  final command = invocation.command.join('.');
  if (command == 'help' || command == '--help') {
    stdout.writeln(_usage);
    return CliExitCode.success;
  }
  if (command == 'version') {
    final commit = await BuildInfoService.resolveCommitHash();
    if (invocation.json) {
      stdout.writeln(
        jsonEncode({
          'name': 'ZeroBox',
          'version': BuildInfoService.appVersion,
          'commit': commit,
          'builder': BuildInfoService.buildUser,
          'protocolVersion': zeroBoxProtocolVersion,
        }),
      );
    } else {
      stdout.writeln(
        'ZeroBox ${BuildInfoService.appVersion} ($commit), '
        'built by ${BuildInfoService.buildUser}, '
        'protocol $zeroBoxProtocolVersion',
      );
    }
    return CliExitCode.success;
  }
  if (command == 'daemon.run') {
    final server = ZeroBoxDaemonServer(ProviderContainer());
    try {
      await server.run();
      return CliExitCode.success;
    } catch (error) {
      stderr.writeln('Failed to run daemon: $error');
      return CliExitCode.daemon;
    }
  }
  if (command == 'daemon.start') {
    return _startDaemon(invocation);
  }

  ZeroBoxDaemonClient client;
  try {
    client = await _connectOrStart(invocation);
  } catch (error) {
    stderr.writeln('Unable to connect to ZeroBox daemon: $error');
    return CliExitCode.daemon;
  }

  final lastProgress = <String, int>{};
  final eventSubscription = client.events.listen((event) {
    if (invocation.quiet) return;
    final watchingLogs = invocation.command.join('.') == 'logs.watch';
    final watchingQueue = invocation.command.join('.') == 'queue.watch';
    if (event.event == 'device.state') return;
    if (event.event == 'task.removed') return;
    if (event.event == 'task' && !watchingQueue) return;
    if (event.event == 'log' || event.event == 'debug.log') {
      if (!watchingLogs) return;
      final record = event.data['record'];
      final message = record is Map
          ? record['message']?.toString()
          : event.data['message']?.toString();
      if (message != null) stdout.writeln(message);
      return;
    }
    if (invocation.json) {
      stdout.writeln(event.encode());
    } else {
      if (event.event == 'task') {
        stdout.writeln('${event.data['id']}: ${event.data['status']}');
        return;
      }
      final rawProgress = event.data['progress'];
      if (rawProgress is num) {
        final percent =
            ((rawProgress <= 1 ? rawProgress * 100 : rawProgress).clamp(
              0,
              100,
            )).round();
        final previous = lastProgress[event.event] ?? -5;
        if (percent == previous) return;
        if (percent < 100 && percent - previous < 5) return;
        lastProgress[event.event] = percent;
        final label = event.event == 'progress'
            ? 'Installing'
            : '${event.event[0].toUpperCase()}${event.event.substring(1)}';
        stdout.writeln('$label: $percent%');
        return;
      }
      stdout.writeln(event.event);
    }
  });
  try {
    var request = await _toCommand(invocation);
    if (invocation.options.containsKey('detach') &&
        (request.method == 'install.local' ||
            request.method == 'resource.install')) {
      request = ZeroBoxCommand(
        method: 'task.enqueue',
        params: {'command': request.toJson()},
      );
    }
    var result = await client.execute(request);
    if (request.method == 'task.enqueue' &&
        invocation.options.containsKey('wait') &&
        result.ok) {
      final taskId = (result.value as Map?)?['taskId']?.toString();
      if (taskId != null) {
        if (!invocation.quiet && !invocation.json) {
          stdout.writeln('Task $taskId queued; waiting for completion');
        }
        result = await client.execute(
          ZeroBoxCommand(method: 'queue.wait', params: {'id': taskId}),
        );
      }
    }
    _printResult(invocation, result);
    if ({'queue.watch', 'logs.watch'}.contains(invocation.command.join('.')) &&
        result.ok) {
      final done = Completer<void>();
      late final StreamSubscription<ProcessSignal> signal;
      signal = ProcessSignal.sigint.watch().listen((_) {
        if (!done.isCompleted) done.complete();
      });
      await done.future;
      await signal.cancel();
    }
    return _resultExitCode(result);
  } on CliUsageException catch (error) {
    stderr.writeln(error.message);
    return CliExitCode.usage;
  } finally {
    await eventSubscription.cancel();
    await client.close();
  }
}

Future<CliExitCode> _startDaemon(CliInvocation invocation) async {
  try {
    final existing = await ZeroBoxDaemonClient.connect();
    await existing.close();
    if (!invocation.quiet) stdout.writeln('ZeroBox daemon is already running');
    return CliExitCode.success;
  } catch (_) {}
  await Process.start(Platform.resolvedExecutable, [
    '--nogui',
    'daemon',
    'run',
  ], mode: ProcessStartMode.detached);
  try {
    final client = await _waitForDaemon();
    await client.close();
    if (!invocation.quiet) stdout.writeln('ZeroBox daemon started');
    return CliExitCode.success;
  } catch (error) {
    stderr.writeln('Daemon failed to start: $error');
    return CliExitCode.daemon;
  }
}

Future<ZeroBoxDaemonClient> _connectOrStart(CliInvocation invocation) async {
  try {
    return await ZeroBoxDaemonClient.connect();
  } catch (_) {
    if (invocation.options.containsKey('no-autostart')) rethrow;
    final result = await _startDaemon(
      CliInvocation(
        noGui: true,
        command: const ['daemon', 'start'],
        quiet: true,
      ),
    );
    if (result != CliExitCode.success) {
      throw StateError('daemon autostart failed');
    }
    return ZeroBoxDaemonClient.connect();
  }
}

Future<ZeroBoxDaemonClient> _waitForDaemon() async {
  Object? lastError;
  for (var attempt = 0; attempt < 30; attempt++) {
    try {
      return await ZeroBoxDaemonClient.connect(
        timeout: const Duration(milliseconds: 200),
      );
    } catch (error) {
      lastError = error;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  throw StateError('$lastError');
}

Future<ZeroBoxCommand> _toCommand(CliInvocation invocation) async {
  final name = invocation.command.join('.');
  final device = invocation.options['device'];
  return switch (name) {
    'status' => const ZeroBoxCommand(method: 'status'),
    'daemon.status' => const ZeroBoxCommand(method: 'daemon.info'),
    'daemon.stop' => const ZeroBoxCommand(method: 'daemon.stop'),
    'device.paired' ||
    'device.list' => const ZeroBoxCommand(method: 'device.paired'),
    'device.status' => const ZeroBoxCommand(method: 'device.status'),
    'device.connect' => ZeroBoxCommand(
      method: 'device.connect',
      params: {
        if (invocation.arguments.isNotEmpty)
          'device': invocation.arguments.first,
      },
    ),
    'device.disconnect' => const ZeroBoxCommand(method: 'device.disconnect'),
    'device.scan' => ZeroBoxCommand(
      method: 'device.scan',
      params: {
        if (invocation.options['timeout'] != null)
          'timeout': invocation.options['timeout'],
        if (invocation.options['connect-type'] != null)
          'connectType': invocation.options['connect-type'],
      },
    ),
    'device.info' => const ZeroBoxCommand(method: 'device.info'),
    'app.list' => const ZeroBoxCommand(method: 'app.list'),
    'app.uninstall' => ZeroBoxCommand(
      method: 'app.uninstall',
      params: {'package': invocation.requiredArgument('package name')},
    ),
    'app.launch' => ZeroBoxCommand(
      method: 'app.launch',
      params: {'package': invocation.requiredArgument('package name')},
    ),
    'watchface.list' => const ZeroBoxCommand(method: 'watchface.list'),
    'watchface.remove' => ZeroBoxCommand(
      method: 'watchface.remove',
      params: {'id': invocation.requiredArgument('watchface ID')},
    ),
    'watchface.set' => ZeroBoxCommand(
      method: 'watchface.set',
      params: {'id': invocation.requiredArgument('watchface ID')},
    ),
    'settings.list' => const ZeroBoxCommand(method: 'settings.list'),
    'settings.get' => ZeroBoxCommand(
      method: 'settings.get',
      params: {'key': invocation.requiredArgument('setting key')},
    ),
    'settings.set' => ZeroBoxCommand(
      method: 'settings.set',
      params: {
        'key': invocation.requiredArgument('setting key'),
        'value': _settingValue(invocation),
      },
    ),
    'resource.sources' => const ZeroBoxCommand(method: 'resource.sources'),
    'resource.list' ||
    'resource.search' => buildResourceQueryCommand(invocation),
    'resource.devices' => ZeroBoxCommand(
      method: 'resource.devices',
      params: {
        if (invocation.options['source'] != null)
          'source': invocation.options['source'],
      },
    ),
    'resource.info' ||
    'resource.download' ||
    'resource.install' => ZeroBoxCommand(
      method: name,
      params: {
        'ref': invocation.requiredArgument('resource ref'),
        if (invocation.options['file'] != null)
          'file': invocation.options['file'],
        if (invocation.options['device'] != null)
          'device': invocation.options['device'],
        if (invocation.options['target-device'] != null)
          'targetDevice': invocation.options['target-device'],
      },
    ),
    'account.list' => const ZeroBoxCommand(method: 'account.list'),
    'account.status' => ZeroBoxCommand(
      method: 'account.status',
      params: {'provider': invocation.requiredArgument('account provider')},
    ),
    'account.logout' => ZeroBoxCommand(
      method: 'account.logout',
      params: {'provider': invocation.requiredArgument('account provider')},
    ),
    'account.login' => await _accountLoginCommand(invocation),
    'queue.list' || 'queue.watch' => const ZeroBoxCommand(method: 'queue.list'),
    'queue.get' => ZeroBoxCommand(
      method: 'queue.get',
      params: {'id': invocation.requiredArgument('task ID')},
    ),
    'queue.wait' => ZeroBoxCommand(
      method: 'queue.wait',
      params: {'id': invocation.requiredArgument('task ID')},
    ),
    'queue.cancel' => ZeroBoxCommand(
      method: 'queue.cancel',
      params: {'id': invocation.requiredArgument('task ID')},
    ),
    'queue.remove' => ZeroBoxCommand(
      method: 'queue.remove',
      params: {'id': invocation.requiredArgument('task ID')},
    ),
    'queue.retry' => ZeroBoxCommand(
      method: 'queue.retry',
      params: {'id': invocation.requiredArgument('task ID')},
    ),
    'queue.start' => const ZeroBoxCommand(method: 'queue.start'),
    'queue.pause' => const ZeroBoxCommand(method: 'queue.pause'),
    'queue.clear' => const ZeroBoxCommand(method: 'queue.clear'),
    'logs.show' || 'logs.watch' => const ZeroBoxCommand(method: 'logs.recent'),
    'plugin.list' => const ZeroBoxCommand(
      method: 'plugin.list',
      params: {'includeIcons': false},
    ),
    'plugin.install' => _pluginInstallCommand(invocation),
    'plugin.open' => ZeroBoxCommand(
      method: 'plugin.open',
      params: {'id': invocation.requiredArgument('plugin ID')},
    ),
    'plugin.invoke' => ZeroBoxCommand(
      method: 'plugin.invoke',
      params: {
        'id': invocation.requiredArgument('plugin ID'),
        'callback':
            invocation.arguments.elementAtOrNull(1) ??
            (throw const CliUsageException('Missing callback ID')),
        if (invocation.arguments.length > 2)
          'value': invocation.arguments.skip(2).join(' '),
      },
    ),
    'plugin.remove' => ZeroBoxCommand(
      method: 'plugin.remove',
      params: {'id': invocation.requiredArgument('plugin ID')},
    ),
    'install.quickapp' ||
    'install.miniprogram' ||
    'install.watchface' ||
    'install.firmware' => ZeroBoxCommand(
      method: 'install.local',
      params: {
        'type': invocation.command.last == 'miniprogram'
            ? 'quickapp'
            : invocation.command.last,
        'path': invocation.requiredArgument('resource path'),
        if (device != null) 'device': device,
      },
    ),
    _ => throw CliUsageException('Unknown command: $name'),
  };
}

Future<ZeroBoxCommand> _pluginInstallCommand(CliInvocation invocation) async {
  final path = invocation.requiredArgument('ABP path');
  final file = File(path);
  if (!await file.exists()) throw CliUsageException('File not found: $path');
  return ZeroBoxCommand(
    method: 'plugin.install',
    params: {
      'bytes': base64Encode(await file.readAsBytes()),
      'fileName': file.uri.pathSegments.last,
      'includeIcon': false,
    },
  );
}

Future<ZeroBoxCommand> _accountLoginCommand(CliInvocation invocation) async {
  final provider = invocation.requiredArgument('account provider');
  final needsPassword =
      provider == 'amazfit' || provider == 'huami' || provider == 'xiaomi';
  return ZeroBoxCommand(
    method: 'account.login',
    params: {
      'provider': provider,
      if (invocation.options['username'] != null)
        'username': invocation.options['username'],
      if (needsPassword) 'password': await _readPassword(invocation),
    },
  );
}

Future<String> _readPassword(CliInvocation invocation) async {
  if (invocation.options.containsKey('password-stdin') || !stdin.hasTerminal) {
    return stdin.readLineSync() ?? '';
  }
  stdout.write('Password: ');
  stdin.echoMode = false;
  try {
    return stdin.readLineSync() ?? '';
  } finally {
    stdin.echoMode = true;
    stdout.writeln();
  }
}

Object _settingValue(CliInvocation invocation) {
  if (invocation.arguments.length < 2) {
    throw const CliUsageException('Missing setting value');
  }
  final value = invocation.arguments[1];
  if (value == 'true') return true;
  if (value == 'false') return false;
  return int.tryParse(value) ?? value;
}

void _printResult(CliInvocation invocation, CommandResult result) {
  if (invocation.json) {
    stdout.writeln(jsonEncode(result.toJson()));
  } else if (!result.ok) {
    stderr.writeln('${result.error!.code}: ${result.error!.message}');
  } else if (!invocation.quiet && result.value != null) {
    const encoder = JsonEncoder.withIndent('  ');
    stdout.writeln(encoder.convert(result.value));
  }
}

CliExitCode _exitCode(String? error) => switch (error) {
  null => CliExitCode.success,
  'usage' || 'unknown_command' => CliExitCode.usage,
  'file' => CliExitCode.file,
  'no_device' => CliExitCode.noDevice,
  'connection' => CliExitCode.connection,
  'validation' => CliExitCode.validation,
  'install' => CliExitCode.install,
  'daemon_disconnected' || 'unauthorized' => CliExitCode.daemon,
  'not_found' => CliExitCode.file,
  'download' || 'operation_failed' => CliExitCode.install,
  'cancelled' => CliExitCode.install,
  'timeout' => CliExitCode.daemon,
  _ => CliExitCode.internal,
};

CliExitCode _resultExitCode(CommandResult result) {
  if (!result.ok) return _exitCode(result.error?.code);
  final value = result.value;
  if (value is Map && value['result'] is Map) {
    final nested = (value['result'] as Map).cast<String, Object?>();
    final nestedResult = CommandResult.fromJson(nested);
    if (!nestedResult.ok) return _exitCode(nestedResult.error?.code);
  }
  return CliExitCode.success;
}

const _usage = '''
Usage: zerobox --nogui <command> [arguments] [options]

Commands:
  daemon run|start|stop|status
  status
  device paired|scan|connect|disconnect|status|info
  install quickapp|miniprogram|watchface|firmware <path> [--device <address>]
  app list|uninstall|launch
  watchface list|remove|set
  settings list|get|set
  resource sources|devices|list|search|info|download|install
  account list|status|login|logout
  queue list|get|wait|watch|cancel|remove|retry|start|pause|clear
  logs show|watch
  plugin list|install|open|invoke|remove

Options:
  --json          Emit machine-readable JSON/JSONL
  --quiet         Suppress informational output
  --no-autostart  Do not automatically start the daemon
  --filter        Comma-separated resource filter chips
  --sort          Resource sort: random, name, or time
  --detach        Queue an install and return its task ID
  --wait          Wait for a detached task and return its final exit code
''';
