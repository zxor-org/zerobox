enum CliExitCode {
  success(0),
  usage(2),
  file(3),
  noDevice(4),
  connection(5),
  validation(6),
  install(7),
  daemon(8),
  internal(70);

  const CliExitCode(this.code);
  final int code;
}

class CliInvocation {
  const CliInvocation({
    required this.noGui,
    required this.command,
    this.arguments = const [],
    this.options = const {},
    this.json = false,
    this.quiet = false,
  });

  final bool noGui;
  final List<String> command;
  final List<String> arguments;
  final Map<String, String?> options;
  final bool json;
  final bool quiet;

  String requiredArgument(String label) {
    if (arguments.isEmpty) throw CliUsageException('Missing $label');
    return arguments.first;
  }
}

class CliUsageException implements Exception {
  const CliUsageException(this.message);
  final String message;
  @override
  String toString() => message;
}
