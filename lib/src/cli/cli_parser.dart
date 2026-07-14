import 'cli_models.dart';

const _commandsWithSubcommands = {
  'daemon',
  'device',
  'resource',
  'app',
  'watchface',
  'queue',
  'account',
  'settings',
  'logs',
  'plugin',
};

const _booleanOptions = {
  'no-autostart',
  'password-stdin',
  'detach',
  'wait',
  'free',
  'hide-paid',
  'hide-force-paid',
  'help',
  'version',
};

CliInvocation parseCliInvocation(List<String> rawArgs) {
  var noGui = false;
  var json = false;
  var quiet = false;
  final options = <String, String?>{};
  final positional = <String>[];

  for (var index = 0; index < rawArgs.length; index++) {
    final token = rawArgs[index];
    if (token == '--nogui') {
      noGui = true;
    } else if (token == '--json') {
      json = true;
    } else if (token == '--quiet') {
      quiet = true;
    } else if (token == '-h') {
      options['help'] = null;
    } else if (token.startsWith('--')) {
      final separator = token.indexOf('=');
      if (separator > 2) {
        options[token.substring(2, separator)] = token.substring(separator + 1);
      } else {
        final name = token.substring(2);
        final hasValue =
            !_booleanOptions.contains(name) &&
            index + 1 < rawArgs.length &&
            !rawArgs[index + 1].startsWith('-');
        options[name] = hasValue ? rawArgs[++index] : null;
      }
    } else {
      positional.add(token);
    }
  }

  if (!noGui) {
    return CliInvocation(noGui: false, command: const [], arguments: rawArgs);
  }
  if (positional.isEmpty) {
    if (options.containsKey('help')) {
      return CliInvocation(
        noGui: true,
        command: const ['help'],
        options: options,
        json: json,
        quiet: quiet,
      );
    }
    if (options.containsKey('version')) {
      return CliInvocation(
        noGui: true,
        command: const ['version'],
        options: options,
        json: json,
        quiet: quiet,
      );
    }
    throw const CliUsageException('Missing command after --nogui');
  }

  final command = <String>[positional.first.toLowerCase()];
  var consumed = 1;
  if (_commandsWithSubcommands.contains(command.first) &&
      positional.length > 1) {
    command.add(positional[1].toLowerCase());
    consumed = 2;
  } else if (command.first == 'install' && positional.length > 1) {
    command.add(positional[1].toLowerCase());
    consumed = 2;
  }

  return CliInvocation(
    noGui: true,
    command: command,
    arguments: positional.skip(consumed).toList(growable: false),
    options: options,
    json: json,
    quiet: quiet,
  );
}
