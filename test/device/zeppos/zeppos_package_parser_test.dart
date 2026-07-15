import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/device/zeppos/install/zeppos_package_parser.dart';

void main() {
  const parser = ZeppOsPackageParser();

  test('parses a direct Zepp OS app package', () {
    final bytes = _zip({
      'app.json': utf8.encode(
        jsonEncode({
          'app': {
            'appId': 42,
            'appName': 'Test App',
            'appType': 'app',
            'version': {'name': '1.2.3'},
          },
        }),
      ),
      'assets/index.js': utf8.encode('console.log("ok")'),
    });

    final package = parser.parse(bytes);
    expect(package.type, ZeppOsPackageType.app);
    expect(package.appId, 42);
    expect(package.name, 'Test App');
    expect(package.version, '1.2.3');
    expect(package.firmwareType, 0x08);
    expect(package.bytes, bytes);
  });

  test('extracts device.zip from a zpk', () {
    final deviceZip = _appZip('Nested App');
    final zpk = _zip({
      'device.zip': deviceZip,
      'app-side.zip': _zip({
        'app-side.js': utf8.encode('AppSideService({onInit(){}})'),
      }),
    });

    final package = parser.parse(zpk);
    expect(package.type, ZeppOsPackageType.app);
    expect(package.name, 'Nested App');
    expect(package.bytes, deviceZip);
    expect(utf8.decode(package.appSideJs!), contains('AppSideService'));
  });

  test('ignores manifests and selects app-side.js by basename', () {
    final zpk = _zip({
      'device.zip': _appZip('Custom Side'),
      'app-side.zip': _zip({
        'app.json': utf8.encode(
          jsonEncode({
            'module': {
              'appSide': {'path': r'src\service.js'},
            },
          }),
        ),
        'src/service.js': utf8.encode('customAppSideEntry()'),
        'nested/app-side.js': utf8.encode('basenameEntry()'),
      }),
    });

    final package = parser.parse(zpk);
    expect(utf8.decode(package.appSideJs!), 'basenameEntry()');
  });

  test(
    'extracts setting without app-side and picks deterministic basename',
    () {
      final zpk = _zip({
        'device.zip': _appZip('Settings Only'),
        'app-side.zip': _zip({
          'deep/setting.js': utf8.encode('deepSetting()'),
          'a/setting.js': utf8.encode('preferredSetting()'),
          'b/setting.js': utf8.encode('otherSetting()'),
          'asset.png': [1, 2, 3],
        }),
      });

      final package = parser.parse(zpk);
      expect(package.appSideJs, isNull);
      expect(utf8.decode(package.settingJs!), 'preferredSetting()');
      expect(package.settingAssets['asset.png'], [1, 2, 3]);
    },
  );

  test('supports a bare top-level app-side.js in a zpk', () {
    final zpk = _zip({
      'device.zip': _appZip('Bare Side'),
      'app-side.js': utf8.encode('bareAppSideEntry()'),
    });

    final package = parser.parse(zpk);
    expect(utf8.decode(package.appSideJs!), 'bareAppSideEntry()');
  });

  test('does not adopt a traversing app-side manifest path', () {
    final zpk = _zip({
      'device.zip': _appZip('Safe Side'),
      'app-side.zip': _zip({
        'app.json': utf8.encode(
          jsonEncode({
            'module': {
              'appSide': {'path': '../outside.js'},
            },
          }),
        ),
        'app-side.js': utf8.encode('safeFallback()'),
      }),
    });

    final package = parser.parse(zpk);
    expect(utf8.decode(package.appSideJs!), 'safeFallback()');
  });

  test('rejects unsafe paths in app-side resources', () {
    final zpk = _zip({
      'device.zip': _appZip('Unsafe'),
      'app-side.zip': _zip({'../setting.js': utf8.encode('unsafe()')}),
    });

    expect(() => parser.parse(zpk), throwsFormatException);
  });

  test('selects a ZAB variant by deviceSource', () {
    final first = _zip({'device.zip': _appZip('Wrong')});
    final second = _zip({'device.zip': _appZip('Correct')});
    final zab = _zip({
      'manifest.json': utf8.encode(
        jsonEncode({
          'zpks': [
            {
              'name': 'old.zpk',
              'platforms': [
                {'deviceSource': 1},
              ],
            },
            {
              'name': 'target.zpk',
              'platforms': [
                {'deviceSource': 2},
              ],
            },
          ],
        }),
      ),
      'old.zpk': first,
      'target.zpk': second,
    });

    final package = parser.parse(zab, deviceSources: const {2});
    expect(package.name, 'Correct');
  });

  test('keeps firmware distinct from apps', () {
    final bytes = _zip({
      'META/firmware.bin': Uint8List.fromList([1, 2, 3]),
    });
    final package = parser.parse(bytes);
    expect(package.type, ZeppOsPackageType.firmware);
    expect(package.firmwareType, 0x00);
  });

  test('rejects an app package without a valid appId', () {
    final bytes = _zip({
      'app.json': utf8.encode(
        jsonEncode({
          'app': {
            'appId': 'not-an-id',
            'appName': 'Unsafe App',
            'appType': 'app',
            'version': {'name': '1.0.0'},
          },
        }),
      ),
    });

    expect(() => parser.parse(bytes), throwsFormatException);
  });
}

Uint8List _appZip(String name) => _zip({
  'app.json': utf8.encode(
    jsonEncode({
      'app': {
        'appId': 7,
        'appName': name,
        'appType': 'app',
        'version': {'name': '1.0.0'},
      },
    }),
  ),
});

Uint8List _zip(Map<String, List<int>> files) {
  final archive = Archive();
  for (final entry in files.entries) {
    archive.addFile(ArchiveFile(entry.key, entry.value.length, entry.value));
  }
  return Uint8List.fromList(ZipEncoder().encode(archive));
}
