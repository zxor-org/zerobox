import 'dart:async';

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/theme/app_theme.dart';
import 'package:zerobox/src/app/theme/system_accent_color.dart';
import 'package:zerobox/src/app/window/secondary_window_host.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';
import 'package:zerobox/src/core/providers/theme_locale_providers.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/features/debug/widgets/debug_console.dart';
import 'package:zerobox/src/features/debug/widgets/debug_inspectors.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

final _desktopAccentColorProvider = FutureProvider<Color?>((ref) {
  final source = ref.watch(
    themeSettingsProvider.select((settings) {
      return settings.desktopAccentColorSource;
    }),
  );
  return loadDesktopAccentColor(source);
});

class DebugWindowApp extends ConsumerWidget {
  const DebugWindowApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                  _accentColorScheme(desktopAccentColor, Brightness.light)
            : _seedColorScheme(themeSettings.customSeedColor, Brightness.light);
        final darkColorScheme = useDynamicColor
            ? darkDynamic ??
                  _accentColorScheme(desktopAccentColor, Brightness.dark)
            : _seedColorScheme(themeSettings.customSeedColor, Brightness.dark);

        return MaterialApp(
          title: 'ZeroBox DevTools',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.buildLightTheme(colorScheme: lightColorScheme),
          darkTheme: themeSettings.isOledDark
              ? AppTheme.buildOledDarkTheme(colorScheme: darkColorScheme)
              : AppTheme.buildDarkTheme(colorScheme: darkColorScheme),
          themeMode: themeSettings.materialThemeMode,
          locale: localeSettings.materialLocale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SecondaryWindowHost(
            role: 'debug',
            child: DebugWindowPage(),
          ),
        );
      },
    );
  }

  ColorScheme? _accentColorScheme(Color? accentColor, Brightness brightness) {
    if (accentColor == null) {
      return null;
    }
    return _seedColorScheme(accentColor, brightness);
  }

  ColorScheme _seedColorScheme(Color seedColor, Brightness brightness) {
    return ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  }
}

class DebugWindowPage extends ConsumerStatefulWidget {
  const DebugWindowPage({super.key, this.embedded = false});

  /// Embedded mode is used inside the main app (Android): adds an app bar
  /// with back navigation and switches to the narrow-screen layout.
  final bool embedded;

  @override
  ConsumerState<DebugWindowPage> createState() => _DebugWindowPageState();
}

class _DebugWindowPageState extends ConsumerState<DebugWindowPage>
    with SingleTickerProviderStateMixin {
  late final ZeroBoxCommandBus _host;
  late final TabController _tabs;
  StreamSubscription<CommandEvent>? _events;
  final _records = <DiagnosticEvent>[];
  final _plugins = <String, Map<String, Object?>>{};
  final _search = TextEditingController();
  String _source = 'all';
  String _level = 'ALL';
  bool _paused = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
    _host = ref.read(applicationHostProvider);
    _events = _host.events.listen(_onEvent);
    unawaited(_load());
  }

  @override
  void dispose() {
    _events?.cancel();
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result = await _host.execute(
        const ZeroBoxCommand(method: 'debug.snapshot'),
      );
      if (!result.ok) throw StateError(result.error!.message);
      final snapshot = (result.value as Map).cast<String, Object?>();
      final records = (snapshot['records'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => DiagnosticEvent.fromJson(value.cast()))
          .toList();
      final plugins = (snapshot['plugins'] as List? ?? const [])
          .whereType<Map>()
          .map((value) => value.cast<String, Object?>());
      if (!mounted) return;
      setState(() {
        _records
          ..clear()
          ..addAll(records);
        _plugins
          ..clear()
          ..addEntries(
            plugins.map((plugin) => MapEntry(plugin['id'].toString(), plugin)),
          );
        if (_source.startsWith('plugin:') && _selectedPlugin == null) {
          _source = 'all';
        }
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _onEvent(CommandEvent event) {
    if (event.event == 'debug.log' && !_paused) {
      final value = event.data['record'];
      if (value is! Map || !mounted) return;
      setState(() {
        _records.add(DiagnosticEvent.fromJson(value.cast()));
        if (_records.length > 2000) _records.removeAt(0);
      });
    } else if (event.event == 'debug.plugin.changed') {
      final value = event.data['plugin'];
      if (value is! Map || !mounted) return;
      final plugin = value.cast<String, Object?>();
      setState(() => _plugins[plugin['id'].toString()] = plugin);
    }
  }

  List<DiagnosticEvent> get _visibleRecords {
    final query = _search.text.trim().toLowerCase();
    return _records
        .where((record) {
          if (_source != 'all' && record.scope != _source) return false;
          if (_level != 'ALL' && record.level.name != _level) return false;
          return query.isEmpty ||
              record.message.toLowerCase().contains(query) ||
              record.source.toLowerCase().contains(query);
        })
        .toList(growable: false);
  }

  Map<String, Object?>? get _selectedPlugin => _source.startsWith('plugin:')
      ? _plugins[_source.substring('plugin:'.length)]
      : null;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isWide = useWideLayout(MediaQuery.sizeOf(context).width);
    final content = Column(
      children: [
        _Toolbar(
          search: _search,
          level: _level,
          paused: _paused,
          onRefresh: _load,
          onSearch: () => setState(() {}),
          onLevel: (value) => setState(() => _level = value),
          onPause: () => setState(() => _paused = !_paused),
          onClear: () => setState(_records.clear),
        ),
        TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: const [
            Tab(icon: Icon(Icons.terminal), text: 'Console'),
            Tab(
              icon: Icon(Icons.account_tree_outlined),
              text: 'Layout',
            ),
            Tab(icon: Icon(Icons.memory), text: 'Runtime'),
            Tab(icon: Icon(Icons.folder_outlined), text: 'Storage'),
          ],
        ),
        const Divider(height: 1),
        Expanded(
          child: _error != null
              ? Center(child: Text(_error.toString()))
              : TabBarView(
                  controller: _tabs,
                  children: [
                    DebugConsole(records: _visibleRecords),
                    DebugLayoutInspector(
                      nodes: (_selectedPlugin?['layout'] as List? ?? const [])
                          .whereType<Map>()
                          .map((node) => node.cast<String, Object?>())
                          .toList(growable: false),
                    ),
                    DebugRuntimeInspector(
                      host: _host,
                      source: _source,
                      plugin: _selectedPlugin,
                    ),
                    DebugStorageInspector(
                      host: _host,
                      source: _source,
                      plugin: _selectedPlugin,
                    ),
                  ],
                ),
        ),
      ],
    );
    return Scaffold(
      appBar: widget.embedded
          ? SysAppBar(secondary: true, title: Text(l10n.devTools))
          : null,
      body: isWide
          ? Row(
              children: [
                SizedBox(
                  width: 190,
                  child: Material(
                    color: colors.surfaceContainerLow,
                    child: _SourceList(
                      source: _source,
                      records: _records,
                      plugins: _plugins,
                      onSelected: (value) => setState(() => _source = value),
                    ),
                  ),
                ),
                const VerticalDivider(width: 1),
                Expanded(child: content),
              ],
            )
          : Column(
              children: [
                _SourceChips(
                  source: _source,
                  records: _records,
                  plugins: _plugins,
                  onSelected: (value) => setState(() => _source = value),
                ),
                const Divider(height: 1),
                Expanded(child: content),
              ],
            ),
    );
  }
}

class _SourceChips extends StatelessWidget {
  const _SourceChips({
    required this.source,
    required this.records,
    required this.plugins,
    required this.onSelected,
  });

  final String source;
  final List<DiagnosticEvent> records;
  final Map<String, Map<String, Object?>> plugins;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(String value) => value == 'all'
        ? records.length
        : records.where((record) => record.scope == value).length;
    final entries = <(String, String)>[
      ('all', 'All'),
      ('frontend', 'Frontend'),
      ('backend', 'Backend'),
      for (final plugin in plugins.values)
        (
          'plugin:${plugin['id']}',
          plugin['name']?.toString() ?? plugin['id'].toString(),
        ),
    ];
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          for (final entry in entries)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: ChoiceChip(
                selected: source == entry.$1,
                onSelected: (_) => onSelected(entry.$1),
                label: Text('${entry.$2} ${count(entry.$1)}'),
              ),
            ),
        ],
      ),
    );
  }
}

