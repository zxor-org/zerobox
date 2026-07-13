import 'dart:convert';

const zeroBoxProtocolVersion = 2;

const zeroBoxDaemonCapabilities = <String>[
  'device',
  'install',
  'resources',
  'apps',
  'watchfaces',
  'accounts',
  'settings',
  'tasks',
  'logs',
];

class ZeroBoxCommand {
  const ZeroBoxCommand({required this.method, this.params = const {}});

  final String method;
  final Map<String, Object?> params;

  Map<String, Object?> toJson() => {'method': method, 'params': params};

  factory ZeroBoxCommand.fromJson(Map<String, Object?> json) {
    return ZeroBoxCommand(
      method: json['method']?.toString() ?? '',
      params: (json['params'] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }
}

class CommandResult {
  const CommandResult.success([this.value]) : error = null;
  const CommandResult.failure(this.error) : value = null;

  final Object? value;
  final CommandError? error;
  bool get ok => error == null;

  Map<String, Object?> toJson() => {
    'ok': ok,
    'result': value,
    'error': error?.toJson(),
  };

  factory CommandResult.fromJson(Map<String, Object?> json) {
    final rawError = json['error'];
    return rawError is Map
        ? CommandResult.failure(
            CommandError.fromJson(rawError.cast<String, Object?>()),
          )
        : CommandResult.success(json['result']);
  }
}

class CommandError {
  const CommandError(this.code, this.message, {this.details});
  final String code;
  final String message;
  final Object? details;

  Map<String, Object?> toJson() => {
    'code': code,
    'message': message,
    if (details != null) 'details': details,
  };

  factory CommandError.fromJson(Map<String, Object?> json) => CommandError(
    json['code']?.toString() ?? 'unknown',
    json['message']?.toString() ?? 'Unknown error',
    details: json['details'],
  );
}

class CommandEvent {
  const CommandEvent(this.event, {this.data = const {}});
  final String event;
  final Map<String, Object?> data;

  Map<String, Object?> toJson() => {'event': event, ...data};
  String encode() => jsonEncode(toJson());
}

abstract interface class ZeroBoxCommandBus {
  Future<CommandResult> execute(ZeroBoxCommand command);
  Stream<CommandEvent> get events;
  Future<void> close();
}
