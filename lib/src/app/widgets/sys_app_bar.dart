import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:window_manager/window_manager.dart';

class SysAppBar extends StatelessWidget implements PreferredSizeWidget {
  const SysAppBar({
    super.key,
    this.title,
    this.backgroundColor,
    this.elevation,
    this.actions,
    this.leading,
    this.bottom,
  });

  final Widget? title;
  final Color? backgroundColor;
  final double? elevation;
  final List<Widget>? actions;
  final Widget? leading;
  final PreferredSizeWidget? bottom;

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
    final resolvedLeading = macOS
        ? Row(
            children: [
              const SizedBox(width: 72),
              SizedBox(
                width: 48,
                child:
                    leading ??
                    (Navigator.canPop(context) ? const BackButton() : null),
              ),
            ],
          )
        : leading;
    final appBar = AppBar(
      title: title,
      leading: resolvedLeading,
      leadingWidth: macOS ? 120 : null,
      automaticallyImplyLeading: !macOS,
      actions: [
        ...?actions,
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
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
