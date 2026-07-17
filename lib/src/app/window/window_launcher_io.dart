import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:window_manager/window_manager.dart';
import 'package:zerobox/src/app/window/window_launch_spec.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';

bool get supportsSecondaryWindows =>
    Platform.isLinux || Platform.isMacOS || Platform.isWindows;

final _coordinator = _WindowCoordinator();
_SecondaryWindowControl? _secondaryControl;

Future<bool> initializeWindowCoordinator(WindowLaunchSpec spec) async {
  if (!supportsSecondaryWindows) return true;
  if (spec.isSecondary) {
    _secondaryControl = await _SecondaryWindowControl.connect(spec);
    return true;
  } else {
    return _coordinator.initialize();
  }
}

Future<void> notifySecondaryWindowReady() async {
  await _secondaryControl?.ready();
}

Future<bool> openDebugWindow() =>
    _coordinator.open(key: 'debug', arguments: const ['--window', 'debug']);

Future<bool> closeDebugWindow() => _coordinator.close('debug');

Future<bool> openPluginWindow(String pluginId) => _coordinator.open(
  key: 'plugin:$pluginId',
  arguments: ['--window', 'plugin', '--plugin-id', pluginId],
);

Future<void> shutdownSecondaryWindows() => _coordinator.shutdown();

Future<void> reportSecondaryWindowBounds({
  required String role,
  required double width,
  required double height,
  required double x,
  required double y,
}) async {
  await _secondaryControl?.send({
    'event': 'bounds',
    'role': role,
    'width': width,
    'height': height,
    'x': x,
    'y': y,
  });
}

class _WindowCoordinator {
  final _sessions = <String, _WindowSession>{};
  final _tokens = <String, _WindowSession>{};
  ServerSocket? _server;
  RandomAccessFile? _primaryLock;
  String? _ownerToken;
  bool _shuttingDown = false;

  Future<bool> initialize() async {
    if (_server != null) return true;
    if (!supportsSecondaryWindows) return true;
    final runtimeDirectory = Directory(daemonRuntimeDirectory);
    await runtimeDirectory.create(recursive: true);
    if (!Platform.isWindows) {
      await Process.run('chmod', ['700', runtimeDirectory.path]);
    }
    final lock = await File(
      '${runtimeDirectory.path}${Platform.pathSeparator}gui.lock',
    ).open(mode: FileMode.append);
    try {
      await lock.lock(FileLock.exclusive);
      _primaryLock = lock;
    } catch (_) {
      await lock.close();
      await _focusPrimary(runtimeDirectory);
      exit(0);
    }
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_accept);
    _ownerToken = _randomToken();
    final endpoint = File(
      '${runtimeDirectory.path}${Platform.pathSeparator}gui.json',
    );
    await endpoint.writeAsString(
      jsonEncode({'port': server.port, 'token': _ownerToken, 'pid': pid}),
      flush: true,
    );
    if (!Platform.isWindows) {
      await Process.run('chmod', ['600', endpoint.path]);
    }
    return true;
  }

  Future<bool> open({
    required String key,
    required List<String> arguments,
  }) async {
    if (_shuttingDown || !supportsSecondaryWindows) return false;
    if (!await initialize()) return false;
    final existing = _sessions[key];
    if (existing != null) {
      if (!await existing.waitUntilReady()) return false;
      existing.send(const {'command': 'focus'});
      return true;
    }

    final token = _randomToken();
    late final Process process;
    try {
      process = await Process.start(Platform.resolvedExecutable, [
        ...arguments,
        '--window-port',
        _server!.port.toString(),
        '--window-token',
        token,
      ]);
    } catch (_) {
      return false;
    }
    unawaited(process.stdout.drain<void>());
    unawaited(process.stderr.drain<void>());
    final session = _WindowSession(key: key, token: token, process: process);
    _sessions[key] = session;
    _tokens[token] = session;
    unawaited(
      process.exitCode.then((_) {
        if (identical(_sessions[key], session)) _sessions.remove(key);
        _tokens.remove(token);
        session.completeExited();
      }),
    );
    if (await session.waitUntilReady()) return true;
    await _terminate(session);
    return false;
  }

  Future<bool> close(String key) async {
    final session = _sessions[key];
    if (session == null) return true;
    session.send(const {'command': 'close'});
    try {
      await session.exited.timeout(const Duration(seconds: 4));
    } on TimeoutException {
      await _terminate(session);
    }
    return !_sessions.containsKey(key);
  }

  Future<void> shutdown() async {
    if (_shuttingDown) return;
    _shuttingDown = true;
    await Future.wait(_sessions.keys.toList().map(close));
    await _server?.close();
    _server = null;
    final endpoint = File(
      '$daemonRuntimeDirectory${Platform.pathSeparator}gui.json',
    );
    if (await endpoint.exists()) await endpoint.delete();
    await _primaryLock?.unlock();
    await _primaryLock?.close();
    _primaryLock = null;
  }

  void _accept(Socket socket) {
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) => _handle(socket, line),
          onDone: () => _detach(socket),
          onError: (_) => _detach(socket),
          cancelOnError: true,
        );
  }

  void _handle(Socket socket, String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map) return;
    final message = decoded.cast<String, Object?>();
    final token = message['token']?.toString();
    if (token != null) {
      if (token == _ownerToken && message['action'] == 'focus-main') {
        unawaited(_focusMainWindow());
        unawaited(socket.close());
        return;
      }
      final session = _tokens[token];
      if (session == null || session.socket != null) {
        unawaited(socket.close());
        return;
      }
      session.socket = socket;
      return;
    }
    final session = _sessions.values
        .where((candidate) => identical(candidate.socket, socket))
        .firstOrNull;
    if (session == null) return;
    switch (message['event']) {
      case 'ready':
        session.completeReady();
        return;
      case 'bounds':
        unawaited(_saveBounds(message));
        return;
    }
  }

  void _detach(Socket socket) {
    for (final session in _sessions.values) {
      if (identical(session.socket, socket)) session.socket = null;
    }
  }

  Future<void> _saveBounds(Map<String, Object?> message) async {
    final role = message['role']?.toString();
    if (role == null || role.isEmpty) return;
    final prefs = SharedPrefsService.instance;
    await prefs.setDouble(
      'window.$role.width',
      (message['width'] as num).toDouble(),
    );
    await prefs.setDouble(
      'window.$role.height',
      (message['height'] as num).toDouble(),
    );
    await prefs.setDouble('window.$role.x', (message['x'] as num).toDouble());
    await prefs.setDouble('window.$role.y', (message['y'] as num).toDouble());
  }

  Future<void> _terminate(_WindowSession session) async {
    session.process.kill();
    try {
      await session.exited.timeout(const Duration(seconds: 2));
    } on TimeoutException {
      session.process.kill();
    }
  }

  Future<void> _focusPrimary(Directory runtimeDirectory) async {
    try {
      final decoded = jsonDecode(
        await File(
          '${runtimeDirectory.path}${Platform.pathSeparator}gui.json',
        ).readAsString(),
      );
      if (decoded is! Map) return;
      final socket = await Socket.connect(
        InternetAddress.loopbackIPv4,
        (decoded['port'] as num).toInt(),
        timeout: const Duration(seconds: 1),
      );
      socket.writeln(
        jsonEncode({'token': decoded['token'], 'action': 'focus-main'}),
      );
      await socket.flush();
      await socket.close();
    } catch (_) {
      // The existing GUI may still be starting or shutting down.
    }
  }

  Future<void> _focusMainWindow() async {
    try {
      await windowManager.show();
      if (await windowManager.isMinimized()) await windowManager.restore();
      await windowManager.focus();
    } catch (_) {
      // The primary window may still be completing native initialization.
    }
  }

  String _randomToken() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }
}

