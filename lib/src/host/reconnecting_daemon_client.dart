import 'dart:async';
import 'dart:io';

import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/daemon/daemon_client.dart';

/// A stable GUI-side adapter over daemon process restarts
class ReconnectingDaemonClient implements ZeroBoxCommandBus {
  ZeroBoxDaemonClient? _client;
  StreamSubscription<CommandEvent>? _subscription;
  Future<ZeroBoxDaemonClient>? _connecting;
  Timer? _reconnectTimer;
  final _events = StreamController<CommandEvent>.broadcast();
  bool _closed = false;

  ReconnectingDaemonClient() {
    scheduleMicrotask(_reconnect);
  }

  @override
  Stream<CommandEvent> get events => _events.stream;

  @override
  Future<CommandResult> execute(ZeroBoxCommand command) async {
    var client = await _ensureClient();
    var result = await client.execute(command);
    if (result.error?.code == 'daemon_disconnected') {
      await _detach(client);
      client = await _ensureClient();
      result = await client.execute(command);
    }
    return result;
  }

  Future<ZeroBoxDaemonClient> _ensureClient() {
    final current = _client;
    if (current != null) return Future.value(current);
    return _connecting ??= _connect().whenComplete(() => _connecting = null);
  }

  Future<ZeroBoxDaemonClient> _connect() async {
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt += 1) {
      try {
        return await _attach(await ZeroBoxDaemonClient.connect());
      } catch (error) {
        lastError = error;
        if (attempt == 0) await _startDaemon();
      }
    }
    throw StateError('Unable to start ZeroBox daemon: $lastError');
  }

  Future<void> _startDaemon() async {
    await Process.start(Platform.resolvedExecutable, const [
      '--nogui',
      'daemon',
      'run',
    ], mode: ProcessStartMode.detached);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    for (var attempt = 0; attempt < 49; attempt += 1) {
      try {
        final client = await ZeroBoxDaemonClient.connect(
          timeout: const Duration(milliseconds: 250),
        );
        await client.close();
        return;
      } catch (_) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<ZeroBoxDaemonClient> _attach(ZeroBoxDaemonClient client) async {
    await _subscription?.cancel();
    if (_closed) {
      await client.close();
      throw StateError('Application host client is closed');
    }
    _client = client;
    _subscription = client.events.listen((event) {
      if (event.event == 'daemon.disconnected') {
        unawaited(_detach(client));
        return;
      }
      _events.add(event);
    }, onDone: () => unawaited(_detach(client)));
    return client;
  }

  Future<void> _detach(ZeroBoxDaemonClient client) async {
    if (!identical(_client, client)) return;
    _client = null;
    await _subscription?.cancel();
    _subscription = null;
    if (!_closed) {
      _events.add(const CommandEvent('host.disconnected'));
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(milliseconds: 500), _reconnect);
    }
  }

  Future<void> _reconnect() async {
    if (_closed || _client != null || _connecting != null) return;
    try {
      await _ensureClient();
      if (!_closed) _events.add(const CommandEvent('host.connected'));
    } catch (_) {
      if (_closed) return;
      _reconnectTimer?.cancel();
      _reconnectTimer = Timer(const Duration(seconds: 2), _reconnect);
    }
  }

  @override
  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _client?.close();
    await _events.close();
  }
}
