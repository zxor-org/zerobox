Future<void> initializeFileLogSink({List<String> arguments = const []}) async {}
void writeFileLogLine(String line) {}
Future<void> closeFileLogSink() async {}
Future<bool> openLogDirectory() async => false;
Future<String?> getLogDirectoryPath() async => null;
