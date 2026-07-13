class DaemonTaskView {
  const DaemonTaskView({
    required this.id,
    required this.method,
    required this.status,
    required this.progress,
    required this.createdAt,
    this.params = const {},
    this.path,
    this.error,
  });

  final String id;
  final String method;
  final String status;
  final double progress;
  final DateTime createdAt;
  final Map<String, Object?> params;
  final String? path;
  final String? error;

  bool get isTerminal =>
      status == 'completed' || status == 'failed' || status == 'cancelled';

  factory DaemonTaskView.fromJson(Map<String, Object?> json) {
    final command = (json['command'] as Map?)?.cast<String, Object?>();
    final params = (command?['params'] as Map?)?.cast<String, Object?>();
    final result = (json['result'] as Map?)?.cast<String, Object?>();
    final error = (result?['error'] as Map?)?.cast<String, Object?>();
    return DaemonTaskView(
      id: json['id']?.toString() ?? '',
      method: command?['method']?.toString() ?? 'unknown',
      status: json['status']?.toString() ?? 'unknown',
      progress: (json['progress'] as num?)?.toDouble() ?? 0,
      createdAt:
          DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      params: params ?? const {},
      path: params?['path']?.toString(),
      error: error?['message']?.toString(),
    );
  }
}
