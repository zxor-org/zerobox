import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobox/src/app/window/window_launcher.dart';

class SecondaryWindowHost extends StatefulWidget {
  const SecondaryWindowHost({
    super.key,
    required this.role,
    required this.child,
  });
  final String role;
  final Widget child;

  @override
  State<SecondaryWindowHost> createState() => _SecondaryWindowHostState();
}

class _SecondaryWindowHostState extends State<SecondaryWindowHost>
    with WindowListener {
  Timer? _saveTimer;

  bool get _desktop =>
      Platform.isLinux || Platform.isMacOS || Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (_desktop) windowManager.addListener(this);
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    if (_desktop) windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowResize() => _scheduleSave();

  @override
  void onWindowMove() => _scheduleSave();

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 250), _saveBounds);
  }

  Future<void> _saveBounds() async {
    final size = await windowManager.getSize();
    final position = await windowManager.getPosition();
    await reportSecondaryWindowBounds(
      role: widget.role,
      width: size.width,
      height: size.height,
      x: position.dx,
      y: position.dy,
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
