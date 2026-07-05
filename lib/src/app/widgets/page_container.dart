import 'package:flutter/material.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';

class PageContainer extends StatelessWidget {
  const PageContainer({
    super.key,
    required this.child,
    this.maxWidth = StyleConstants.pageMaxWidth,
    this.padding = const EdgeInsets.symmetric(
      horizontal: StyleConstants.pagePadding,
      vertical: StyleConstants.pagePadding,
    ),
    this.center = true,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;
  final bool center;

  @override
  Widget build(BuildContext context) {
    final body = Padding(padding: padding, child: child);
    if (!center) return body;
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: body,
      ),
    );
  }
}

class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(StyleConstants.pagePadding),
    this.margin = const EdgeInsets.only(bottom: StyleConstants.sectionSpacing),
    this.borderRadius = const BorderRadius.all(
      Radius.circular(StyleConstants.cardRadius),
    ),
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius borderRadius;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: margin,
      color: color ?? Theme.of(context).colorScheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: padding, child: child),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}
