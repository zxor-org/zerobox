import 'package:flutter_test/flutter_test.dart';
import 'package:zerobox/src/daemon/daemon_endpoint.dart';

void main() {
  test('uses the writable macOS sandbox container data directory', () {
    expect(
      resolveDaemonRuntimeDirectory(
        operatingSystem: 'macos',
        environment: const {'HOME': '/Users/orpudding'},
        systemTemporaryDirectory:
            '/Users/orpudding/Library/Containers/org.zxor.zerobox/Data/tmp',
      ),
      '/Users/orpudding/Library/Containers/org.zxor.zerobox/Data/Library/'
      'Application Support/ZeroBox/run',
    );
  });

  test('uses Application Support for an unsandboxed macOS process', () {
    expect(
      resolveDaemonRuntimeDirectory(
        operatingSystem: 'macos',
        environment: const {'HOME': '/Users/orpudding'},
        systemTemporaryDirectory: '/var/folders/example/T',
      ),
      '/Users/orpudding/Library/Application Support/ZeroBox/run',
    );
  });

  test('uses the Windows local application-data directory', () {
    expect(
      resolveDaemonRuntimeDirectory(
        operatingSystem: 'windows',
        environment: const {
          'LOCALAPPDATA': r'C:\Users\orpudding\AppData\Local',
        },
        systemTemporaryDirectory: r'C:\Temp',
      ),
      r'C:\Users\orpudding\AppData\Local\ZeroBox\run',
    );
  });

  test('validates Windows daemon discovery metadata', () {
    final endpoint = WindowsDaemonEndpoint.fromJson(const {
      'port': 51234,
      'token': 'secret',
      'pid': 42,
      'protocolVersion': 1,
    });
    expect(endpoint.port, 51234);
    expect(endpoint.token, 'secret');
    expect(endpoint.pid, 42);
    expect(endpoint.toJson()['protocolVersion'], 1);
    expect(
      () => WindowsDaemonEndpoint.fromJson(const {'port': 0, 'token': ''}),
      throwsFormatException,
    );
  });
}
