import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/community/community_source.dart';

class AppSettings {
  const AppSettings({
    required this.cdn,
    required this.communitySource,
    required this.autoInstall,
    required this.disableAutoClean,
    required this.autoReconnect,
  });

  final AstroBoxCdn cdn;
  final CommunitySourceId communitySource;
  final bool autoInstall;
  final bool disableAutoClean;
  final bool autoReconnect;

  AppSettings copyWith({
    AstroBoxCdn? cdn,
    CommunitySourceId? communitySource,
    bool? autoInstall,
    bool? disableAutoClean,
    bool? autoReconnect,
  }) {
    return AppSettings(
      cdn: cdn ?? this.cdn,
      communitySource: communitySource ?? this.communitySource,
      autoInstall: autoInstall ?? this.autoInstall,
      disableAutoClean: disableAutoClean ?? this.disableAutoClean,
      autoReconnect: autoReconnect ?? this.autoReconnect,
    );
  }

  static const String _keyCdn = 'astrobox_cdn';
  static const String _keyCommunitySource = 'community_source';
  static const String _keyAutoInstall = 'auto_install';
  static const String _keyDisableAutoClean = 'disable_auto_clean';
  static const String _keyAutoReconnect = 'auto_reconnect';

  static AppSettings load() {
    final prefs = SharedPrefsService.instance;
    final cdnRaw = prefs.getString(_keyCdn);
    final sourceRaw = prefs.getString(_keyCommunitySource);
    return AppSettings(
      cdn: astroBoxCdnByName(cdnRaw ?? '') ?? AstroBoxCdn.raw,
      communitySource:
          communitySourceIdByName(sourceRaw ?? '') ??
          CommunitySourceId.astroboxRepo,
      autoInstall: prefs.getBool(_keyAutoInstall) ?? true,
      disableAutoClean: prefs.getBool(_keyDisableAutoClean) ?? false,
      autoReconnect: prefs.getBool(_keyAutoReconnect) ?? false,
    );
  }

  Future<void> save() async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyCdn, cdn.name);
    await prefs.setString(_keyCommunitySource, communitySource.storageKey);
    await prefs.setBool(_keyAutoInstall, autoInstall);
    await prefs.setBool(_keyDisableAutoClean, disableAutoClean);
    await prefs.setBool(_keyAutoReconnect, autoReconnect);
  }
}

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => AppSettings.load();

  Future<void> setCdn(AstroBoxCdn cdn) async {
    state = state.copyWith(cdn: cdn);
    await state.save();
  }

  Future<void> setCommunitySource(CommunitySourceId source) async {
    state = state.copyWith(communitySource: source);
    await state.save();
  }

  Future<void> setAutoInstall(bool value) async {
    state = state.copyWith(autoInstall: value);
    await state.save();
  }

  Future<void> setDisableAutoClean(bool value) async {
    state = state.copyWith(disableAutoClean: value);
    await state.save();
  }

  Future<void> setAutoReconnect(bool value) async {
    state = state.copyWith(autoReconnect: value);
    await state.save();
  }
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);
