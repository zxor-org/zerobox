import 'package:card_settings_ui/card_settings_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/utils/error_localization.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/core/providers/app_settings_providers.dart';
import 'package:zerobox/src/core/providers/theme_locale_providers.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/features/resources/application/resource_catalog_providers.dart';
import 'package:zerobox/src/features/accounts/models/mi_account_models.dart';
import 'package:zerobox/src/features/accounts/services/bandbbs_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/huami_auth_service.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_service.dart';
import 'package:zerobox/src/features/accounts/services/mi_account_two_factor_resolver.dart';
import 'package:zerobox/src/features/devices/controllers/device_manager.dart';

final _desktopExitBehaviorProvider = Provider<int?>((ref) {
  return SharedPrefsService.instance.getInt('desktop.exit_behavior');
});

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _keyMiAccountRemember = 'mi_account.remember_credentials';
  static const _keyMiAccountUsername = 'mi_account.username';
  static const _keyMiAccountPassword = 'mi_account.password';
  static const _keyMiAccountUserId = 'mi_account.user_id';
  static const _keyHuamiAccountRemember = 'huami_account.remember_credentials';
  static const _keyHuamiAccountPassword = 'huami_account.password';
  static const _colorSchemes = <Color>[
    Color(0xFFE91E63),
    Color(0xFF6750A4),
    Color(0xFF006A6A),
    Color(0xFF006D3F),
    Color(0xFFB3261E),
    Color(0xFF755B00),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final showDesktopAccentSource =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.linux;
    final showWideNavigationPosition =
        MediaQuery.sizeOf(context).width >= LayoutBreakpoint.medium;
    final showDesktopWindowSettings =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.windows ||
            defaultTargetPlatform == TargetPlatform.linux ||
            defaultTargetPlatform == TargetPlatform.macOS);
    final themeSettings = ref.watch(themeSettingsProvider);

    return Scaffold(
      appBar: SysAppBar(title: Text(l10n.settingsTab)),
      body: SettingsList(
        maxWidth: StyleConstants.pageMaxWidth,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
          vertical: StyleConstants.pagePadding,
        ),
        sections: [
          _buildSection(
            context,
            title: l10n.settingsAccount,
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => _showMiAccountLogin(context, ref),
                leading: const _MiLogo(),
                title: Text(l10n.settingsMiAccount),
                description: Text(l10n.settingsMiAccountDesc),
              ),
              SettingsTile.navigation(
                onPressed: (_) => _showHuamiAccountLogin(context, ref),
                leading: const _AccountLeading(child: Icon(Icons.functions)),
                title: Text(l10n.settingsHuamiAccount),
                description: Consumer(
                  builder: (context, ref, _) {
                    final account = ref.watch(huamiAuthProvider);
                    if (account.isBusy) {
                      return Text(l10n.settingsHuamiAccountSigningIn);
                    }
                    if (account.isSignedIn) {
                      return Text(
                        account.username?.isNotEmpty == true
                            ? account.username!
                            : l10n.settingsConnected,
                      );
                    }
                    return Text(l10n.settingsHuamiAccountDesc);
                  },
                ),
                value: Consumer(
                  builder: (context, ref, _) {
                    final account = ref.watch(huamiAuthProvider);
                    if (account.isBusy) {
                      return const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Text(
                      account.isSignedIn
                          ? l10n.settingsConnected
                          : l10n.settingsTapToSignIn,
                    );
                  },
                ),
              ),
              SettingsTile.navigation(
                onPressed: (_) {
                  final account = ref.read(bandBbsAuthProvider);
                  if (account.isSignedIn) {
                    context.push('/settings/bandbbs');
                  } else if (!account.isBusy) {
                    _startBandBbsLogin(context, ref);
                  }
                },
                leading: _AccountBrandLogo(
                  asset: 'assets/images/brands/bandbbs.svg',
                  semanticsLabel: 'BandBBS',
                ),
                title: Text(l10n.settingsAccountBandBbsAccount),
                description: Consumer(
                  builder: (context, ref, _) {
                    final account = ref.watch(bandBbsAuthProvider);
                    if (account.isBusy) {
                      return Text(l10n.settingsAccountBandBbsSigningIn);
                    }
                    if (account.isSignedIn) {
                      final username = account.username?.trim() ?? '';
                      final userId = account.userId?.trim() ?? '';
                      if (username.isNotEmpty && userId.isNotEmpty) {
                        return Text('$username · $userId');
                      }
                      if (username.isNotEmpty) return Text(username);
                      if (userId.isNotEmpty) return Text(userId);
                      return Text(l10n.settingsConnected);
                    }
                    return Text(l10n.settingsAccountLoginBBSDesc);
                  },
                ),
                value: Consumer(
                  builder: (context, ref, _) {
                    final account = ref.watch(bandBbsAuthProvider);
                    if (account.isBusy) {
                      return const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    return Text(
                      account.isSignedIn
                          ? l10n.settingsConnected
                          : l10n.settingsTapToSignIn,
                    );
                  },
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsGeneral,
            tiles: [
              SettingsTile.navigation(
                onPressed: (context) => _showLanguageSelector(context, ref),
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsGeneralLanguage),
                description: Text(l10n.settingsGeneralLanguageDesc),
                value: Consumer(
                  builder: (context, ref, _) {
                    final locale = ref.watch(localeSettingsProvider).locale;
                    return Text(_localeLabel(l10n, locale));
                  },
                ),
              ),
              SettingsTile.navigation(
                onPressed: (context) => _showThemeModeSelector(context, ref),
                leading: const Icon(Icons.dark_mode_outlined),
                title: Text(l10n.settingsThemeMode),
                description: Text(l10n.settingsThemeModeDesc),
                value: Text(_themeModeLabel(l10n, themeSettings.themeMode)),
              ),
              if (!kIsWeb)
                SettingsTile.switchTile(
                  onToggle: (value) async {
                    await ref
                        .read(themeSettingsProvider.notifier)
                        .setDynamicColor(value ?? true);
                  },
                  initialValue: themeSettings.useDynamicColor,
                  leading: const Icon(Icons.palette_outlined),
                  title: Text(l10n.settingsDynamicColor),
                  description: Text(l10n.settingsDynamicColorDesc),
                ),
              if (!kIsWeb && !themeSettings.useDynamicColor)
                SettingsTile.navigation(
                  onPressed: (context) =>
                      _showColorSchemeSelector(context, ref),
                  leading: const Icon(Icons.color_lens_outlined),
                  title: Text(l10n.settingsColorScheme),
                  description: Text(l10n.settingsColorSchemeDesc),
                  value: _ColorDot(color: themeSettings.customSeedColor),
                ),
              if (showDesktopAccentSource && themeSettings.useDynamicColor)
                SettingsTile.navigation(
                  onPressed: (context) =>
                      _showDesktopAccentSourceSelector(context, ref),
                  leading: const Icon(Icons.color_lens_outlined),
                  title: Text(l10n.settingsDesktopAccentSource),
                  description: Text(l10n.settingsDesktopAccentSourceDesc),
                  value: Consumer(
                    builder: (context, ref, _) {
                      final source = ref
                          .watch(themeSettingsProvider)
                          .desktopAccentColorSource;
                      return Text(_desktopAccentSourceLabel(l10n, source));
                    },
                  ),
                ),
              if (showWideNavigationPosition)
                SettingsTile.navigation(
                  onPressed: (context) =>
                      _showWideNavigationPositionSelector(context, ref),
                  leading: const Icon(Icons.vertical_split_outlined),
                  title: Text(l10n.settingsWideNavigationPosition),
                  description: Text(l10n.settingsWideNavigationPositionDesc),
                  value: Consumer(
                    builder: (context, ref, _) {
                      final position = ref
                          .watch(appSettingsProvider)
                          .wideNavigationRailPosition;
                      return Text(_wideNavigationPositionLabel(l10n, position));
                    },
                  ),
                ),
              if (showDesktopWindowSettings)
                SettingsTile.navigation(
                  onPressed: (context) =>
                      _showDesktopExitBehaviorMenu(context, ref),
                  leading: const Icon(Icons.close_fullscreen_outlined),
                  title: Text(l10n.settingsDesktopCloseBehavior),
                  description: Text(l10n.settingsDesktopCloseBehaviorDesc),
                  value: Text(
                    _desktopExitBehaviorLabel(
                      l10n,
                      ref.watch(_desktopExitBehaviorProvider),
                    ),
                  ),
                ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setAutoReconnect(value ?? false);
                },
                initialValue: ref.watch(appSettingsProvider).autoReconnect,
                leading: const Icon(Icons.bluetooth_connected_outlined),
                title: Text(l10n.settingsAutoReconnectTitle),
                description: Text(l10n.settingsAutoReconnectDesc),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsSource,
            tiles: [
              SettingsTile.navigation(
                onPressed: (context) => _showCdnMenu(context, ref),
                leading: const Icon(Icons.cloud_outlined),
                title: Text(l10n.settingsSourceOfficialCdn),
                description: Text(l10n.settingsSourceOfficialCdnDesc),
                value: Consumer(
                  builder: (context, ref, _) {
                    final cdn = ref.watch(appSettingsProvider).cdn;
                    return Text(cdn.displayName);
                  },
                ),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsInstall,
            tiles: [
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setAutoInstall(value ?? true);
                },
                initialValue: ref.watch(appSettingsProvider).autoInstall,
                leading: const Icon(Icons.task_alt_outlined),
                title: Text(l10n.settingsQueueAutoInstall),
                description: Text(l10n.settingsQueueAutoInstallDesc),
              ),
              SettingsTile.switchTile(
                onToggle: (value) async {
                  await ref
                      .read(appSettingsProvider.notifier)
                      .setDisableAutoClean(value ?? false);
                },
                initialValue: ref.watch(appSettingsProvider).disableAutoClean,
                leading: const Icon(Icons.playlist_add_check_outlined),
                title: Text(l10n.settingsQueueDontClear),
                description: Text(l10n.settingsQueueDontClearDesc),
              ),
            ],
          ),
          _buildSection(
            context,
            title: l10n.settingsAbout,
            tiles: [
              SettingsTile.navigation(
                onPressed: (_) => context.push('/settings/about'),
                leading: const Icon(Icons.info_outline),
                title: Text(l10n.settingsAboutSoftware),
                description: Text(l10n.settingsAboutSoftwareDesc),
              ),
              SettingsTile.navigation(
                onPressed: (_) => _showLicensePage(context),
                leading: const Icon(Icons.description_outlined),
                title: Text(l10n.openSourceLicenses),
                description: Text(l10n.settingsAboutLicencesDesc),
              ),
              SettingsTile.navigation(
                onPressed: (_) => context.push('/settings/acknowledgements'),
                leading: const Icon(Icons.favorite_outline),
                title: Text(l10n.acknowledgements),
                description: Text(l10n.acknowledgementsDesc),
              ),
              SettingsTile.navigation(
                onPressed: (_) =>
                    _launchUrl(context, 'https://zerobox.zxor.org'),
                leading: const Icon(Icons.language_outlined),
                title: Text(l10n.settingsAboutWebsite),
                description: Text(l10n.settingsAboutWebsiteDesc),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SettingsSection _buildSection(
    BuildContext context, {
    required String title,
    required List<AbstractSettingsTile> tiles,
  }) {
    return SettingsSection(title: Text(title), tiles: tiles);
  }

  String _localeLabel(AppLocalizations l10n, AppLocale locale) {
    return switch (locale) {
      AppLocale.en => 'English',
      AppLocale.zh => '中文',
      _ => l10n.settingsSystem,
    };
  }

  String _themeModeLabel(AppLocalizations l10n, AppThemeMode mode) {
    return switch (mode) {
      AppThemeMode.light => l10n.settingsLight,
      AppThemeMode.dark => l10n.settingsDark,
      AppThemeMode.oledDark => l10n.settingsOledDark,
      _ => l10n.settingsSystem,
    };
  }

  String _desktopAccentSourceLabel(
    AppLocalizations l10n,
    DesktopAccentColorSource source,
  ) {
    return switch (source) {
      DesktopAccentColorSource.gtk => l10n.settingsDesktopAccentSourceGtk,
      DesktopAccentColorSource.qt => l10n.settingsDesktopAccentSourceQt,
      _ => l10n.settingsDesktopAccentSourceSystem,
    };
  }

  String _wideNavigationPositionLabel(
    AppLocalizations l10n,
    WideNavigationRailPosition position,
  ) {
    return switch (position) {
      WideNavigationRailPosition.center =>
        l10n.settingsWideNavigationPositionCenter,
      WideNavigationRailPosition.split =>
        l10n.settingsWideNavigationPositionSplit,
      _ => l10n.settingsWideNavigationPositionBottom,
    };
  }

  Future<void> _showCdnMenu(BuildContext context, WidgetRef ref) async {
    final current = ref.read(appSettingsProvider).cdn;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<AstroBoxCdn>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: AstroBoxCdn.values.map((cdn) {
        return PopupMenuItem<AstroBoxCdn>(
          value: cdn,
          child: Text(cdn.displayName),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(appSettingsProvider.notifier).setCdn(selected);
      ref.invalidate(communityCatalogDevicesProvider);
    }
  }

  Future<void> _showMiAccountLogin(BuildContext context, WidgetRef ref) async {
    final rootContext = context;
    final l10n = AppLocalizations.of(context)!;
    final prefs = SharedPrefsService.instance;
    var rememberCredentials = prefs.getBool(_keyMiAccountRemember) ?? false;
    var username = rememberCredentials
        ? prefs.getString(_keyMiAccountUsername) ?? ''
        : '';
    var password = rememberCredentials
        ? prefs.getString(_keyMiAccountPassword) ?? ''
        : '';
    var running = false;
    var obscurePassword = true;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final normalizedUsername = username.trim();
              if (normalizedUsername.isEmpty || password.isEmpty) {
                setState(() {
                  error = l10n.settingsMiAccountMissingCredentials;
                });
                return;
              }
              setState(() {
                running = true;
                error = null;
              });
              final accountService = ref.read(miAccountServiceProvider);
              try {
                final token = await accountService.login(
                  username: normalizedUsername,
                  password: password,
                );
                final devices = await accountService.fetchBoundDevices(
                  token: token,
                );
                final imported = await ref
                    .read(deviceManagerProvider.notifier)
                    .importMiCloudDevices(devices);
                await _persistMiAccountCredentials(
                  remember: rememberCredentials,
                  username: normalizedUsername,
                  password: password,
                  userId: token.userId,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(
                      content: Text(
                        l10n.settingsMiAccountSyncedDevices(imported),
                      ),
                    ),
                  );
                }
              } on MiAccountTwoFactorRequired catch (e) {
                try {
                  setState(() {
                    error = l10n.settingsMiAccountTwoFactorPrompt;
                  });
                  if (!rootContext.mounted) {
                    throw StateError(l10n.settingsMiAccountLoginWindowClosed);
                  }
                  final cookieHeader = await createMiAccountTwoFactorResolver()
                      .resolve(rootContext, Uri.parse(e.url));
                  final token = await accountService.completeTwoFactorLogin(
                    challenge: e,
                    cookieHeader: cookieHeader,
                  );
                  final devices = await accountService.fetchBoundDevices(
                    token: token,
                  );
                  final imported = await ref
                      .read(deviceManagerProvider.notifier)
                      .importMiCloudDevices(devices);
                  await _persistMiAccountCredentials(
                    remember: rememberCredentials,
                    username: normalizedUsername,
                    password: password,
                    userId: token.userId,
                  );
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (rootContext.mounted) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.settingsMiAccountSyncedDevices(imported),
                        ),
                      ),
                    );
                  }
                } catch (twoFactorError) {
                  setState(() {
                    running = false;
                    error = localizedErrorMessage(l10n, twoFactorError);
                  });
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, e);
                });
              }
            }

            return AlertDialog(
              title: Text(l10n.settingsMiAccountLoginTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: username,
                      onChanged: (value) => username = value,
                      enabled: !running,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.settingsMiAccountUsername,
                        prefixIcon: const Icon(Icons.account_circle_outlined),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: password,
                      onChanged: (value) => password = value,
                      enabled: !running,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.settingsMiAccountPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: running
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        if (!running) submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberCredentials,
                      onChanged: running
                          ? null
                          : (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.settingsMiAccountRememberCredentials),
                      dense: true,
                    ),
                    if (running) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: running
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: running ? null : submit,
                  child: Text(l10n.settingsMiAccountLoginAndSync),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _persistMiAccountCredentials({
    required bool remember,
    required String username,
    required String password,
    required String userId,
  }) async {
    final prefs = SharedPrefsService.instance;
    if (userId.isNotEmpty) {
      await prefs.setString(_keyMiAccountUserId, userId);
    }
    await prefs.setBool(_keyMiAccountRemember, remember);
    if (!remember) {
      await prefs.remove(_keyMiAccountUsername);
      await prefs.remove(_keyMiAccountPassword);
      return;
    }
    await prefs.setString(_keyMiAccountUsername, username);
    await prefs.setString(_keyMiAccountPassword, password);
  }

  Future<void> _showHuamiAccountLogin(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final rootContext = context;
    final l10n = AppLocalizations.of(context)!;
    final prefs = SharedPrefsService.instance;
    final existing = ref.read(huamiAuthProvider);
    var rememberCredentials = prefs.getBool(_keyHuamiAccountRemember) ?? false;
    var username = existing.username ?? '';
    var password = rememberCredentials
        ? prefs.getString(_keyHuamiAccountPassword) ?? ''
        : '';
    var running = false;
    var obscurePassword = true;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> submit() async {
              final normalizedUsername = username.trim();
              if (normalizedUsername.isEmpty || password.isEmpty) {
                setState(() {
                  error = l10n.settingsHuamiAccountMissingCredentials;
                });
                return;
              }
              setState(() {
                running = true;
                error = null;
              });
              try {
                await ref
                    .read(huamiAuthProvider.notifier)
                    .login(username: normalizedUsername, password: password);
                await _persistHuamiAccountCredentials(
                  remember: rememberCredentials,
                  password: password,
                );
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    SnackBar(content: Text(l10n.settingsHuamiAccountSignedIn)),
                  );
                }
              } catch (e) {
                setState(() {
                  running = false;
                  error = localizedErrorMessage(l10n, e);
                });
              }
            }

            Future<void> signOut() async {
              setState(() {
                running = true;
                error = null;
              });
              await ref.read(huamiAuthProvider.notifier).signOut();
              await _persistHuamiAccountCredentials(
                remember: false,
                password: '',
              );
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            }

            return AlertDialog(
              title: Text(l10n.settingsHuamiAccountLoginTitle),
              content: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      initialValue: username,
                      onChanged: (value) => username = value,
                      enabled: !running,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: l10n.settingsHuamiAccountUsername,
                        prefixIcon: const Icon(Icons.functions),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      initialValue: password,
                      onChanged: (value) => password = value,
                      enabled: !running,
                      obscureText: obscurePassword,
                      decoration: InputDecoration(
                        labelText: l10n.settingsHuamiAccountPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: running
                              ? null
                              : () {
                                  setState(() {
                                    obscurePassword = !obscurePassword;
                                  });
                                },
                          icon: Icon(
                            obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      onFieldSubmitted: (_) {
                        if (!running) submit();
                      },
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: rememberCredentials,
                      onChanged: running
                          ? null
                          : (value) {
                              setState(() {
                                rememberCredentials = value ?? false;
                              });
                            },
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.settingsHuamiAccountRememberCredentials),
                      dense: true,
                    ),
                    if (running) ...[
                      const SizedBox(height: 20),
                      const LinearProgressIndicator(),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                if (existing.isSignedIn)
                  TextButton(
                    onPressed: running ? null : signOut,
                    child: Text(l10n.bandBbsLogout),
                  ),
                TextButton(
                  onPressed: running
                      ? null
                      : () {
                          Navigator.of(dialogContext).pop();
                        },
                  child: Text(l10n.settingsCancel),
                ),
                FilledButton(
                  onPressed: running ? null : submit,
                  child: Text(l10n.settingsHuamiAccountLoginAndSave),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _persistHuamiAccountCredentials({
    required bool remember,
    required String password,
  }) async {
    final prefs = SharedPrefsService.instance;
    await prefs.setBool(_keyHuamiAccountRemember, remember);
    if (!remember) {
      await prefs.remove(_keyHuamiAccountPassword);
      return;
    }
    await prefs.setString(_keyHuamiAccountPassword, password);
  }

  Future<void> _showLanguageSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(localeSettingsProvider).locale;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<AppLocale>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: AppLocale.values.map((locale) {
        final selected = locale == current;
        return PopupMenuItem<AppLocale>(
          value: locale,
          child: Row(
            children: [
              Expanded(child: Text(_localeLabel(l10n, locale))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(localeSettingsProvider.notifier).setLocale(selected);
    }
  }

  Future<void> _showDesktopAccentSourceSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).desktopAccentColorSource;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<DesktopAccentColorSource>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: DesktopAccentColorSource.values.map((source) {
        final selected = source == current;
        return PopupMenuItem<DesktopAccentColorSource>(
          value: source,
          child: Row(
            children: [
              Expanded(child: Text(_desktopAccentSourceLabel(l10n, source))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref
          .read(themeSettingsProvider.notifier)
          .setDesktopAccentColorSource(selected);
    }
  }

  Future<void> _showThemeModeSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).themeMode;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<AppThemeMode>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: AppThemeMode.values.map((mode) {
        final selected = mode == current;
        return PopupMenuItem<AppThemeMode>(
          value: mode,
          child: Row(
            children: [
              Expanded(child: Text(_themeModeLabel(l10n, mode))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref.read(themeSettingsProvider.notifier).setThemeMode(selected);
    }
  }

  Future<void> _showColorSchemeSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(themeSettingsProvider).customSeedColor;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<Color>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: _colorSchemes.map((color) {
        final selected = color.toARGB32() == current.toARGB32();
        return PopupMenuItem<Color>(
          value: color,
          child: Row(
            children: [
              _ColorDot(color: color),
              const SizedBox(width: 12),
              Expanded(child: Text(_colorSchemeLabel(l10n, color))),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected.toARGB32() != current.toARGB32()) {
      await ref
          .read(themeSettingsProvider.notifier)
          .setCustomSeedColor(selected);
    }
  }

  String _colorSchemeLabel(AppLocalizations l10n, Color color) {
    return switch (color.toARGB32()) {
      0xFFE91E63 => l10n.settingsColorSchemePink,
      0xFF6750A4 => l10n.settingsColorSchemePurple,
      0xFF006A6A => l10n.settingsColorSchemeTeal,
      0xFF006D3F => l10n.settingsColorSchemeGreen,
      0xFFB3261E => l10n.settingsColorSchemeRed,
      0xFF755B00 => l10n.settingsColorSchemeAmber,
      _ =>
        '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    };
  }

  Future<void> _showWideNavigationPositionSelector(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final current = ref.read(appSettingsProvider).wideNavigationRailPosition;
    final l10n = AppLocalizations.of(context)!;
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;

    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );

    final selected = await showMenu<WideNavigationRailPosition>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current,
      items: WideNavigationRailPosition.values.map((position) {
        final selected = position == current;
        return PopupMenuItem<WideNavigationRailPosition>(
          value: position,
          child: Row(
            children: [
              Expanded(
                child: Text(_wideNavigationPositionLabel(l10n, position)),
              ),
              if (selected) const Icon(Icons.check),
            ],
          ),
        );
      }).toList(),
    );
    if (selected != null && selected != current) {
      await ref
          .read(appSettingsProvider.notifier)
          .setWideNavigationRailPosition(selected);
    }
  }

  Future<void> _startBandBbsLogin(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref.read(bandBbsAuthProvider.notifier).startLogin();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountBandBbsOpenedBrowser)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(localizedErrorMessage(l10n, e))));
    }
  }

  Future<void> _showDesktopExitBehaviorMenu(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final current = ref.read(_desktopExitBehaviorProvider);
    final tileContext = context;
    final renderBox = tileContext.findRenderObject() as RenderBox?;
    final overlay =
        Navigator.of(tileContext).overlay?.context.findRenderObject()
            as RenderBox?;
    if (renderBox == null || overlay == null) return;
    final tileTopLeft = renderBox.localToGlobal(Offset.zero, ancestor: overlay);
    final tileBottomRight = renderBox.localToGlobal(
      renderBox.size.bottomRight(Offset.zero),
      ancestor: overlay,
    );
    final anchor = Rect.fromLTWH(
      tileBottomRight.dx - 48,
      tileTopLeft.dy,
      48,
      renderBox.size.height,
    );
    final selected = await showMenu<int>(
      context: tileContext,
      position: RelativeRect.fromRect(anchor, Offset.zero & overlay.size),
      initialValue: current ?? -1,
      items: [
        PopupMenuItem(value: -1, child: Text(l10n.desktopCloseBehaviorAsk)),
        PopupMenuItem(value: 0, child: Text(l10n.desktopCloseBehaviorExit)),
        PopupMenuItem(value: 1, child: Text(l10n.desktopCloseBehaviorTray)),
      ],
    );
    if (selected == null || !context.mounted) return;
    if (selected == -1) {
      await SharedPrefsService.instance.remove('desktop.exit_behavior');
    } else {
      await SharedPrefsService.instance.setInt(
        'desktop.exit_behavior',
        selected,
      );
    }
    ref.invalidate(_desktopExitBehaviorProvider);
  }

  void _showLicensePage(BuildContext context) {
    showLicensePage(context: context);
  }

  Future<void> _launchUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}

String _desktopExitBehaviorLabel(AppLocalizations l10n, int? behavior) =>
    switch (behavior) {
      0 => l10n.desktopCloseBehaviorExit,
      1 => l10n.desktopCloseBehaviorTray,
      _ => l10n.desktopCloseBehaviorAsk,
    };

class _AccountLeading extends StatelessWidget {
  const _AccountLeading({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(dimension: 32, child: Center(child: child));
  }
}

class _MiLogo extends StatelessWidget {
  const _MiLogo();

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: SvgPicture.asset(
          'assets/images/brands/xiaomi.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: 'Xiaomi',
        ),
      ),
    );
  }
}

class _AccountBrandLogo extends StatelessWidget {
  const _AccountBrandLogo({required this.asset, required this.semanticsLabel});

  final String asset;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 32,
      child: Center(
        child: SvgPicture.asset(
          asset,
          width: 27,
          height: 27,
          colorFilter: ColorFilter.mode(
            Theme.of(context).colorScheme.onSurface,
            BlendMode.srcIn,
          ),
          semanticsLabel: semanticsLabel,
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  const _ColorDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const SizedBox.square(dimension: 22),
    );
  }
}
