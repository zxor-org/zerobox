import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';
import 'package:zerobox/src/core/utils/layout.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SysAppBar({
    super.key,
    this.title,
    this.backgroundColor,
    this.elevation,
    this.actions,
    this.leading,
    this.bottom,
    this.secondary = false,
  });

  final Widget? title;
  final Color? backgroundColor;
  final double? elevation;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;
  final bool secondary;

  @override
  Widget build(BuildContext context) {
    final desktop =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final customClose =
        desktop && defaultTargetPlatform != TargetPlatform.macOS;
    final macOS = desktop && defaultTargetPlatform == TargetPlatform.macOS;
    final compactMacOS =
        macOS && !useWideLayout(MediaQuery.sizeOf(context).width);
    final macOSSecondary = compactMacOS && secondary;
    final resolvedLeading = macOSSecondary
        ? Padding(
            padding: const EdgeInsets.only(left: 12, top: 20),
            child:
                leading ??
                (Navigator.canPop(context) ? const BackButton() : null),
          )
        : leading;
    final resolvedTitle = title;
    final resolvedActions = compactMacOS
        ? actions
              ?.map(
                (action) => Transform.translate(
                  offset: const Offset(0, -16),
                  child: action,
                ),
              )
              .toList(growable: false)
        : actions;
    final appBar = AppBar(
      title: resolvedTitle,
      leading: resolvedLeading,
      leadingWidth: macOSSecondary ? 68 : null,
      titleSpacing: macOSSecondary ? 16 : null,
      centerTitle: macOSSecondary ? false : null,
      toolbarHeight: compactMacOS ? 72 : null,
      automaticallyImplyLeading: !macOSSecondary,
      actions: [
        ...?resolvedActions,
        if (customClose) CloseButton(onPressed: () => windowManager.close()),
        if (desktop) const SizedBox(width: 4),
      ],
      bottom: bottom,
      backgroundColor: backgroundColor,
      elevation: elevation,
      scrolledUnderElevation: 0,
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            Theme.of(context).brightness == Brightness.light
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarDividerColor: Colors.transparent,
      ),
    );
    if (!desktop) return appBar;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => windowManager.startDragging(),
      child: appBar,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(
    (_usesCompactMacOSLayout ? 72 : kToolbarHeight) +
        (bottom?.preferredSize.height ?? 0),
  );

  bool get _usesCompactMacOSLayout {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.macOS) return false;
    final views = ui.PlatformDispatcher.instance.views;
    if (views.isEmpty) return false;
    final view = views.first;
    final logicalWidth = view.physicalSize.width / view.devicePixelRatio;
    return !useWideLayout(logicalWidth);
  }
}
