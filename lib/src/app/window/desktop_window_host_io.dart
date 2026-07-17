import 'dart:async';
import 'dart:io';
import 'dart:ui' show AppExitResponse;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/router/app_router.dart';
import 'package:zerobox/src/app/window/window_launcher.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

class DesktopWindowHost extends ConsumerStatefulWidget {
  const DesktopWindowHost({super.key, required this.child});
  final Widget child;

  @override
  ConsumerState<DesktopWindowHost> createState() => _DesktopWindowHostState();
}

class _DesktopWindowHostState extends ConsumerState<DesktopWindowHost>
    with WindowListener, TrayListener {
  static const _exitBehaviorKey = 'desktop.exit_behavior';
  bool _initialized = false;
  bool _showingDialog = false;
  bool _exiting = false;
  AppLifecycleListener? _lifecycleListener;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && _isDesktop) {
      _initialized = true;
      _initialize();
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isDesktop) {
      _lifecycleListener = AppLifecycleListener(
        onExitRequested: () async {
          unawaited(_exitApplication());
          return AppExitResponse.cancel;
        },
      );
    }
  }

  Future<void> _initialize() async {
    final l10n = AppLocalizations.of(context)!;
    windowManager.addListener(this);
    trayManager.addListener(this);
    await windowManager.setPreventClose(true);
    final icon = Platform.isWindows
        ? 'assets/images/tray_icon.ico'
        : 'assets/images/tray_icon.png';
    await trayManager.setIcon(icon);
    if (!Platform.isLinux) await trayManager.setToolTip('ZeroBox');
    await trayManager.setContextMenu(
      Menu(
        items: [
          MenuItem(key: 'show', label: l10n.desktopTrayShow),
          MenuItem.separator(),
          MenuItem(key: 'exit', label: l10n.desktopTrayExit),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _lifecycleListener?.dispose();
    if (_isDesktop) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
    }
    super.dispose();
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    if (await windowManager.isMinimized()) await windowManager.restore();
    await windowManager.focus();
  }

  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    if (menuItem.key == 'show') _showWindow();
    if (menuItem.key == 'exit') unawaited(_exitApplication());
  }

  Future<void> _exitApplication() async {
    if (_exiting) return;
    _exiting = true;
    final host = ref.read(applicationHostProvider);
    final forcedExit = Timer(const Duration(seconds: 8), () => exit(0));
    try {
      await windowManager.hide().timeout(const Duration(seconds: 1));
    } catch (_) {}
    try {
      await shutdownSecondaryWindows().timeout(const Duration(seconds: 5));
    } catch (_) {}
    try {
      await host
          .execute(const ZeroBoxCommand(method: 'daemon.stop'))
          .timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await host.close().timeout(const Duration(seconds: 2));
    } catch (_) {}
    try {
      await trayManager.destroy().timeout(const Duration(seconds: 1));
    } catch (_) {
    } finally {
      forcedExit.cancel();
      exit(0);
    }
  }

  @override
  void onWindowClose() {
    final behavior = SharedPrefsService.instance.getInt(_exitBehaviorKey);
    if (behavior == 0) {
      unawaited(_exitApplication());
    } else if (behavior == 1) {
      windowManager.hide();
    } else {
      _askCloseBehavior();
    }
  }

  Future<void> _askCloseBehavior() async {
    if (_showingDialog || !mounted) return;
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      await windowManager.hide();
      return;
    }
    _showingDialog = true;
    var remember = false;
    final l10n = AppLocalizations.of(navigatorContext)!;
    await showDialog<void>(
      context: navigatorContext,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(l10n.desktopCloseTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(l10n.desktopCloseMessage),
              const SizedBox(height: 24),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Checkbox(
                    value: remember,
                    onChanged: (value) =>
                        setState(() => remember = value ?? false),
                  ),
                  Text(l10n.desktopCloseRemember),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (remember) {
                  await SharedPrefsService.instance.setInt(_exitBehaviorKey, 0);
                }
                await _exitApplication();
              },
              child: Text(l10n.desktopCloseExit),
            ),
            TextButton(
              onPressed: () async {
                if (remember) {
                  await SharedPrefsService.instance.setInt(_exitBehaviorKey, 1);
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext);
                await windowManager.hide();
              },
              child: Text(l10n.desktopCloseToTray),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.settingsCancel),
            ),
          ],
        ),
      ),
    );
    _showingDialog = false;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
