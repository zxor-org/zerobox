import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';
import 'package:zerobox/src/core/logging/file_log_sink.dart';

export 'package:logging/logging.dart';

Logger getLogger(String name) => Logger('zerobox.$name');

final _diagnostics = StreamController<DiagnosticEvent>.broadcast();
final _recentDiagnostics = <DiagnosticEvent>[];
DiagnosticProcess diagnosticProcess = DiagnosticProcess.frontend;
Stream<DiagnosticEvent> get zeroBoxDiagnosticStream => _diagnostics.stream;
List<DiagnosticEvent> get recentZeroBoxDiagnostics =>
    List.unmodifiable(_recentDiagnostics);
Stream<String> get zeroBoxLogStream =>
    zeroBoxDiagnosticStream.map((event) => event.format());
List<String> get recentZeroBoxLogs =>
    recentZeroBoxDiagnostics.map((event) => event.format()).toList();

void publishDiagnostic(DiagnosticEvent event) {
  _recentDiagnostics.add(event);
  if (_recentDiagnostics.length > 1000) _recentDiagnostics.removeAt(0);
  _diagnostics.add(event);
  if (event.level < Level.INFO) return;
  final line = event.format();
  writeFileLogLine(line);
  // ignore: avoid_print
  print(line);
}

void logPluginDiagnostic({
  required String pluginId,
  required String runtime,
  required Level level,
  required String message,
  Object? error,
  StackTrace? stackTrace,
  Map<String, Object?> fields = const {},
}) => publishDiagnostic(
  DiagnosticEvent(
    time: DateTime.now(),
    level: level,
    source: 'Plugin.$pluginId',
    process: DiagnosticProcess.backend,
    pluginId: pluginId,
    runtime: runtime,
    message: message,
    error: error,
    stackTrace: stackTrace,
    fields: fields,
  ),
);

Future<void> initLogging({
  List<String> arguments = const [],
  DiagnosticProcess process = DiagnosticProcess.frontend,
}) async {
  diagnosticProcess = process;
  await initializeFileLogSink(arguments: arguments);
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    publishDiagnostic(
      DiagnosticEvent(
        time: record.time,
        level: record.level,
        source: record.loggerName,
        process: diagnosticProcess,
        message: record.message.toString(),
        error: record.error,
        stackTrace: record.stackTrace,
      ),
    );
  });
}
