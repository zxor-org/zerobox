import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';

void main() {
  group('PluginStoragePath', () {
    test('maps each virtual root to an isolated storage area', () {
      expect(
        PluginStoragePath.parse('/plugin/main.js').area,
        PluginStorageArea.package,
      );
      expect(
        PluginStoragePath.parse('/data/settings.json').area,
        PluginStorageArea.data,
      );
      expect(
        PluginStoragePath.parse('/cache/image.png').area,
        PluginStorageArea.cache,
      );
      expect(
        PluginStoragePath.parse('/temp/download.bin').area,
        PluginStorageArea.temporary,
      );
    });

    test('rejects paths that can escape or hide inside storage metadata', () {
      for (final path in [
        'data/file',
        '/data/../secret',
        '/data/./secret',
        '/data//secret',
        r'/data\secret',
        '/data/secret\u0000suffix',
        '/data/.zerobox',
        '/data/.zerobox-secret',
        '/unknown/file',
      ]) {
        expect(
          () => PluginStoragePath.parse(path),
          throwsFormatException,
          reason: path,
        );
      }
    });

    test('round-trips storage roots and nested paths', () {
      for (final path in [
        '/plugin',
        '/data',
        '/cache/nested/image.png',
        '/temp/session/output.bin',
      ]) {
        expect(PluginStoragePath.parse(path).virtualPath, path);
      }
    });
  });
}
