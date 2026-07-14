import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';

class ZeroBoxDaemonClient implements ZeroBoxCommandBus {
  ZeroBoxDaemonClient._(this._socket, this._token) {
    _subscription = _socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          _handleLine,
          onDone: _handleDone,
          onError: (_) => _handleDone(),
        );
  }

  final Socket _socket;
  final String? _token;
  late final StreamSubscription<String> _subscription;
  final _pending = <String, _PendingRequest>{};
  final _events = StreamController<CommandEvent>.broadcast();
  var _nextId = 0;

  static Future<ZeroBoxDaemonClient> connect({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    if (!Platform.isWindows) {
      final client = ZeroBoxDaemonClient._(await _connectUnix(timeout), null);
      try {
        await client._verifyDaemon();
        return client;
      } catch (_) {
        await client.close();
        rethrow;
      }
    }

    final endpoints = await readWindowsDaemonEndpoints();
    if (endpoints.isEmpty) {
      throw StateError('ZeroBox daemon endpoint is unavailable');
    }
    Object? lastError;
    for (final endpoint in endpoints) {
      ZeroBoxDaemonClient? client;
      try {
        final socket = await Socket.connect(
          InternetAddress.loopbackIPv4,
          endpoint.port,
          timeout: timeout,
        );
        client = ZeroBoxDaemonClient._(socket, endpoint.token);
        await client._verifyDaemon();
        return client;
      } catch (error) {
        lastError = error;
        await client?.close();
      }
    }
    throw StateError('Unable to authenticate ZeroBox daemon: $lastError');
  }

  Future<void> _verifyDaemon() async {
    final result = await execute(
      const ZeroBoxCommand(method: 'daemon.info'),
      timeout: const Duration(seconds: 2),
    );
    if (!result.ok) {
      throw StateError(
        '${result.error?.code ?? 'handshake_failed'}: '
        '${result.error?.message ?? 'Daemon handshake failed'}',
      );
    }
    final info = result.value;
    if (info is! Map ||
        info['running'] != true ||
        info['platform'] != Platform.operatingSystem) {
      throw StateError('The endpoint is not a compatible ZeroBox daemon');
    }
    if (info['protocolVersion'] != zeroBoxProtocolVersion) {
      await execute(
        const ZeroBoxCommand(method: 'daemon.stop'),
        timeout: const Duration(seconds: 2),
      );
      throw StateError('The ZeroBox daemon protocol version is outdated');
    }
  }

  static Future<Socket> _connectUnix(Duration timeout) async {
    return Socket.connect(
      InternetAddress(daemonSocketPath, type: InternetAddressType.unix),
      0,
      timeout: timeout,
    );
  }

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(
    ZeroBoxCommand command, {
    Duration timeout = const Duration(minutes: 10),
  }) {
    final id = '${++_nextId}';
    final completer = Completer<CommandResult>();
    final timer = Timer(timeout, () {
      final pending = _pending.remove(id);
      pending?.completer.complete(
        CommandResult.failure(
          CommandError(
            'timeout',
            'Daemon request timed out: ${command.method}',
          ),
        ),
      );
    });
    _pending[id] = _PendingRequest(completer, timer);
    _socket.writeln(
      jsonEncode({
        'id': id,
        if (_token != null) 'token': _token,
        ...command.toJson(),
      }),
    );
    return completer.future;
  }

  void _handleLine(String line) {
    try {
      final value = jsonDecode(line) as Map<String, dynamic>;
      if (value['messageType'] == 'event') {
        final event = value['event']?.toString() ?? 'unknown';
        final data = Map<String, Object?>.from(value)
          ..remove('messageType')
          ..remove('event');
        _events.add(CommandEvent(event, data: data));
        return;
      }
      final id = value['id']?.toString() ?? '';
      final pending = _pending.remove(id);
      pending?.timer.cancel();
      pending?.completer.complete(
        CommandResult.fromJson(value.cast<String, Object?>()),
      );
    } catch (_) {
      // Treat malformed input as a failed handshake/connection instead of
      // leaking a parser exception when a stale endpoint targets another app.
      _handleDone();
      unawaited(_socket.close());
    }
  }

  void _handleDone() {
    for (final pending in _pending.values) {
      pending.timer.cancel();
      if (!pending.completer.isCompleted) {
        pending.completer.complete(
          const CommandResult.failure(
            CommandError('daemon_disconnected', 'Daemon disconnected'),
          ),
        );
      }
    }
    _pending.clear();
    if (!_events.isClosed) {
      _events.add(const CommandEvent('daemon.disconnected'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await _socket.close();
    await _events.close();
  }
}

class _PendingRequest {
  _PendingRequest(this.completer, this.timer);
  final Completer<CommandResult> completer;
  final Timer timer;
}
