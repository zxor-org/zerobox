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
import 'package:zerobox/src/core/utils/layout.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
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
  String? _selectedPluginId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    try {
      final value = await _execute(const ZeroBoxCommand(method: 'plugin.list'));
      if (!mounted) return;
      setState(() {
        _plugins = (value as List)
            .whereType<Map>()
            .map((row) => row.cast<String, Object?>())
            .toList(growable: false);
        final ids = _plugins.map((plugin) => plugin['id']?.toString()).toSet();
        if (!ids.contains(_selectedPluginId)) {
          _selectedPluginId = ids.firstOrNull;
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
      allowedExtensions: const ['abp'],
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
            selectedPluginId: wide ? _selectedPluginId : null,
            emptyText: l10n.pluginEmpty,
            marketUnavailableText: l10n.pluginMarketUnavailable,
            installedLabel: l10n.pluginInstalled,
            marketLabel: l10n.pluginMarket,
            onQueryChanged: (value) => setState(() => _query = value),
            onSectionChanged: (value) => setState(() => _section = value),
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

class _PluginCatalog extends StatelessWidget {
  const _PluginCatalog({
    required this.section,
    required this.loading,
    required this.plugins,
    required this.selectedPluginId,
    required this.emptyText,
    required this.marketUnavailableText,
    required this.installedLabel,
    required this.marketLabel,
    required this.onQueryChanged,
    required this.onSectionChanged,
    required this.onOpen,
  });

  final int section;
  final bool loading;
  final List<Map<String, Object?>> plugins;
  final String? selectedPluginId;
  final String emptyText;
  final String marketUnavailableText;
  final String installedLabel;
  final String marketLabel;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<int> onSectionChanged;
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
              : _PluginMarketPlaceholder(text: marketUnavailableText),
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

class _PluginMarketPlaceholder extends StatelessWidget {
  const _PluginMarketPlaceholder({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.storefront_outlined,
          size: 56,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(text),
      ],
    ),
  );
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
