import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';
import 'package:zerobox/src/app/window/window_launch_spec.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';

void main() {
  test('diagnostic records survive daemon transport', () {
    final record = DiagnosticEvent(
      time: DateTime.utc(2026, 7, 17),
      level: Level.WARNING,
      source: 'Plugin.reader',
      process: DiagnosticProcess.backend,
      pluginId: 'reader',
      runtime: 'js',
      message: 'failed to open file',
      fields: const {'operation': 'file.pick'},
    );

    final restored = DiagnosticEvent.fromJson(record.toJson());
    expect(restored.level, Level.WARNING);
    expect(restored.scope, 'plugin:reader');
    expect(restored.runtime, 'js');
    expect(restored.fields, {'operation': 'file.pick'});
  });

  test('window role parser isolates secondary window targets', () {
    final debug = WindowLaunchSpec.parse(const ['--window', 'debug']);
    final plugin = WindowLaunchSpec.parse(const [
      '--window',
      'plugin',
      '--plugin-id',
      'reader',
    ]);

    expect(debug.role, ZeroBoxWindowRole.debug);
    expect(plugin.role, ZeroBoxWindowRole.plugin);
    expect(plugin.targetId, 'reader');
  });
}
