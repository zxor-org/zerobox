import 'package:flutter/material.dart';
import 'package:zerobox/src/core/utils/layout.dart';

class ResponsiveGrid extends StatelessWidget {
  const ResponsiveGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.childAspectRatio = 0.75,
    this.mainAxisExtent,
    this.padding,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double childAspectRatio;
  final double? mainAxisExtent;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossCount = _resolveCrossAxisCount(width);

    return GridView.builder(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: mainAxisExtent == null ? childAspectRatio : 1,
        mainAxisExtent: mainAxisExtent,
      ),
      itemCount: itemCount,
      itemBuilder: (context, index) => itemBuilder(context, index),
    );
  }

  int _resolveCrossAxisCount(double width) {
    if (width >= LayoutBreakpoint.expanded) return 6;
    if (width >= LayoutBreakpoint.medium) return 4;
    if (width >= LayoutBreakpoint.compact) return 3;
    return 2;
  }
}
