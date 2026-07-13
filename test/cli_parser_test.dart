import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/cli/cli_models.dart';
import 'package:zerobox/src/cli/cli_parser.dart';
import 'package:zerobox/src/cli/resource_cli_command.dart';

void main() {
  test('GUI mode leaves arguments untouched', () {
    final result = parseCliInvocation(['zerobox://open?id=1']);
    expect(result.noGui, isFalse);
    expect(result.arguments, ['zerobox://open?id=1']);
  });

  test('parses explicit local install type and path', () {
    final result = parseCliInvocation([
      '--nogui',
      '--json',
      'install',
      'quickapp',
      '/tmp/demo.rpk',
      '--device',
      'AA:BB',
    ]);
    expect(result.command, ['install', 'quickapp']);
    expect(result.arguments, ['/tmp/demo.rpk']);
    expect(result.options['device'], 'AA:BB');
    expect(result.json, isTrue);
  });

  test('requires a command in no-GUI mode', () {
    expect(
      () => parseCliInvocation(['--nogui']),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('boolean options do not consume the command', () {
    final result = parseCliInvocation([
      '--nogui',
      '--no-autostart',
      'device',
      'status',
    ]);
    expect(result.command, ['device', 'status']);
    expect(result.options, containsPair('no-autostart', null));
  });

  test('supports global help and version in no-GUI mode', () {
    expect(parseCliInvocation(const ['--nogui', '--help']).command, const [
      'help',
    ]);
    expect(parseCliInvocation(const ['--nogui', '--version']).command, const [
      'version',
    ]);
    expect(
      parseCliInvocation(const ['--nogui', '--json', '--version']).json,
      isTrue,
    );
  });

  test('maps resource filters to the shared command protocol', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'search',
      '鸣潮',
      '--source',
      'bandbbs',
      '--sort',
      'name',
      '--filter',
      'watchface,free,bandbbs-category:81,bandbbs-category:95',
      '--page',
      '2',
      '--page-size',
      '50',
    ]);

    final command = buildResourceQueryCommand(invocation);

    expect(command.method, 'resource.search');
    expect(command.params, {
      'source': 'bandbbs',
      'type': 'watchface',
      'sort': 'name',
      'hidePaid': true,
      'hideForcePaid': true,
      'devices': ['bandbbs-category:81', 'bandbbs-category:95'],
      'page': '2',
      'pageSize': '50',
      'query': '鸣潮',
    });
  });

  test('rejects unsupported resource sort rules', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'list',
      '--sort',
      'downloads',
    ]);

    expect(
      () => buildResourceQueryCommand(invocation),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('maps paid filter chips and removes duplicate devices', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'list',
      '--filter',
      'hide-paid, hide-force-paid, o65m, n67, o65m',
    ]);

    expect(buildResourceQueryCommand(invocation).params, {
      'hidePaid': true,
      'hideForcePaid': true,
      'devices': ['o65m', 'n67'],
    });
  });

  test('rejects conflicting resource type chips', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'list',
      '--filter',
      'quickapp,watchface',
    ]);

    expect(
      () => buildResourceQueryCommand(invocation),
      throwsA(isA<CliUsageException>()),
    );
  });

  test('maps the GUI firmware type chip', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'list',
      '--filter',
      'firmware,o65m',
    ]);

    expect(buildResourceQueryCommand(invocation).params, {
      'type': 'firmware',
      'devices': ['o65m'],
    });
  });

  test('rejects unknown word-like resource filter chips', () {
    final invocation = parseCliInvocation([
      '--nogui',
      'resource',
      'list',
      '--filter',
      'watchface,fre',
    ]);

    expect(
      () => buildResourceQueryCommand(invocation),
      throwsA(isA<CliUsageException>()),
    );
  });
}
