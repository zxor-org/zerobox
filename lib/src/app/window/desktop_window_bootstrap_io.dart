import 'dart:io';

import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobox/src/app/window/window_launch_spec.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';

Future<void> initializeDesktopWindow({
  WindowLaunchSpec spec = const WindowLaunchSpec(),
}) async {
  if (!Platform.isWindows && !Platform.isLinux && !Platform.isMacOS) return;
  await windowManager.ensureInitialized();
  final secondary = spec.isSecondary;
  final role = spec.storageKey;
  final prefs = SharedPrefsService.instance;
  final savedWidth = prefs.getDouble('window.$role.width');
  final savedHeight = prefs.getDouble('window.$role.height');
  final defaultSize = switch (spec.role) {
    ZeroBoxWindowRole.debug => const Size(1000, 650),
    ZeroBoxWindowRole.plugin => const Size(1100, 760),
    ZeroBoxWindowRole.main => const Size(1280, 720),
  };
  final minimumSize = switch (spec.role) {
    ZeroBoxWindowRole.debug => const Size(640, 520),
    _ => const Size(720, 520),
  };
  final options = WindowOptions(
    size: savedWidth != null && savedHeight != null
        ? Size(savedWidth, savedHeight)
        : defaultSize,
    minimumSize: minimumSize,
    center: true,
    title: switch (spec.role) {
      ZeroBoxWindowRole.debug => 'ZeroBox Debug',
      ZeroBoxWindowRole.plugin => 'ZeroBox Plugin',
      ZeroBoxWindowRole.main => 'ZeroBox',
    },
    titleBarStyle: secondary ? TitleBarStyle.normal : TitleBarStyle.hidden,
    windowButtonVisibility: secondary ? true : Platform.isMacOS,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    final x = prefs.getDouble('window.$role.x');
    final y = prefs.getDouble('window.$role.y');
    if (x != null && y != null) await windowManager.setPosition(Offset(x, y));
    if (spec.role == ZeroBoxWindowRole.debug) {
      await windowManager.setPreventClose(true);
    }
    await windowManager.show();
    await windowManager.focus();
  });
}
