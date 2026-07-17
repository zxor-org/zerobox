enum ZeroBoxWindowRole { main, debug, plugin }

class WindowLaunchSpec {
  const WindowLaunchSpec({
    this.role = ZeroBoxWindowRole.main,
    this.targetId,
    this.controlPort,
    this.controlToken,
  });

  final ZeroBoxWindowRole role;
  final String? targetId;
  final int? controlPort;
  final String? controlToken;

  bool get isSecondary => role != ZeroBoxWindowRole.main;
  String get storageKey => switch (role) {
    ZeroBoxWindowRole.plugin when targetId != null => 'plugin.$targetId',
    _ => role.name,
  };

  static WindowLaunchSpec parse(List<String> arguments) {
    final index = arguments.indexOf('--window');
    if (index < 0 || index + 1 >= arguments.length) {
      return const WindowLaunchSpec();
    }
    return switch (arguments[index + 1]) {
      'debug' => WindowLaunchSpec(
        role: ZeroBoxWindowRole.debug,
        controlPort: int.tryParse(_option(arguments, '--window-port') ?? ''),
        controlToken: _option(arguments, '--window-token'),
      ),
      'plugin' => WindowLaunchSpec(
        role: ZeroBoxWindowRole.plugin,
        targetId: _option(arguments, '--plugin-id'),
        controlPort: int.tryParse(_option(arguments, '--window-port') ?? ''),
        controlToken: _option(arguments, '--window-token'),
      ),
      _ => const WindowLaunchSpec(),
    };
  }

  static String? _option(List<String> arguments, String name) {
    final index = arguments.indexOf(name);
    return index >= 0 && index + 1 < arguments.length
        ? arguments[index + 1]
        : null;
  }
}
