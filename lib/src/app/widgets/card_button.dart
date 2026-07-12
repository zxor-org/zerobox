import 'package:flutter/material.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';

class CardButton extends StatelessWidget {
  const CardButton({
    super.key,
    this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.disabled = false,
    this.external = false,
  });

  final IconData? icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool disabled;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = disabled
        ? colorScheme.onSurface.withValues(alpha: 0.5)
        : colorScheme.onSurface;
    final muted = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.35)
        : colorScheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null)
                Padding(
                  padding: const EdgeInsets.only(right: 16),
                  child: Icon(icon, size: 24, color: muted),
                ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: foreground,
                        fontSize: 16,
                        height: 1.25,
                      ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: muted,
                          fontSize: 13,
                          height: 1.25,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                external ? Icons.open_in_new : Icons.chevron_right,
                size: 20,
                color: muted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CardButtonGroup extends StatelessWidget {
  const CardButtonGroup({
    super.key,
    required this.children,
    this.margin = const EdgeInsets.only(bottom: 16),
  });

  final List<CardButton> children;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      margin: margin,
      padding: EdgeInsets.zero,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: _divide(context, children),
      ),
    );
  }

  List<Widget> _divide(BuildContext context, List<CardButton> children) {
    if (children.length <= 1) return children;
    final result = <Widget>[children.first];
    final divider = Divider(
      height: 1,
      indent: 56,
      color: Theme.of(
        context,
      ).colorScheme.outlineVariant.withValues(alpha: 0.5),
    );
    for (var i = 1; i < children.length; i++) {
      result.add(divider);
      result.add(children[i]);
    }
    return result;
  }
}
