import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/services/shared_prefs_service.dart';
import 'package:zerobox/src/data/astrobox/astrobox_cdn.dart';
import 'package:zerobox/src/data/community/community_source.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

enum WideNavigationRailPosition { bottom, center, split }

class AppSettings {
  const AppSettings({
    required this.cdn,
    required this.communitySource,
    required this.autoInstall,
    required this.disableAutoClean,
    required this.autoReconnect,
    required this.wideNavigationRailPosition,
    required this.bandbbsLoadPreviews,
    required this.bandbbsShowAllCategories,
  });

  final AstroBoxCdn cdn;
  final CommunitySourceId communitySource;
  final bool autoInstall;
  final bool disableAutoClean;
  final bool autoReconnect;
  final WideNavigationRailPosition wideNavigationRailPosition;
  final bool bandbbsLoadPreviews;
  final bool bandbbsShowAllCategories;

  AppSettings copyWith({
    AstroBoxCdn? cdn,
    CommunitySourceId? communitySource,
    bool? autoInstall,
    bool? disableAutoClean,
    bool? autoReconnect,
    WideNavigationRailPosition? wideNavigationRailPosition,
    bool? bandbbsLoadPreviews,
    bool? bandbbsShowAllCategories,
  }) {
    return AppSettings(
      cdn: cdn ?? this.cdn,
      communitySource: communitySource ?? this.communitySource,
      autoInstall: autoInstall ?? this.autoInstall,
      disableAutoClean: disableAutoClean ?? this.disableAutoClean,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      wideNavigationRailPosition:
          wideNavigationRailPosition ?? this.wideNavigationRailPosition,
      bandbbsLoadPreviews: bandbbsLoadPreviews ?? this.bandbbsLoadPreviews,
      bandbbsShowAllCategories:
          bandbbsShowAllCategories ?? this.bandbbsShowAllCategories,
    );
  }

  static const String _keyCdn = 'astrobox_cdn';
  static const String _keyCommunitySource = 'community_source';
  static const String _keyAutoInstall = 'auto_install';
  static const String _keyDisableAutoClean = 'disable_auto_clean';
  static const String _keyAutoReconnect = 'auto_reconnect';
  static const String _keyWideNavigationRailPosition =
      'wide_navigation_rail_position';
  static const String _keyBandBbsLoadPreviews = 'bandbbs_load_previews';
  static const String _keyBandBbsShowAllCategories =
      'bandbbs_show_all_categories';

  static AppSettings load() {
    final prefs = SharedPrefsService.instance;
    final cdnRaw = prefs.getString(_keyCdn);
    final sourceRaw = prefs.getString(_keyCommunitySource);
    final railPositionRaw = prefs.getString(_keyWideNavigationRailPosition);
    return AppSettings(
      cdn: astroBoxCdnByName(cdnRaw ?? '') ?? AstroBoxCdn.raw,
      communitySource:
          communitySourceIdByName(sourceRaw ?? '') ??
          CommunitySourceId.astroboxRepo,
      autoInstall: prefs.getBool(_keyAutoInstall) ?? true,
      disableAutoClean: prefs.getBool(_keyDisableAutoClean) ?? false,
      autoReconnect: prefs.getBool(_keyAutoReconnect) ?? false,
      wideNavigationRailPosition: _enumByName(
        WideNavigationRailPosition.values,
        railPositionRaw,
        WideNavigationRailPosition.bottom,
      ),
      bandbbsLoadPreviews: prefs.getBool(_keyBandBbsLoadPreviews) ?? false,
      bandbbsShowAllCategories:
          prefs.getBool(_keyBandBbsShowAllCategories) ?? false,
    );
  }

  static const defaults = AppSettings(
    cdn: AstroBoxCdn.raw,
    communitySource: CommunitySourceId.astroboxRepo,
    autoInstall: true,
    disableAutoClean: false,
    autoReconnect: false,
    wideNavigationRailPosition: WideNavigationRailPosition.bottom,
    bandbbsLoadPreviews: false,
    bandbbsShowAllCategories: false,
  );

  Future<void> save() async {
    final prefs = SharedPrefsService.instance;
    await prefs.setString(_keyCdn, cdn.name);
    await prefs.setString(_keyCommunitySource, communitySource.storageKey);
    await prefs.setBool(_keyAutoInstall, autoInstall);
    await prefs.setBool(_keyDisableAutoClean, disableAutoClean);
    await prefs.setBool(_keyAutoReconnect, autoReconnect);
    await prefs.setString(
      _keyWideNavigationRailPosition,
      wideNavigationRailPosition.name,
    );
    await prefs.setBool(_keyBandBbsLoadPreviews, bandbbsLoadPreviews);
    await prefs.setBool(_keyBandBbsShowAllCategories, bandbbsShowAllCategories);
  }

