import 'dart:io';

abstract final class BuildInfoService {
  static const appVersion = String.fromEnvironment(
    'APP_VERSION',
    defaultValue: '1.0.0+1',
  );

  static const buildUser = String.fromEnvironment(
    'BUILD_USER',
    defaultValue: 'local',
  );

  static const _definedCommit = String.fromEnvironment(
    'GIT_COMMIT_HASH',
    defaultValue: 'local',
  );

  static Future<String> resolveCommitHash() async {
    if (_definedCommit != 'local' && _definedCommit.isNotEmpty) {
      return _definedCommit;
    }

    try {
      final result = await Process.run(
        'git',
        ['rev-parse', '--short', 'HEAD'],
        workingDirectory: Directory.current.path,
      ).timeout(const Duration(milliseconds: 800));
      if (result.exitCode == 0) {
        final hash = result.stdout.toString().trim();
        if (hash.isNotEmpty) return hash;
      }
    } catch (_) {
      // Packaged builds do not necessarily run inside a Git checkout.
    }

    return _definedCommit;
  }
}
