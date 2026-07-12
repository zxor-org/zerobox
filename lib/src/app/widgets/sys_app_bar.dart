import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    return AppBar(
      title: title,
      leading: leading,
      actions: actions,
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
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
