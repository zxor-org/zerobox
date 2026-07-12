abstract final class LayoutBreakpoint {
  static const double compact = 600;
  static const double medium = 840;
  static const double expanded = 1200;
  static const double maxContentWidth = 1000;
}

enum ScreenSize { compact, medium, expanded }

bool useWideLayout(double availableWidth) =>
    availableWidth >= LayoutBreakpoint.medium;

extension ScreenSizeExtension on ScreenSize {
  bool get isCompact => this == ScreenSize.compact;
  bool get isMedium => this == ScreenSize.medium;
  bool get isExpanded => this == ScreenSize.expanded;
}

ScreenSize resolveScreenSize(double width) {
  if (width >= LayoutBreakpoint.expanded) return ScreenSize.expanded;
  if (width >= LayoutBreakpoint.medium) return ScreenSize.medium;
  if (width >= LayoutBreakpoint.compact) return ScreenSize.medium;
  return ScreenSize.compact;
}

T responsiveValue<T>(
  double width, {
  required T compact,
  required T medium,
  required T expanded,
}) {
  if (width >= LayoutBreakpoint.expanded) return expanded;
  if (width >= LayoutBreakpoint.medium) return medium;
  if (width >= LayoutBreakpoint.compact) return medium;
  return compact;
}
