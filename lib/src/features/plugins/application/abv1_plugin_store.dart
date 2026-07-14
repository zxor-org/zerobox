import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dio/dio.dart';

const abV1PluginStoreIndexUrl =
    'https://raw.githubusercontent.com/AstralSightStudios/'
    'AstroBox-Plugin-Repo/refs/heads/main/index.txt';

int comparePluginVersions(String left, String right) {
  final leftVersion = _PluginVersion.parse(left);
  final rightVersion = _PluginVersion.parse(right);
  return leftVersion.compareTo(rightVersion);
}

class _PluginVersion implements Comparable<_PluginVersion> {
  const _PluginVersion(this.core, this.preRelease);

  final List<int> core;
  final List<String> preRelease;

  factory _PluginVersion.parse(String value) {
    var normalized = value.trim().toLowerCase();
    if (normalized.startsWith('v')) normalized = normalized.substring(1);
    normalized = normalized.split('+').first;
    final parts = normalized.split('-');
    final core = parts.first
        .split('.')
        .map(
          (part) => int.tryParse(RegExp(r'^\d+').stringMatch(part) ?? '') ?? 0,
        )
        .toList(growable: true);
    while (core.length < 3) {
      core.add(0);
    }
    final preRelease = parts.length <= 1
        ? const <String>[]
        : parts.skip(1).join('-').split('.');
    return _PluginVersion(core, preRelease);
  }

  @override
  int compareTo(_PluginVersion other) {
    final length = core.length > other.core.length
        ? core.length
        : other.core.length;
    for (var index = 0; index < length; index++) {
      final comparison = (index < core.length ? core[index] : 0).compareTo(
        index < other.core.length ? other.core[index] : 0,
      );
      if (comparison != 0) return comparison;
    }
    if (preRelease.isEmpty != other.preRelease.isEmpty) {
      return preRelease.isEmpty ? 1 : -1;
    }
    for (
      var index = 0;
      index < preRelease.length && index < other.preRelease.length;
      index++
    ) {
      final left = preRelease[index];
      final right = other.preRelease[index];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);
      final comparison = leftNumber != null && rightNumber != null
          ? leftNumber.compareTo(rightNumber)
          : leftNumber != null
          ? -1
          : rightNumber != null
          ? 1
          : left.compareTo(right);
      if (comparison != 0) return comparison;
    }
    return preRelease.length.compareTo(other.preRelease.length);
  }
}

class StorePlugin {
  const StorePlugin({
    required this.repositoryUrl,
    required this.folder,
    required this.name,
    required this.icon,
    required this.version,
    required this.description,
    required this.author,
    required this.website,
    required this.entry,
    required this.apiLevel,
    required this.permissions,
    required this.additionalFiles,
    this.iconBytes,
  });

  final Uri repositoryUrl;
  final String folder;
  final String name;
  final String icon;
  final String version;
  final String description;
  final String author;
  final String website;
  final String entry;
  final int apiLevel;
  final List<String> permissions;
  final List<String> additionalFiles;
  final Uint8List? iconBytes;

  StorePlugin copyWith({Uint8List? iconBytes}) => StorePlugin(
    repositoryUrl: repositoryUrl,
    folder: folder,
    name: name,
    icon: icon,
    version: version,
    description: description,
    author: author,
    website: website,
    entry: entry,
    apiLevel: apiLevel,
    permissions: permissions,
    additionalFiles: additionalFiles,
    iconBytes: iconBytes ?? this.iconBytes,
  );

  Uri fileUrl(String path) => repositoryUrl.resolve('$folder/$path');
  Uri get iconUrl => fileUrl(icon);
}

class AbV1PluginStore {
  AbV1PluginStore(this._dio);

  final Dio _dio;

  Future<List<StorePlugin>> load() async {
    final repositories = _lines(
      await _getText(Uri.parse(abV1PluginStoreIndexUrl)),
    );
    final entries = (await Future.wait(
      repositories.map((repository) async {
        final repositoryUrl = _directoryUri(repository);
        final folders = _lines(
          await _getText(repositoryUrl.resolve('index.txt')),
        );
        return folders
            .map((folder) => (repositoryUrl: repositoryUrl, folder: folder))
            .toList(growable: false);
      }),
    )).expand((entries) => entries).toList(growable: false);
    final plugins = await Future.wait(
      entries.map((entry) async {
        final repositoryUrl = entry.repositoryUrl;
        final folder = entry.folder;
        final manifestUri = repositoryUrl.resolve('$folder/manifest.json');
        final response = await _dio.getUri<Object?>(manifestUri);
        final raw = response.data is String
            ? jsonDecode(response.data! as String)
            : response.data;
        if (raw is! Map) {
          throw FormatException('Invalid plugin manifest: $manifestUri');
        }
        return _parse(repositoryUrl, folder, raw.cast<String, Object?>());
      }),
    );
    plugins.sort((a, b) => a.name.compareTo(b.name));
    return List.unmodifiable(plugins);
  }

  Future<Uint8List?> loadIcon(StorePlugin plugin) async {
    try {
      return await _getBytes(plugin.iconUrl);
    } on DioException {
      return null;
    }
  }

  Future<Uint8List> download(StorePlugin plugin) async {
    final files = <String>{
      'manifest.json',
      plugin.entry,
      plugin.icon,
      ...plugin.additionalFiles,
    };
    final archive = Archive();
    for (final path in files) {
      final bytes = await _getBytes(plugin.fileUrl(path));
      archive.addFile(ArchiveFile(path, bytes.length, bytes));
    }
    return Uint8List.fromList(ZipEncoder().encode(archive));
  }

  StorePlugin _parse(
    Uri repositoryUrl,
    String folder,
    Map<String, Object?> json,
  ) {
    String requiredString(String key) {
      final value = json[key]?.toString().trim() ?? '';
      if (value.isEmpty) throw FormatException('Plugin $key is missing');
      return value;
    }

    List<String> strings(String key) =>
        (json[key] as List?)?.map((value) => value.toString()).toList() ??
        const [];

    return StorePlugin(
      repositoryUrl: repositoryUrl,
      folder: folder,
      name: requiredString('name'),
      icon: requiredString('icon'),
      version: requiredString('version'),
      description: json['description']?.toString() ?? '',
      author: json['author']?.toString() ?? '',
      website: json['website']?.toString() ?? '',
      entry: requiredString('entry'),
      apiLevel: (json['api_level'] as num?)?.toInt() ?? 0,
      permissions: strings('permissions'),
      additionalFiles: strings('additional_files'),
    );
  }

  Future<String> _getText(Uri uri) async {
    final response = await _dio.getUri<String>(
      uri,
      options: Options(responseType: ResponseType.plain),
    );
    return response.data ?? '';
  }

  Future<Uint8List> _getBytes(Uri uri) async {
    final response = await _dio.getUri<List<int>>(
      uri,
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(response.data ?? const []);
  }

  List<String> _lines(String value) => value
      .split(RegExp(r'\r?\n'))
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty && !line.startsWith('#'))
      .toList(growable: false);

  Uri _directoryUri(String value) {
    final uri = Uri.parse(value);
    return uri.path.endsWith('/') ? uri : uri.replace(path: '${uri.path}/');
  }
}