  static T _enumByName<T extends Enum>(
    Iterable<T> values,
    String? name,
    T fallback,
  ) {
    if (name == null) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}

abstract class AppSettingsNotifier extends Notifier<AppSettings> {
  Future<void> setCdn(AstroBoxCdn cdn);
  Future<void> setCommunitySource(CommunitySourceId source);
  Future<void> setAutoInstall(bool value);
  Future<void> setDisableAutoClean(bool value);
  Future<void> setAutoReconnect(bool value);
  Future<void> setWideNavigationRailPosition(WideNavigationRailPosition value);
  Future<void> setBandBbsLoadPreviews(bool value);
  Future<void> setBandBbsShowAllCategories(bool value);
}

class LocalAppSettingsNotifier extends AppSettingsNotifier {
  @override
  AppSettings build() => AppSettings.load();

  @override
  Future<void> setCdn(AstroBoxCdn cdn) async {
    state = state.copyWith(cdn: cdn);
    await state.save();
  }

  @override
  Future<void> setCommunitySource(CommunitySourceId source) async {
    state = state.copyWith(communitySource: source);
    await state.save();
  }

  @override
  Future<void> setAutoInstall(bool value) async {
    state = state.copyWith(autoInstall: value);
    await state.save();
  }

  @override
  Future<void> setDisableAutoClean(bool value) async {
    state = state.copyWith(disableAutoClean: value);
    await state.save();
  }

  @override
  Future<void> setAutoReconnect(bool value) async {
    state = state.copyWith(autoReconnect: value);
    await state.save();
  }

  @override
  Future<void> setWideNavigationRailPosition(
    WideNavigationRailPosition value,
  ) async {
    state = state.copyWith(wideNavigationRailPosition: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsLoadPreviews(bool value) async {
    state = state.copyWith(bandbbsLoadPreviews: value);
    await state.save();
  }

  @override
  Future<void> setBandBbsShowAllCategories(bool value) async {
    state = state.copyWith(bandbbsShowAllCategories: value);
    await state.save();
  }
}

class HostAppSettingsNotifier extends AppSettingsNotifier {
  StreamSubscription<CommandEvent>? _subscription;

  @override
  AppSettings build() {
    _subscription = ref.watch(applicationHostProvider).events.listen((event) {
      if (event.event == 'settings.state' || event.event == 'host.connected') {
        unawaited(refresh());
      }
    });
    ref.onDispose(() => unawaited(_subscription?.cancel()));
    Future.microtask(refresh);
    return AppSettings.load();
  }

  Future<void> refresh() async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(const ZeroBoxCommand(method: 'settings.list'));
    if (!result.ok) return;
    final json = (result.value as Map).cast<String, Object?>();
    state = AppSettings(
      cdn:
          astroBoxCdnByName(json['astrobox_cdn']?.toString() ?? '') ??
          AstroBoxCdn.raw,
      communitySource:
          communitySourceIdByName(json['community_source']?.toString() ?? '') ??
          CommunitySourceId.astroboxRepo,
      autoInstall: json['auto_install'] as bool? ?? true,
      disableAutoClean: json['disable_auto_clean'] as bool? ?? false,
      autoReconnect: json['auto_reconnect'] as bool? ?? false,
      wideNavigationRailPosition: state.wideNavigationRailPosition,
      bandbbsLoadPreviews: json['bandbbs_load_previews'] as bool? ?? false,
      bandbbsShowAllCategories:
          json['bandbbs_show_all_categories'] as bool? ?? false,
    );
  }

  Future<void> _set(String key, Object value, AppSettings next) async {
    final result = await ref
        .read(applicationHostProvider)
        .execute(
          ZeroBoxCommand(
            method: 'settings.set',
            params: {'key': key, 'value': value},
          ),
        );
    if (!result.ok) {
      throw StateError('${result.error!.code}: ${result.error!.message}');
    }
    state = next;
  }

  @override
  Future<void> setCdn(AstroBoxCdn cdn) =>
      _set('astrobox_cdn', cdn.name, state.copyWith(cdn: cdn));
  @override
  Future<void> setCommunitySource(CommunitySourceId source) => _set(
    'community_source',
    source.storageKey,
    state.copyWith(communitySource: source),
  );
  @override
  Future<void> setAutoInstall(bool value) =>
      _set('auto_install', value, state.copyWith(autoInstall: value));
  @override
  Future<void> setDisableAutoClean(bool value) => _set(
    'disable_auto_clean',
    value,
    state.copyWith(disableAutoClean: value),
  );
  @override
  Future<void> setAutoReconnect(bool value) =>
      _set('auto_reconnect', value, state.copyWith(autoReconnect: value));
  @override
  Future<void> setWideNavigationRailPosition(
    WideNavigationRailPosition value,
  ) async {
    state = state.copyWith(wideNavigationRailPosition: value);
    await SharedPrefsService.instance.setString(
      AppSettings._keyWideNavigationRailPosition,
      value.name,
    );
  }

  @override
  Future<void> setBandBbsLoadPreviews(bool value) => _set(
    'bandbbs_load_previews',
    value,
    state.copyWith(bandbbsLoadPreviews: value),
  );
  @override
  Future<void> setBandBbsShowAllCategories(bool value) => _set(
    'bandbbs_show_all_categories',
    value,
    state.copyWith(bandbbsShowAllCategories: value),
  );
}

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  LocalAppSettingsNotifier.new,
);
