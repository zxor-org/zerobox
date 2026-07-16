import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';

void main() {
  group('PluginPackageReader', () {
    test('reads native JavaScript ZBP', () {
      final package = const PluginPackageReader().read(
        _package(runtime: 'js', entry: 'main.js'),
        fileName: 'example.zbp',
      );

      expect(package.manifest.id, 'org.example.plugin');
      expect(package.manifest.runtime, PluginRuntimeType.js);
      expect(utf8.decode(package.files['main.js']!), 'export {}');
    });

    test('reads native hybrid and WASM manifests', () {
      final hybrid = const PluginPackageReader().read(
        _package(runtime: 'hybrid', entry: 'main.mjs'),
        fileName: 'hybrid.zbp',
      );
      final wasm = const PluginPackageReader().read(
        _package(runtime: 'wasm', entry: 'main.wasm'),
        fileName: 'wasm.zbp',
      );

      expect(hybrid.manifest.runtime, PluginRuntimeType.hybrid);
      expect(wasm.manifest.runtime, PluginRuntimeType.wasm);
    });

    test('routes manifests without runtime to Legacy', () {
      final package = const PluginPackageReader().read(
        _package(entry: 'main.js'),
        fileName: 'legacy.abp',
      );

      expect(package.manifest.runtime, PluginRuntimeType.legacy);
      expect(package.manifest.id, startsWith('example-plugin-'));
    });

    test('rejects Legacy manifests in ZBP packages', () {
      expect(
        () => const PluginPackageReader().read(
          _package(entry: 'main.js'),
          fileName: 'legacy.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects native manifests in ABP packages', () {
      expect(
        () => const PluginPackageReader().read(
          _package(runtime: 'js', entry: 'main.js'),
          fileName: 'native.abp',
        ),
        throwsFormatException,
      );
    });

    test('validates runtime entry type', () {
      expect(
        () => const PluginPackageReader().read(
          _package(runtime: 'wasm', entry: 'main.js'),
          fileName: 'invalid.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects unknown native permissions', () {
      expect(
        () => const PluginPackageReader().read(
          _package(
            runtime: 'js',
            entry: 'main.js',
            permissions: const ['filesystem'],
          ),
          fileName: 'invalid.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects a WASM entry without the WebAssembly magic header', () {
      expect(
        () => const PluginPackageReader().read(
          _package(
            runtime: 'wasm',
            entry: 'main.wasm',
            entryBytes: const [1, 2, 3, 4],
          ),
          fileName: 'invalid.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects archive entries that escape the package root', () {
      expect(
        () => const PluginPackageReader().read(
          _package(entry: 'main.js', archiveEntryName: '../main.js'),
          fileName: 'unsafe.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects a manifest whose runtime entry is missing', () {
      expect(
        () => const PluginPackageReader().read(
          _package(entry: 'main.js', includeEntry: false),
          fileName: 'missing.zbp',
        ),
        throwsFormatException,
      );
    });

    test('rejects duplicate manifest entries', () {
      expect(
        () => const PluginPackageReader().read(
          _package(entry: 'main.js', duplicateManifest: true),
          fileName: 'duplicate.zbp',
        ),
        throwsFormatException,
      );
    });
  });
}

Uint8List _package({
  String? runtime,
  required String entry,
  List<String> permissions = const [],
  List<int>? entryBytes,
  String? archiveEntryName,
  bool includeEntry = true,
  bool duplicateManifest = false,
}) {
  final manifest = <String, Object?>{
    'id': 'org.example.plugin',
    'name': 'Example Plugin',
    'version': '1.0.0',
    'author': 'ZeroBox',
    'description': 'Test plugin',
    'api_level': 1,
    if (runtime != null) 'runtime': runtime,
    'entry': entry,
    'permissions': permissions,
  };
  final content =
      entryBytes ??
      (entry.endsWith('.wasm')
          ? const <int>[0, 97, 115, 109, 1, 0, 0, 0]
          : utf8.encode('export {}'));
  final manifestBytes = utf8.encode(jsonEncode(manifest));
  final archive = Archive()
    ..addFile(ArchiveFile('manifest.json', 0, manifestBytes));
  if (duplicateManifest) {
    archive.addFile(ArchiveFile('manifest.json', 0, manifestBytes));
  }
  if (includeEntry) {
    archive.addFile(ArchiveFile(archiveEntryName ?? entry, 0, content));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
