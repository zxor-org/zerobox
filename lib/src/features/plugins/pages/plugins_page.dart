import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/network/dio_provider.dart';
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/features/plugins/application/abv1_plugin_store.dart';
import 'package:zerobox/src/features/plugins/domain/plugin_package.dart';
import 'package:zerobox/src/host/application_host_provider.dart';

import 'plugin_detail_page.dart';

class PluginsPage extends ConsumerStatefulWidget {
  const PluginsPage({super.key});

  @override
  ConsumerState<PluginsPage> createState() => _PluginsPageState();
}

class _PluginsPageState extends ConsumerState<PluginsPage> {
  var _plugins = <Map<String, Object?>>[];
  var _loading = true;
  var _query = '';
  var _section = 0;
  var _marketPlugins = <StorePlugin>[];
  var _marketLoading = false;
  Object? _marketError;
  final _installing = <String>{};
  String? _selectedPluginId;
  var _safeMode = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final values = await Future.wait([
        _execute(const ZeroBoxCommand(method: 'plugin.list')),
        _execute(const ZeroBoxCommand(method: 'plugin.safeMode.get')),
      ]);
      if (!mounted) return;
      setState(() {
        _plugins = (values[0] as List)
            .whereType<Map>()
            .map((row) => row.cast<String, Object?>())
            .toList(growable: false);
        _safeMode = (values[1] as Map?)?['enabled'] == true;
        final ids = _plugins.map((plugin) => plugin['id']?.toString()).toSet();
        if (!ids.contains(_selectedPluginId)) {
          _selectedPluginId = null;
        }
      });
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importPlugin() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zbp', 'abp'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file = picked.files.single;
    final bytes = file.bytes;
    if (bytes == null) {
      _showError(StateError('Unable to read ${file.name}'));
      return;
    }
    try {
      final package = const PluginPackageReader().read(
        bytes,
        fileName: file.name,
      );
      final updating = _plugins.any(
        (plugin) => plugin['id']?.toString() == package.manifest.id,
      );
      if (!await _confirmPluginInstall(
        name: package.manifest.name,
        permissions: package.manifest.permissions,
        updating: updating,
      )) {
        return;
      }
      await _execute(
        ZeroBoxCommand(
          method: 'plugin.install',
          params: {'bytes': base64Encode(bytes), 'fileName': file.name},
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    }
  }

  Future<void> _loadMarket({bool force = false}) async {
    if (_marketLoading || (!force && _marketPlugins.isNotEmpty)) return;
    setState(() {
      _marketLoading = true;
      _marketError = null;
    });
    try {
      final plugins = await AbV1PluginStore(ref.read(appDioProvider)).load();
      if (mounted) {
        setState(() => _marketPlugins = plugins);
        unawaited(_loadMarketIcons(plugins));
      }
    } catch (error) {
      if (mounted) setState(() => _marketError = error);
    } finally {
      if (mounted) setState(() => _marketLoading = false);
    }
  }

  Future<void> _loadMarketIcons(List<StorePlugin> plugins) async {
    final store = AbV1PluginStore(ref.read(appDioProvider));
    final icons = await Future.wait(plugins.map(store.loadIcon));
    if (!mounted) return;
    setState(() {
      final byKey = <String, Uint8List?>{
        for (var index = 0; index < plugins.length; index++)
          _marketPluginKey(plugins[index]): icons[index],
      };
      _marketPlugins = _marketPlugins
          .map(
            (plugin) =>
                plugin.copyWith(iconBytes: byKey[_marketPluginKey(plugin)]),
          )
          .toList(growable: false);
    });
  }

  Future<void> _installMarketPlugin(StorePlugin plugin) async {
    final installedVersion = _plugins
        .where((installed) => installed['name']?.toString() == plugin.name)
        .map((installed) => installed['version']?.toString())
        .firstOrNull;
    final updating = installedVersion != null;
    if (!await _confirmPluginInstall(
      name: plugin.name,
      permissions: plugin.permissions,
      updating: updating,
    )) {
      return;
    }
    final key = _marketPluginKey(plugin);
    setState(() => _installing.add(key));
    try {
      final bytes = await AbV1PluginStore(
        ref.read(appDioProvider),
      ).download(plugin);
      await _execute(
        ZeroBoxCommand(
          method: 'plugin.install',
          params: {
            'bytes': base64Encode(bytes),
            'fileName': '${plugin.name}.abp',
          },
        ),
      );
      await _load();
    } catch (error) {
      if (mounted) _showError(error);
    } finally {
      if (mounted) setState(() => _installing.remove(key));
    }
  }

  Future<bool> _confirmPluginInstall({
    required String name,
    required List<String> permissions,
    required bool updating,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              updating
                  ? l10n.pluginUpdateConfirmTitle
                  : l10n.pluginInstallConfirmTitle,
            ),
            content: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  Text(l10n.pluginDeclaredPermissions),
                  const SizedBox(height: 8),
                  if (permissions.isEmpty)
                    Text(
                      l10n.pluginNoPermissions,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  else
                    ...permissions.map(
                      (permission) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            const Icon(Icons.circle, size: 7),
                            const SizedBox(width: 8),
                            Expanded(child: Text(permission)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(l10n.cancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(updating ? l10n.update : l10n.install),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _marketPluginKey(StorePlugin plugin) =>
      '${plugin.repositoryUrl}|${plugin.folder}';

  Future<void> _exitSafeMode() async {
    await _execute(
      const ZeroBoxCommand(
        method: 'plugin.safeMode.set',
        params: {'enabled': false},
      ),
    );
    if (mounted) setState(() => _safeMode = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final query = _query.trim().toLowerCase();
    final visiblePlugins = query.isEmpty
        ? _plugins
        : _plugins
              .where((plugin) {
                return [
                  plugin['name'],
                  plugin['description'],
                  plugin['author'],
                ].any(
                  (value) =>
                      value?.toString().toLowerCase().contains(query) ?? false,
                );
              })
              .toList(growable: false);
    final visibleMarketPlugins = query.isEmpty
        ? _marketPlugins
        : _marketPlugins
              .where(
                (plugin) => [
                  plugin.name,
                  plugin.description,
                  plugin.author,
                ].any((value) => value.toLowerCase().contains(query)),
              )
              .toList(growable: false);
    return Scaffold(
      appBar: SysAppBar(
        title: Text(l10n.pluginsTab),
        actions: [
          IconButton(
            onPressed: _importPlugin,
            icon: const Icon(Icons.add_box_outlined),
            tooltip: l10n.pluginImport,
          ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
            tooltip: l10n.refresh,
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = useWideLayout(constraints.maxWidth);
          final catalog = _PluginCatalog(
            section: _section,
            loading: _loading,
            plugins: visiblePlugins,
            marketPlugins: visibleMarketPlugins,
            marketLoading: _marketLoading,
            marketError: _marketError,
            installedVersions: {
              for (final plugin in _plugins)
                if (plugin['name'] != null && plugin['version'] != null)
                  plugin['name'].toString(): plugin['version'].toString(),
            },
            installing: _installing,
            selectedPluginId: wide ? _selectedPluginId : null,
            emptyText: l10n.pluginEmpty,
            marketUnavailableText: l10n.pluginMarketUnavailable,
            installedLabel: l10n.pluginInstalled,
            marketLabel: l10n.pluginMarket,
            onQueryChanged: (value) => setState(() => _query = value),
            onSectionChanged: (value) {
              setState(() => _section = value);
              if (value == 1) _loadMarket();
            },
            onRefreshMarket: () => _loadMarket(force: true),
            onInstall: _installMarketPlugin,
            onOpen: (id) {
              if (wide) {
                setState(() => _selectedPluginId = id);
              } else {
                context.push('/plugins/$id');
              }
            },
          );
          return PageContainer(
            maxWidth: wide ? 1280 : 1000,
            padding: const EdgeInsets.symmetric(
              horizontal: StyleConstants.pagePadding,
            ),
            child: Column(
              children: [
                if (_safeMode) ...[
                  _PluginSafeModeBanner(onExit: _exitSafeMode),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: Row(
                    children: [
                      if (wide)
                        SizedBox(width: 360, child: catalog)
                      else
                        Expanded(child: catalog),
                      if (wide) ...[
                        const SizedBox(width: 24),
                        Expanded(
                          child: _selectedPluginId == null
                              ? _PluginSelectionPlaceholder(
                                  text: l10n.pluginSelectHint,
                                )
                              : PluginDetailPage(
                                  key: ValueKey(_selectedPluginId),
                                  pluginId: _selectedPluginId!,
                                  embedded: true,
                                  onClose: () =>
                                      setState(() => _selectedPluginId = null),
                                  onRemoved: _load,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<Object?> _execute(ZeroBoxCommand command) async {
    final result = await ref.read(applicationHostProvider).execute(command);
    if (!result.ok) {
      throw StateError('${result.error!.code}: ${result.error!.message}');
    }
    return result.value;
  }

  void _showError(Object error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error.toString())));
  }
}

class _PluginSafeModeBanner extends StatelessWidget {
  const _PluginSafeModeBanner({required this.onExit});

  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colors.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.shield_outlined, color: colors.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.pluginSafeModeTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(l10n.pluginSafeModeDescription),
                ],
              ),
            ),
            TextButton(onPressed: onExit, child: Text(l10n.pluginSafeModeExit)),
          ],
        ),
      ),
    );
  }
}

class _PluginCatalog extends StatelessWidget {
  const _PluginCatalog({
    required this.section,
    required this.loading,
    required this.plugins,
    required this.marketPlugins,
    required this.marketLoading,
    required this.marketError,
    required this.installedVersions,
    required this.installing,
    required this.selectedPluginId,
    required this.emptyText,
    required this.marketUnavailableText,
    required this.installedLabel,
    required this.marketLabel,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.onRefreshMarket,
    required this.onInstall,
    required this.onOpen,
  });

  final int section;
  final bool loading;
  final List<Map<String, Object?>> plugins;
  final List<StorePlugin> marketPlugins;
  final bool marketLoading;
  final Object? marketError;
  final Map<String, String> installedVersions;
  final Set<String> installing;
  final String? selectedPluginId;
  final String emptyText;
  final String marketUnavailableText;
  final String installedLabel;
  final String marketLabel;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSectionChanged;
  final VoidCallback onRefreshMarket;
  final ValueChanged<StorePlugin> onInstall;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(
              value: 0,
              label: Text(installedLabel),
              icon: const Icon(Icons.extension_outlined),
            ),
            ButtonSegment(
              value: 1,
              label: Text(marketLabel),
              icon: const Icon(Icons.storefront_outlined),
            ),
          ],
          selected: {section},
          onSelectionChanged: (value) => onSectionChanged(value.first),
        ),
        const SizedBox(height: 12),
        SearchBar(
          elevation: const WidgetStatePropertyAll(0),
          leading: const Icon(Icons.search),
          hintText: AppLocalizations.of(context)!.search,
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        Expanded(
          child: section == 0
              ? _InstalledPlugins(
                  loading: loading,
                  plugins: plugins,
                  selectedPluginId: selectedPluginId,
                  onOpen: onOpen,
                  emptyText: emptyText,
                )
              : _PluginMarket(
                  loading: marketLoading,
                  error: marketError,
                  plugins: marketPlugins,
                  installedVersions: installedVersions,
                  installing: installing,
                  emptyText: marketUnavailableText,
                  onRefresh: onRefreshMarket,
                  onInstall: onInstall,
                ),
        ),
      ],
    );
  }
}

class _InstalledPlugins extends StatelessWidget {
  const _InstalledPlugins({
    required this.loading,
    required this.plugins,
    required this.selectedPluginId,
    required this.onOpen,
    required this.emptyText,
  });

  final bool loading;
  final List<Map<String, Object?>> plugins;
  final String? selectedPluginId;
  final ValueChanged<String> onOpen;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.extension_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(emptyText),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: plugins.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final plugin = plugins[index];
        return _PluginCard(
          plugin: plugin,
          onTap: () => onOpen(plugin['id']!.toString()),
        );
      },
    );
  }
}

class _PluginCard extends StatelessWidget {
  const _PluginCard({required this.plugin, required this.onTap});

  final Map<String, Object?> plugin;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: color.surfaceContainerHighest.withValues(alpha: .5),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _PluginIcon(base64: plugin['icon']?.toString(), size: 56),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plugin['name']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      plugin['description']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: color.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PluginSelectionPlaceholder extends StatelessWidget {
  const _PluginSelectionPlaceholder({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.extension_outlined,
            size: 56,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(text),
        ],
      ),
    );
  }
}

class _PluginMarket extends StatelessWidget {
  const _PluginMarket({
    required this.loading,
    required this.error,
    required this.plugins,
    required this.installedVersions,
    required this.installing,
    required this.emptyText,
    required this.onRefresh,
    required this.onInstall,
  });

  final bool loading;
  final Object? error;
  final List<StorePlugin> plugins;
  final Map<String, String> installedVersions;
  final Set<String> installing;
  final String emptyText;
  final VoidCallback onRefresh;
  final ValueChanged<StorePlugin> onInstall;

  @override
  Widget build(BuildContext context) {
    if (loading && plugins.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null && plugins.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(error.toString(), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.refresh),
            ),
          ],
        ),
      );
    }
    if (plugins.isEmpty) return Center(child: Text(emptyText));
    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: plugins.length,
        separatorBuilder: (_, _) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final plugin = plugins[index];
          final key = '${plugin.repositoryUrl}|${plugin.folder}';
          final isInstalling = installing.contains(key);
          final installedVersion = installedVersions[plugin.name];
          final updateAvailable =
              installedVersion != null &&
              comparePluginVersions(plugin.version, installedVersion) > 0;
          final installed = installedVersion != null && !updateAvailable;
          return Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: plugin.iconBytes == null
                        ? const SizedBox(
                            width: 56,
                            height: 56,
                            child: Icon(Icons.extension_outlined),
                          )
                        : Image.memory(
                            plugin.iconBytes!,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => const SizedBox(
                              width: 56,
                              height: 56,
                              child: Icon(Icons.extension_outlined),
                            ),
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plugin.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Text(
                          '${plugin.author} · ${plugin.version}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  isInstalling
                      ? IconButton.filledTonal(
                          onPressed: null,
                          icon: const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filledTonal(
                          onPressed: installed ? null : () => onInstall(plugin),
                          icon: Icon(
                            installed
                                ? Icons.check_rounded
                                : updateAvailable
                                ? Icons.upgrade_rounded
                                : Icons.add_rounded,
                          ),
                          tooltip: installed
                              ? AppLocalizations.of(context)!.pluginUpToDate
                              : updateAvailable
                              ? AppLocalizations.of(context)!.update
                              : AppLocalizations.of(context)!.install,
                        ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class PluginIcon extends _PluginIcon {
  const PluginIcon({super.key, required super.base64, required super.size});
}

class _PluginIcon extends StatelessWidget {
  const _PluginIcon({super.key, required this.base64, required this.size});

  final String? base64;
  final double size;

  @override
  Widget build(BuildContext context) {
    final data = base64;
    Uint8List? bytes;
    if (data != null) {
      try {
        bytes = base64Decode(data);
      } on FormatException {
        bytes = null;
      }
    }
    Widget fallback(BuildContext context) => ColoredBox(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: Icon(
        Icons.extension,
        color: Theme.of(context).colorScheme.onSecondaryContainer,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.22),
      child: SizedBox.square(
        dimension: size,
        child: bytes == null
            ? fallback(context)
            : Image.memory(
                bytes,
                fit: BoxFit.cover,
                errorBuilder: (context, _, _) => fallback(context),
              ),
      ),
    );
  }
}
