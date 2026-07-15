import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage.dart';
import 'package:zerobox/src/features/plugins/storage/plugin_storage_io.dart';

void main() {
  test(
    'plugin data is isolated by plugin ID while package files stay read-only',
    () async {
      final root = await Directory.systemTemp.createTemp(
        'zerobox-storage-test-',
      );
      addTearDown(() => root.delete(recursive: true));
      final storage = await createIoPluginStorage(
        installedRoot: Directory('${root.path}/installed'),
        cacheRoot: Directory('${root.path}/cache'),
        temporaryRoot: Directory('${root.path}/temp'),
      );
      addTearDown(storage.close);
      final dataPath = PluginStoragePath.parse('/data/settings.json');

      await storage.writeFile(
        'org.example.first',
        dataPath,
        Uint8List.fromList([1, 2, 3]),
      );

      expect(await storage.readFile('org.example.first', dataPath), [1, 2, 3]);
      await expectLater(
        storage.readFile('org.example.second', dataPath),
        throwsStateError,
      );
      await expectLater(
        storage.writeFile(
          'org.example.first',
          PluginStoragePath.parse('/plugin/main.js'),
          Uint8List(0),
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('symbolic links cannot escape a plugin storage root', () async {
    final root = await Directory.systemTemp.createTemp('zerobox-storage-test-');
    addTearDown(() => root.delete(recursive: true));
    final storage = await createIoPluginStorage(
      installedRoot: Directory('${root.path}/installed'),
      cacheRoot: Directory('${root.path}/cache'),
      temporaryRoot: Directory('${root.path}/temp'),
    );
    addTearDown(storage.close);
    final dataRoot = PluginStoragePath.parse('/data');
    await storage.createDirectory('org.example.plugin', dataRoot);
    final outside = await Directory('${root.path}/outside').create();
    await File('${outside.path}/secret.txt').writeAsString('secret');
    await Link(
      '${storage.nativePath('org.example.plugin', dataRoot)}/escape',
    ).create(outside.path);
    final escaped = PluginStoragePath.parse('/data/escape/secret.txt');

    await expectLater(
      storage.readFile('org.example.plugin', escaped),
      throwsStateError,
    );
    await expectLater(
      storage.writeFile('org.example.plugin', escaped, Uint8List.fromList([1])),
      throwsStateError,
    );
  });
}
