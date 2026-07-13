import 'dart:convert';
import 'dart:io';

import 'package:zerobox/src/commands/command_protocol.dart';

String get daemonRuntimeDirectory => resolveDaemonRuntimeDirectory(
  operatingSystem: Platform.operatingSystem,
  environment: Platform.environment,
  systemTemporaryDirectory: Directory.systemTemp.path,
);

String resolveDaemonRuntimeDirectory({
  required String operatingSystem,
  required Map<String, String> environment,
  required String systemTemporaryDirectory,
}) {
  if (operatingSystem == 'windows') {
    final base = environment['LOCALAPPDATA'] ?? systemTemporaryDirectory;
    return '$base\\ZeroBox\\run';
  }
  if (operatingSystem == 'macos') {
    // Darwin's sockaddr_un.sun_path is limited to roughly 104 bytes. A
    // sandbox container's Application Support path can exceed that before the
    // socket filename is appended. systemTemp is writable, per-user and
    // container-aware, while remaining short enough for a Unix socket.
    return '$systemTemporaryDirectory/zerobox';
  }
  final runtime = environment['XDG_RUNTIME_DIR'];
  if (runtime?.isNotEmpty == true) return '$runtime/zerobox';
  final home = environment['HOME'] ?? systemTemporaryDirectory;
  return '$home/.local/share/zerobox/run';
}

String get daemonSocketPath => '$daemonRuntimeDirectory/daemon.sock';

String get daemonWindowsEndpointPath =>
    '$daemonRuntimeDirectory${Platform.pathSeparator}daemon.json';
String get daemonWindowsLockPath =>
    '$daemonRuntimeDirectory${Platform.pathSeparator}daemon.lock';

class WindowsDaemonEndpoint {
  const WindowsDaemonEndpoint({
    required this.port,
    required this.token,
    required this.pid,
    required this.protocolVersion,
  });

  final int port;
  final String token;
  final int pid;
  final int protocolVersion;

  Map<String, Object?> toJson() => {
    'port': port,
    'token': token,
    'pid': pid,
    'protocolVersion': protocolVersion,
  };

  factory WindowsDaemonEndpoint.fromJson(Map<String, Object?> json) {
    final port = (json['port'] as num?)?.toInt() ?? 0;
    final token = json['token']?.toString() ?? '';
    if (port < 1 || port > 65535 || token.isEmpty) {
      throw const FormatException('Invalid ZeroBox daemon endpoint');
    }
    return WindowsDaemonEndpoint(
      port: port,
      token: token,
      pid: (json['pid'] as num?)?.toInt() ?? 0,
      protocolVersion:
          (json['protocolVersion'] as num?)?.toInt() ?? zeroBoxProtocolVersion,
    );
  }
}

Future<List<WindowsDaemonEndpoint>> readWindowsDaemonEndpoints() async {
  final endpoints = <WindowsDaemonEndpoint>[];
  final endpointFile = File(daemonWindowsEndpointPath);
  if (await endpointFile.exists()) {
    try {
      final decoded = jsonDecode(await endpointFile.readAsString());
      if (decoded is Map) {
        endpoints.add(
          WindowsDaemonEndpoint.fromJson(decoded.cast<String, Object?>()),
        );
      }
    } catch (_) {
      // A partial or stale discovery file is ignored. The authenticated
      // handshake still decides whether any candidate is a ZeroBox daemon.
    }
  }

  return endpoints;
}

Future<void> publishWindowsDaemonEndpoint(
  WindowsDaemonEndpoint endpoint,
) async {
  final target = File(daemonWindowsEndpointPath);
  final temporary = File('$daemonWindowsEndpointPath.${endpoint.pid}.tmp');
  await temporary.writeAsString(jsonEncode(endpoint.toJson()), flush: true);
  try {
    await temporary.rename(target.path);
  } on FileSystemException {
    if (await target.exists()) await target.delete();
    await temporary.rename(target.path);
  }
}
