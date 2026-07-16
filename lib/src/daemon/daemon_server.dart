import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/command_bus/local_command_bus.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';
import 'package:zerobox/src/host/application_host.dart';

class ZeroBoxDaemonServer {
  ZeroBoxDaemonServer(this.container)
    : host = ApplicationHost(LocalCommandBus(container));

  final ProviderContainer container;
  final ApplicationHost host;
  ServerSocket? _server;
  final _clients = <Socket>{};
  StreamSubscription<CommandEvent>? _eventSubscription;
  String? _windowsToken;
  RandomAccessFile? _windowsLock;
  final DateTime startedAt = DateTime.now();
  Socket? _activeOperationClient;
  final _pluginClients = <Socket, String>{};
  static final _log = getLogger('DaemonServer');

  Future<void> run() async {
    final runtimeDirectory = Directory(daemonRuntimeDirectory);
    await runtimeDirectory.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', runtimeDirectory.path]);
    }
    if (Platform.isWindows) {
      final lockFile = await File(
        daemonWindowsLockPath,
      ).open(mode: FileMode.append);
      try {
        await lockFile.lock(FileLock.exclusive);
        _windowsLock = lockFile;
      } catch (_) {
        await lockFile.close();
        throw StateError('ZeroBox daemon is already starting or running');
      }
      _server = await ServerSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
        shared: false,
      );
      _windowsToken = base64Url.encode(
        List<int>.generate(32, (_) => Random.secure().nextInt(256)),
      );
      await publishWindowsDaemonEndpoint(
        WindowsDaemonEndpoint(
          port: _server!.port,
          token: _windowsToken!,
          pid: pid,
          protocolVersion: zeroBoxProtocolVersion,
        ),
      );
    } else {
      final socketFile = File(daemonSocketPath);
      if (await socketFile.exists()) {
        try {
          final probe = await Socket.connect(
            InternetAddress(daemonSocketPath, type: InternetAddressType.unix),
            0,
            timeout: const Duration(milliseconds: 250),
          );
          await probe.close();
          throw StateError('ZeroBox daemon is already running');
        } catch (error) {
          if (error is StateError) rethrow;
          await socketFile.delete();
        }
      }
      _server = await ServerSocket.bind(
        InternetAddress(daemonSocketPath, type: InternetAddressType.unix),
        0,
      );
      await Process.run('chmod', ['600', daemonSocketPath]);
    }
    _eventSubscription = host.events.listen(_broadcastEvent);
    await for (final client in _server!) {
      _clients.add(client);
      unawaited(_serve(client));
    }
  }

  Future<void> _serve(Socket client) async {
    try {
      await for (final line
          in client
              .cast<List<int>>()
              .transform(utf8.decoder)
              .transform(const LineSplitter())) {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          _write(
            client,
            const CommandResult.failure(
              CommandError('invalid_request', 'Request must be a JSON object'),
            ).toJson(),
          );
          continue;
        }
        final request = decoded.cast<String, dynamic>();
        final id = request['id']?.toString() ?? '';
        if (Platform.isWindows && request['token'] != _windowsToken) {
          _write(client, {
            'id': id,
            ...const CommandResult.failure(
              CommandError('unauthorized', 'Invalid daemon token'),
            ).toJson(),
          });
          continue;
        }
        final command = ZeroBoxCommand.fromJson(
          request.cast<String, Object?>(),
        );
        if (command.method == 'daemon.stop') {
          _write(client, {
            'id': id,
            ...const CommandResult.success({'stopping': true}).toJson(),
          });
          unawaited(
            Future<void>.delayed(const Duration(milliseconds: 50), close),
          );
          continue;
        }
        if (command.method == 'plugin.open' ||
            command.method == 'plugin.invoke' ||
            command.method == 'device.connect') {
          unawaited(
            command.method.startsWith('plugin.')
                ? _executePluginAndWrite(client, id, command)
                : _executeAndWrite(client, id, command),
          );
          continue;
        }
        if (command.method == 'plugin.close') {
          _pluginClients.remove(client);
        }
        if (command.method == 'device.connect.cancel') {
          await host.cancelActiveOperation();
          _write(client, {
            'id': id,
            ...const CommandResult.success({'cancelled': true}).toJson(),
          });
          continue;
        }
        final result = switch (command.method) {
          'daemon.info' => CommandResult.success(_daemonInfo()),
          _ => await _executeForClient(client, command),
        };
        _write(client, {'id': id, ...result.toJson()});
      }
    } catch (_) {
      // A disconnected CLI client is expected and does not stop the daemon.
    } finally {
      _clients.remove(client);
      final pluginId = _pluginClients.remove(client);
      if (pluginId != null && !_pluginClients.containsValue(pluginId)) {
        await host.execute(
          ZeroBoxCommand(method: 'plugin.close', params: {'id': pluginId}),
        );
      }
      await client.close();
    }
  }

  Future<CommandResult> _executeForClient(
    Socket client,
    ZeroBoxCommand command,
  ) async {
    _activeOperationClient = client;
    try {
      return await host.execute(command);
    } finally {
      if (identical(_activeOperationClient, client)) {
        _activeOperationClient = null;
      }
    }
  }

  Future<void> _executeAndWrite(
    Socket client,
    String id,
    ZeroBoxCommand command,
  ) async {
    final result = await _executeForClient(client, command);
    _write(client, {'id': id, ...result.toJson()});
  }

  Future<void> _executePluginAndWrite(
    Socket client,
    String id,
    ZeroBoxCommand command,
  ) async {
    final result = await _executeForClient(client, command);
    if (result.ok) {
      final pluginId = command.params['id']?.toString() ?? '';
      if (_clients.contains(client)) {
        _pluginClients[client] = pluginId;
      } else {
        await host.execute(
          ZeroBoxCommand(method: 'plugin.close', params: {'id': pluginId}),
        );
      }
    }
    _write(client, {'id': id, ...result.toJson()});
  }

  Map<String, Object?> _daemonInfo() => {
    'running': true,
    'pid': pid,
    'protocolVersion': zeroBoxProtocolVersion,
    'startedAt': startedAt.toIso8601String(),
    'uptimeSeconds': DateTime.now().difference(startedAt).inSeconds,
    'platform': Platform.operatingSystem,
    'endpoint': Platform.isWindows
        ? '127.0.0.1:${_server?.port ?? 0}'
        : daemonSocketPath,
    'capabilities': zeroBoxDaemonCapabilities,
    'tasks': host.taskSummary,
  };

  void _broadcastEvent(CommandEvent event) {
    if (event.event == 'plugin.hostRequest') {
      _log.info(
        'broadcasting plugin host request '
        '${event.data['requestId']} to ${_clients.length} clients',
      );
    }
    final message = {'messageType': 'event', ...event.toJson()};
    final broadcast =
        event.event == 'device.state' ||
        event.event == 'account.state' ||
        event.event == 'settings.state' ||
        event.event == 'log' ||
        event.event == 'task' ||
        event.event == 'task.removed' ||
        event.event.startsWith('plugin.');
    if (!broadcast && _activeOperationClient != null) {
      _write(_activeOperationClient!, message);
      return;
    }
    for (final client in _clients.toList()) {
      _write(client, message);
    }
  }

  void _write(Socket client, Map<String, Object?> value) {
    client.writeln(jsonEncode(value));
  }

  Future<void> close() async {
    await _eventSubscription?.cancel();
    await _server?.close();
    for (final client in _clients.toList()) {
      await client.close();
    }
    await host.close();
    container.dispose();
    if (!Platform.isWindows) {
      final socketFile = File(daemonSocketPath);
      if (await socketFile.exists()) await socketFile.delete();
    } else {
      final endpointFile = File(daemonWindowsEndpointPath);
      if (await endpointFile.exists()) {
        try {
          final endpoints = await readWindowsDaemonEndpoints();
          if (endpoints.any((endpoint) => endpoint.token == _windowsToken)) {
            await endpointFile.delete();
          }
        } catch (_) {}
      }
      await _windowsLock?.unlock();
      await _windowsLock?.close();
      _windowsLock = null;
    }
  }
}
