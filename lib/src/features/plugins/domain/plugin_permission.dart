enum PluginPermissionRisk { low, medium, high }

enum PluginPermissionDecision { once, session, always, deny }

class PluginPermissionRequest {
  const PluginPermissionRequest({
    required this.pluginId,
    required this.pluginName,
    required this.capability,
    required this.operation,
    required this.risk,
    required this.description,
    this.resource,
    this.scope,
  });

  final String pluginId;
  final String pluginName;
  final String capability;
  final String operation;
  final PluginPermissionRisk risk;
  final String description;
  final String? resource;
  final String? scope;

  String get grantKey => [
    capability,
    operation,
    if (scope != null && scope!.isNotEmpty) scope,
  ].join(':');

  Map<String, Object?> toJson() => {
    'pluginId': pluginId,
    'pluginName': pluginName,
    'capability': capability,
    'operation': operation,
    'risk': risk.name,
    'description': description,
    if (resource != null) 'resource': resource,
  };
}

class PluginPermissionException implements Exception {
  const PluginPermissionException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => 'PluginPermissionException($code, $message)';
}
