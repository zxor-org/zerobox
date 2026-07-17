import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:zerobox/src/core/services/build_info_service.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';

Future<Map<String, Object?>> collectDebugRuntimeEnvironment() async => {
  'system': {
    'operatingSystem': Platform.operatingSystem,
    'version': Platform.operatingSystemVersion,
    'architecture': Abi.current().toString(),
    'locale': Platform.localeName,
    'hostname': Platform.localHostname,
    'processors': Platform.numberOfProcessors,
  },
  'host': {
    'kind': 'zerobox-daemon',
    'pid': pid,
    'executable': Platform.resolvedExecutable,
    'workingDirectory': Directory.current.path,
    'residentMemory': ProcessInfo.currentRss,
    'peakResidentMemory': ProcessInfo.maxRss,
  },
  'runtime': {
    'dart': Platform.version,
    'appVersion': BuildInfoService.appVersion,
    'commit': await BuildInfoService.resolveCommitHash(),
    'builder': BuildInfoService.buildUser,
  },
};

Future<Map<String, Directory>> _hostRoots() async {
  final support = await getApplicationSupportDirectory();
  final cache = await getApplicationCacheDirectory();
  return {
    'data': support,
    'cache': cache,
    'logs': Directory('${support.path}${Platform.pathSeparator}logs'),
    'temporary': await getTemporaryDirectory(),
    'runtime': Directory(daemonRuntimeDirectory),
  };
}

Future<List<Map<String, Object?>>> debugHostStorageRoots() async {
  final roots = await _hostRoots();
  return [
    for (final entry in roots.entries)
      {
        'name': entry.key,
        'path': '',
        'nativePath': entry.value.path,
        'isDirectory': true,
      },
  ];
}

Future<List<Map<String, Object?>>> listDebugHostDirectory(
  String root,
  String path,
) async {
  final roots = await _hostRoots();
  final base = roots[root];
  if (base == null) throw ArgumentError.value(root, 'root', 'Unknown root');
  final parts = path
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.any((part) => part == '.' || part == '..' || part.contains('\\'))) {
    throw const FormatException('Unsafe storage path');
  }
  final directory = Directory(
    [base.path, ...parts].join(Platform.pathSeparator),
  );
  if (!await directory.exists()) return const [];
  final entries = <Map<String, Object?>>[];
  await for (final entity in directory.list(followLinks: false)) {
    final stat = await entity.stat();
    entries.add({
      'name': entity.uri.pathSegments.where((part) => part.isNotEmpty).last,
      'path': [
        ...parts,
        entity.uri.pathSegments.where((p) => p.isNotEmpty).last,
      ].join('/'),
      'nativePath': entity.path,
      'isDirectory': stat.type == FileSystemEntityType.directory,
      'size': stat.size,
      'modified': stat.modified.toIso8601String(),
    });
  }
  entries.sort((a, b) {
    final directoryOrder =
        (b['isDirectory'] == true ? 1 : 0) - (a['isDirectory'] == true ? 1 : 0);
    return directoryOrder != 0
        ? directoryOrder
        : a['name'].toString().toLowerCase().compareTo(
            b['name'].toString().toLowerCase(),
          );
  });
  return entries;
}

Future<Map<String, Object?>> readDebugHostFile(String root, String path) async {
  final roots = await _hostRoots();
  final base = roots[root];
  if (base == null) throw ArgumentError.value(root, 'root', 'Unknown root');
  final parts = _safePathParts(path);
  if (parts.isEmpty) throw const FormatException('A file path is required');
  final file = File([base.path, ...parts].join(Platform.pathSeparator));
  final size = await file.length();
  const previewLimit = 1024 * 1024;
  final bytes = await file
      .openRead(0, size.clamp(0, previewLimit))
      .fold(<int>[], (buffer, chunk) => buffer..addAll(chunk));
  return _filePreview(path, size, bytes);
}

List<String> _safePathParts(String path) {
  final parts = path
      .split('/')
      .where((part) => part.isNotEmpty)
      .toList(growable: false);
  if (parts.any((part) => part == '.' || part == '..' || part.contains('\\'))) {
    throw const FormatException('Unsafe storage path');
  }
  return parts;
}

Map<String, Object?> _filePreview(String path, int size, List<int> bytes) {
  final binary = bytes.any((byte) => byte == 0);
  return {
    'path': path,
    'size': size,
    'truncated': size > bytes.length,
    'format': binary ? 'hex' : 'text',
    'content': binary
        ? bytes
              .take(4096)
              .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
              .toList()
              .asMap()
              .entries
              .map(
                (entry) => entry.key % 16 == 15
                    ? '${entry.value}\n'
                    : '${entry.value} ',
              )
              .join()
              .trimRight()
        : utf8.decode(bytes, allowMalformed: true),
  };
}
