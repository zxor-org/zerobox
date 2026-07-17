Future<Map<String, Object?>> collectDebugRuntimeEnvironment() async => {
  'system': {'platform': 'web'},
  'host': {'kind': 'flutter-web'},
  'runtime': {'dart': 'JavaScript'},
};

Future<List<Map<String, Object?>>> debugHostStorageRoots() async => const [];

Future<List<Map<String, Object?>>> listDebugHostDirectory(
  String root,
  String path,
) async => const [];

Future<Map<String, Object?>> readDebugHostFile(
  String root,
  String path,
) async =>
    throw UnsupportedError('Host files are unavailable on this platform');
