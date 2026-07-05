import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

ThemeData oledDarkTheme(ThemeData defaultDarkTheme) {
  return defaultDarkTheme.copyWith(
    scaffoldBackgroundColor: Colors.black,
    colorScheme: defaultDarkTheme.colorScheme.copyWith(
      onPrimary: Colors.black,
      onSecondary: Colors.black,
      surface: Colors.black,
      onSurface: Colors.white,
    ),
  );
}

abstract final class AppTheme {
  static final ThemeData light = buildLightTheme();
  static final ThemeData dark = buildDarkTheme();
  static final ThemeData oledDark = oledDarkTheme(dark);

  static const pageTransitionsTheme = PageTransitionsTheme(
    builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
    },
  );

  static ThemeData buildLightTheme({ColorScheme? colorScheme}) {
    return _buildTheme(Brightness.light, colorScheme: colorScheme);
  }

  static ThemeData buildDarkTheme({ColorScheme? colorScheme}) {
    return _buildTheme(Brightness.dark, colorScheme: colorScheme);
  }

  static ThemeData buildOledDarkTheme({ColorScheme? colorScheme}) {
    return oledDarkTheme(buildDarkTheme(colorScheme: colorScheme));
  }

  static ThemeData _buildTheme(
    Brightness brightness, {
    ColorScheme? colorScheme,
  }) {
    final effectiveColorScheme =
        colorScheme ??
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF6750A4),
          brightness: brightness,
        );

    return ThemeData(
      useMaterial3: true,
      colorScheme: effectiveColorScheme,
      brightness: brightness,
      pageTransitionsTheme: pageTransitionsTheme,
      scaffoldBackgroundColor: effectiveColorScheme.surface,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        scrolledUnderElevation: 0,
        backgroundColor: effectiveColorScheme.surface,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarDividerColor: Colors.transparent,
          statusBarIconBrightness: brightness == Brightness.dark
              ? Brightness.light
              : Brightness.dark,
          statusBarBrightness: brightness,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: effectiveColorScheme.surfaceContainerLow,
      ),
      chipTheme: ChipThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        side: BorderSide.none,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: effectiveColorScheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide(color: effectiveColorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        backgroundColor: effectiveColorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: effectiveColorScheme.surfaceContainer,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
        showDragHandle: true,
        backgroundColor: effectiveColorScheme.surface,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
