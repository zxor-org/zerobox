import 'dart:async';

import 'package:logging/logging.dart';
import 'package:zerobox/src/core/logging/file_log_sink.dart';

export 'package:logging/logging.dart';

Logger getLogger(String name) => Logger('zerobox.$name');

final _logLines = StreamController<String>.broadcast();
final _recentLogLines = <String>[];
Stream<String> get zeroBoxLogStream => _logLines.stream;
List<String> get recentZeroBoxLogs => List.unmodifiable(_recentLogLines);

Future<void> initLogging({List<String> arguments = const []}) async {
  await initializeFileLogSink(arguments: arguments);
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    final time = record.time.toIso8601String();
    final logger = record.loggerName;
    final level = record.level.name;
    final buffer = StringBuffer();
    buffer.write('[$time] $level $logger: ${record.message}');
    if (record.error != null) {
      buffer.write('\n  ERROR: ${record.error}');
    }
    if (record.stackTrace != null) {
      buffer.write('\n${record.stackTrace}');
    }
    final line = buffer.toString();
    _recentLogLines.add(line);
    if (_recentLogLines.length > 500) _recentLogLines.removeAt(0);
    _logLines.add(line);
    writeFileLogLine(line);
    // ignore: avoid_print
    print(line);
  });
}
