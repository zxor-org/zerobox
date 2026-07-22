import 'dart:ffi';
import 'dart:io';

String pluginHostPlatform() => Platform.operatingSystem;

String pluginHostArchitecture() {
  final abi = Abi.current().toString().toLowerCase();
  if (abi.contains('arm64')) return 'arm64';
  if (abi.contains('x64')) return 'x64';
  if (abi.contains('ia32')) return 'x86';
  if (abi.contains('riscv64')) return 'riscv64';
  if (abi.contains('arm')) return 'arm';
  return abi;
}

String pluginHostVersion() => Platform.operatingSystemVersion;

String pluginHostHostname() => Platform.localHostname;

String pluginHostLocale() => Platform.localeName;
