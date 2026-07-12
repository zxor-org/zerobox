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
    // Sandboxed macOS apps keep HOME pointed at the real user home while their
    // writable data lives below Library/Containers/<bundle-id>/Data. The
    // system temporary directory is already container-aware, so use its Data
    // parent when available. The GUI and its daemon child then resolve the
    // exact same writable endpoint.
    final temporaryDirectory = systemTemporaryDirectory;
    if (temporaryDirectory.contains('/Library/Containers/') &&
        temporaryDirectory.endsWith('/tmp')) {
      final containerData = Directory(temporaryDirectory).parent.path;
      return '$containerData/Library/Application Support/ZeroBox/run';
    }
    final home = environment['HOME'] ?? systemTemporaryDirectory;
    return '$home/Library/Application Support/ZeroBox/run';
  }
  final runtime = environment['XDG_RUNTIME_DIR'];
  if (runtime?.isNotEmpty == true) return '$runtime/zerobox';
  final home = environment['HOME'] ?? systemTemporaryDirectory;
  return '$home/.local/share/zerobox/run';
}

String get daemonSocketPath => '$daemonRuntimeDirectory/daemon.sock';

String get legacyDaemonSocketPath {
  final user =
      Platform.environment['USER'] ??
      Platform.environment['USERNAME'] ??
      'user';
  return '${Directory.systemTemp.path}/zerobox-$user.sock';
}

const legacyDaemonWindowsPort = 47832;
String get daemonWindowsEndpointPath =>
    '$daemonRuntimeDirectory${Platform.pathSeparator}daemon.json';
String get daemonWindowsTokenPath =>
    '$daemonRuntimeDirectory${Platform.pathSeparator}daemon.token';
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

  final legacyTokenFile = File(daemonWindowsTokenPath);
  if (await legacyTokenFile.exists()) {
    final token = (await legacyTokenFile.readAsString()).trim();
    if (token.isNotEmpty) {
      endpoints.add(
        WindowsDaemonEndpoint(
          port: legacyDaemonWindowsPort,
          token: token,
          pid: 0,
          protocolVersion: zeroBoxProtocolVersion,
        ),
      );
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