class _SourceList extends StatelessWidget {
  const _SourceList({
    required this.source,
    required this.records,
    required this.plugins,
    required this.onSelected,
  });

  final String source;
  final List<DiagnosticEvent> records;
  final Map<String, Map<String, Object?>> plugins;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    int count(String value) => value == 'all'
        ? records.length
        : records.where((record) => record.scope == value).length;
    final entries = <(String, String, IconData)>[
      ('all', 'All sources', Icons.all_inclusive),
      ('frontend', 'Frontend', Icons.web_asset_outlined),
      ('backend', 'Backend', Icons.dns_outlined),
      for (final plugin in plugins.values)
        (
          'plugin:${plugin['id']}',
          plugin['name']?.toString() ?? plugin['id'].toString(),
          Icons.extension_outlined,
        ),
    ];
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
          child: Text('SOURCES', style: TextStyle(fontSize: 11)),
        ),
        for (final entry in entries)
          ListTile(
            dense: true,
            selected: source == entry.$1,
            leading: Icon(entry.$3, size: 19),
            title: Text(entry.$2, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Text(count(entry.$1).toString()),
            onTap: () => onSelected(entry.$1),
          ),
      ],
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.search,
    required this.level,
    required this.paused,
    required this.onRefresh,
    required this.onSearch,
    required this.onLevel,
    required this.onPause,
    required this.onClear,
  });

  final TextEditingController search;
  final String level;
  final bool paused;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final ValueChanged<String> onLevel;
  final VoidCallback onPause;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 52,
    child: Row(
      children: [
        const SizedBox(width: 12),
        Expanded(
          child: TextField(
            controller: search,
            onChanged: (_) => onSearch(),
            decoration: const InputDecoration(
              hintText: 'Filter logs',
              prefixIcon: Icon(Icons.search, size: 20),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: level,
            items: const ['ALL', 'FINE', 'INFO', 'WARNING', 'SEVERE']
                .map((item) => DropdownMenuItem(value: item, child: Text(item)))
                .toList(),
            onChanged: (value) => onLevel(value!),
          ),
        ),
        IconButton(
          onPressed: onRefresh,
          tooltip: 'Refresh',
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          onPressed: onPause,
          tooltip: paused ? 'Resume' : 'Pause',
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
        ),
        IconButton(
          onPressed: onClear,
          tooltip: 'Clear',
          icon: const Icon(Icons.delete_sweep_outlined),
        ),
        const SizedBox(width: 6),
      ],
    ),
  );
}
