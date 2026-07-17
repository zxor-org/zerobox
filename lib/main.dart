import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/zerobox_app.dart';
import 'package:zerobox/src/app/window/desktop_window_bootstrap.dart';
import 'package:zerobox/src/app/window/debug_window_preference.dart';
import 'package:zerobox/src/app/window/window_launch_spec.dart';
import 'package:zerobox/src/app/window/window_launcher.dart';
import 'package:zerobox/src/cli/cli_entrypoint.dart';
import 'package:zerobox/src/core/logging/logging_service.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';
import 'package:zerobox/src/core/services/license_registry_service.dart';
import 'package:zerobox/src/core/services/bluetooth_permission_bootstrap.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/host/gui_host_overrides.dart';
import 'package:zerobox/src/features/devices/widgets/device_deep_link_handler.dart';
import 'package:zerobox/src/features/debug/pages/debug_window_app.dart';
import 'package:zerobox/src/features/plugins/pages/plugin_window_app.dart';

void main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  final window = WindowLaunchSpec.parse(args);
  final process = switch (window.role) {
    ZeroBoxWindowRole.debug => DiagnosticProcess.debugWindow,
    ZeroBoxWindowRole.plugin => DiagnosticProcess.pluginWindow,
    ZeroBoxWindowRole.main =>
      args.contains('--nogui')
          ? args.contains('daemon') && args.contains('run')
                ? DiagnosticProcess.backend
                : DiagnosticProcess.cli
          : DiagnosticProcess.frontend,
  };
  await initLogging(arguments: args, process: process);
  await SharedPrefsService.instance.init();
  await runCliIfRequested(args);
  if (!await initializeWindowCoordinator(window)) return;
  if (window.role == ZeroBoxWindowRole.main) {
    await requestBluetoothPermissionOnStartup();
  }
  await LicenseRegistryService.registerThirdPartyLicenses();
  await initializeDesktopWindow(spec: window);
  runApp(
    ProviderScope(
      overrides: [
        ...guiHostOverrides(),
        initialDeepLinksProvider.overrideWithValue(args),
      ],
      child: switch (window.role) {
        ZeroBoxWindowRole.debug => const DebugWindowApp(),
        ZeroBoxWindowRole.plugin => PluginWindowApp(
          pluginId: window.targetId ?? '',
        ),
        ZeroBoxWindowRole.main => const ZeroBoxApp(),
      },
    ),
  );
  if (window.isSecondary) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(notifySecondaryWindowReady());
    });
  }
  if (window.role == ZeroBoxWindowRole.main &&
      !args.contains('--nogui') &&
      supportsSecondaryWindows &&
      isDebugWindowEnabled()) {
    unawaited(() async {
      if (!await openDebugWindow()) {
        await setDebugWindowEnabled(false);
      }
    }());
  }
}
