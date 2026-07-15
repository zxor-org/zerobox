import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:zerobox/src/app/router/app_router.dart';
import 'package:zerobox/src/app/window/desktop_window_host.dart';
import 'package:zerobox/src/app/theme/app_theme.dart';
import 'package:zerobox/src/app/theme/system_accent_color.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/core/providers/theme_locale_providers.dart';
import 'package:zerobox/src/features/devices/widgets/device_deep_link_handler.dart';
import 'package:zerobox/src/features/plugins/widgets/plugin_host_request_handler.dart';

final _desktopAccentColorProvider = FutureProvider<Color?>((ref) {
  final source = ref.watch(
    themeSettingsProvider.select((settings) {
      return settings.desktopAccentColorSource;
    }),
  );
  return loadDesktopAccentColor(source);
});

class ZeroBoxApp extends ConsumerWidget {
  const ZeroBoxApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final themeSettings = ref.watch(themeSettingsProvider);
    final localeSettings = ref.watch(localeSettingsProvider);
    final desktopAccentColor = ref
        .watch(_desktopAccentColorProvider)
        .maybeWhen(data: (color) => color, orElse: () => null);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamicColor = themeSettings.useDynamicColor;
        final lightColorScheme = useDynamicColor
            ? lightDynamic ??
                  _desktopColorScheme(desktopAccentColor, Brightness.light)
            : _seedColorScheme(themeSettings.customSeedColor, Brightness.light);
        final darkColorScheme = useDynamicColor
            ? darkDynamic ??
                  _desktopColorScheme(desktopAccentColor, Brightness.dark)
            : _seedColorScheme(themeSettings.customSeedColor, Brightness.dark);

        return MaterialApp.router(
          title: 'ZeroBox',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildLightTheme(colorScheme: lightColorScheme),
          darkTheme: themeSettings.isOledDark
              ? AppTheme.buildOledDarkTheme(colorScheme: darkColorScheme)
              : AppTheme.buildDarkTheme(colorScheme: darkColorScheme),
          themeMode: themeSettings.materialThemeMode,
          locale: localeSettings.materialLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => DesktopWindowHost(
            child: PluginHostRequestHandler(
              child: DeviceDeepLinkHandler(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }

  ColorScheme? _desktopColorScheme(Color? accentColor, Brightness brightness) {
    if (accentColor == null) {
      return null;
    }
    return _seedColorScheme(accentColor, brightness);
  }

  ColorScheme _seedColorScheme(Color seedColor, Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}