class _WindowSession {
  _WindowSession({
    required this.key,
    required this.token,
    required this.process,
  });

  final String key;
  final String token;
  final Process process;
  final _ready = Completer<void>();
  final _exited = Completer<void>();
  Socket? socket;

  Future<void> get exited => _exited.future;

  Future<bool> waitUntilReady() async {
    try {
      await Future.any([
        _ready.future,
        _exited.future,
      ]).timeout(const Duration(seconds: 6));
      return _ready.isCompleted && !_exited.isCompleted;
    } on TimeoutException {
      return false;
    }
  }

  void completeReady() {
    if (!_ready.isCompleted) _ready.complete();
  }

  void completeExited() {
    if (!_exited.isCompleted) _exited.complete();
    if (!_ready.isCompleted) _ready.complete();
  }

  void send(Map<String, Object?> message) {
    socket?.writeln(jsonEncode(message));
  }
}

class _SecondaryWindowControl {
  _SecondaryWindowControl(this._socket);

  final Socket _socket;
  bool _closing = false;

  static Future<_SecondaryWindowControl> connect(WindowLaunchSpec spec) async {
    final port = spec.controlPort;
    final token = spec.controlToken;
    if (port == null || token == null) {
      throw StateError('Secondary window requires an owner connection');
    }
    final socket = await Socket.connect(InternetAddress.loopbackIPv4, port);
    final control = _SecondaryWindowControl(socket);
    socket.writeln(jsonEncode({'token': token}));
    socket
        .cast<List<int>>()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          control._handle,
          onDone: control._ownerClosed,
          onError: (_) => control._ownerClosed(),
          cancelOnError: true,
        );
    return control;
  }

  Future<void> ready() => send(const {'event': 'ready'});

  Future<void> send(Map<String, Object?> message) async {
    _socket.writeln(jsonEncode(message));
    await _socket.flush();
  }

  void _handle(String line) {
    final decoded = jsonDecode(line);
    if (decoded is! Map) return;
    switch (decoded['command']) {
      case 'focus':
        unawaited(_focus());
        return;
      case 'close':
        unawaited(_close());
        return;
    }
  }

  Future<void> _focus() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  void _ownerClosed() => unawaited(_close());

  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    await windowManager.setPreventClose(false);
    await windowManager.close();
  }
}
