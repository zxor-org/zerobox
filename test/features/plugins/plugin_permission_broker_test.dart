import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/features/plugins/application/plugin_permission_broker.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_permission.dart';

void main() {
  group('PluginPermissionBroker', () {
    test('rejects capabilities missing from the manifest', () async {
      final broker = _broker((_) async => PluginPermissionDecision.once);

      await expectLater(
        broker.authorize(_plugin(const []), _request()),
        throwsA(isA<PluginPermissionException>()),
      );
    });

    test('does not prompt for low-risk sandbox access', () async {
      var prompts = 0;
      final broker = _broker((_) async {
        prompts++;
        return PluginPermissionDecision.deny;
      });

      await broker.authorize(
        _plugin(const ['file']),
        _request(
          capability: 'file',
          operation: 'file.read',
          risk: PluginPermissionRisk.low,
        ),
      );

      expect(prompts, 0);
    });

    test('once grants only the current operation', () async {
      var prompts = 0;
      final broker = _broker((_) async {
        prompts++;
        return PluginPermissionDecision.once;
      });
      final plugin = _plugin(const ['device']);

      await broker.authorize(plugin, _request());
      await broker.authorize(plugin, _request());

      expect(prompts, 2);
    });

    test('session grant lasts until the runtime session ends', () async {
      var prompts = 0;
      final broker = _broker((_) async {
        prompts++;
        return PluginPermissionDecision.session;
      });
      final plugin = _plugin(const ['device']);

      await broker.authorize(plugin, _request());
      await broker.authorize(plugin, _request());
      broker.endSession(plugin.manifest.id);
      await broker.authorize(plugin, _request());

      expect(prompts, 2);
    });

    test('always grant is persisted', () async {
      final grants = <String>{};
      var prompts = 0;
      final broker = PluginPermissionBroker(
        prompt: (_) async {
          prompts++;
          return PluginPermissionDecision.always;
        },
        readPersistentGrants: (_) async => Set<String>.of(grants),
        writePersistentGrants: (_, values) async {
          final copy = Set<String>.of(values);
          grants
            ..clear()
            ..addAll(copy);
        },
      );
      final plugin = _plugin(const ['device']);

      await broker.authorize(plugin, _request());
      broker.endSession(plugin.manifest.id);
      await broker.authorize(plugin, _request());

      expect(prompts, 1);
      expect(grants, contains(_request().grantKey));
    });

    test('coalesces concurrent identical prompts', () async {
      final decision = Completer<PluginPermissionDecision>();
      var prompts = 0;
      final broker = _broker((_) {
        prompts++;
        return decision.future;
      });
      final plugin = _plugin(const ['device']);

      final first = broker.authorize(plugin, _request());
      final second = broker.authorize(plugin, _request());
      await Future<void>.delayed(Duration.zero);
      decision.complete(PluginPermissionDecision.once);
      await Future.wait([first, second]);

      expect(prompts, 1);
    });
  });
}

PluginPermissionBroker _broker(PluginPermissionPrompt prompt) {
  return PluginPermissionBroker(
    prompt: prompt,
    readPersistentGrants: (_) async => <String>{},
    writePersistentGrants: (_, _) async {},
  );
}

InstalledPlugin _plugin(List<String> permissions) => InstalledPlugin(
  manifest: PluginManifest(
    id: 'org.example.plugin',
    name: 'Example',
    version: '1.0.0',
    author: 'ZeroBox',
    description: '',
    apiLevel: 1,
    runtime: PluginRuntimeType.js,
    entry: 'main.js',
    permissions: permissions,
  ),
  entryBytes: Uint8List(0),
  config: const {},
);

PluginPermissionRequest _request({
  String capability = 'device',
  String operation = 'device.connect',
  PluginPermissionRisk risk = PluginPermissionRisk.high,
}) => PluginPermissionRequest(
  pluginId: 'org.example.plugin',
  pluginName: 'Example',
  capability: capability,
  operation: operation,
  risk: risk,
  description: 'connect to a device',
  resource: 'watch',
);
