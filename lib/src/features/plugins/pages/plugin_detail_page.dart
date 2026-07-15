import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/app/widgets/page_container.dart';
import 'package:zerobox/src/app/widgets/sys_app_bar.dart';
import 'package:zerobox/src/commands/command_protocol.dart';
import 'package:zerobox/src/core/constants/style_constants.dart';
import 'package:zerobox/src/host/application_host_provider.dart';
import 'package:zerobox/src/features/resources/widgets/community_html_content.dart';

import 'plugins_page.dart';

class PluginDetailPage extends ConsumerStatefulWidget {
  const PluginDetailPage({
    super.key,
    required this.pluginId,
    this.embedded = false,
    this.onClose,
    this.onRemoved,
  });

  final String pluginId;
  final bool embedded;
  final VoidCallback? onClose;
  final FutureOr<void> Function()? onRemoved;

  @override
  ConsumerState<PluginDetailPage> createState() => _PluginDetailPageState();
}

class _PluginDetailPageState extends ConsumerState<PluginDetailPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  StreamSubscription<CommandEvent>? _events;
  late final ZeroBoxCommandBus _host;
  Future<void>? _loadFuture;
  Map<String, Object?>? _plugin;
  List<Map<String, Object?>> _nodes = const [];
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _host = ref.read(applicationHostProvider);
    _events = _host.events.listen(_handleEvent);
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _events?.cancel();
    _tabs.dispose();
    unawaited(_closeAfterLoad());
    super.dispose();
  }

  Future<void> _closeAfterLoad() async {
    try {
      await _loadFuture;
    } catch (_) {
      // A failed open does not leave a running plugin to close.
    }
    await _host.execute(
      ZeroBoxCommand(method: 'plugin.close', params: {'id': widget.pluginId}),
    );
  }

  Future<void> _load() async {
    try {
      final detail =
          (await _execute(
                    ZeroBoxCommand(
                      method: 'plugin.get',
                      params: {'id': widget.pluginId},
                    ),
                  )
                  as Map)
              .cast<String, Object?>();
      if (mounted) setState(() => _plugin = detail);
      final nodes = await _execute(
        ZeroBoxCommand(method: 'plugin.open', params: {'id': widget.pluginId}),
      );
      if (mounted) {
        setState(() {
          _nodes = _nodeList(nodes);
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _handleEvent(CommandEvent event) {
    if (event.event == 'plugin.ui' &&
        event.data['id']?.toString() == widget.pluginId) {
      final nodes = _nodeList(event.data['nodes']);
      if (event.data['page'] == true) {
        unawaited(_openNodePage(nodes));
      } else if (mounted) {
        setState(() => _nodes = nodes);
      }
      return;
    }
  }

  Future<void> _invoke(String callback, [String? value]) async {
    try {
      final nodes = await _execute(
        ZeroBoxCommand(
          method: 'plugin.invoke',
          params: {
            'id': widget.pluginId,
            'callback': callback,
            if (value != null) 'value': value,
          },
        ),
      );
      if (mounted) setState(() => _nodes = _nodeList(nodes));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  Future<void> _openNodePage(List<Map<String, Object?>> nodes) async {
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (context) => _PluginNodePage(
          title:
              _plugin?['name']?.toString() ??
              AppLocalizations.of(context)!.pluginFeatures,
          nodes: nodes,
          onInvoke: _invoke,
        ),
      ),
    );
  }

  Future<void> _remove() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.pluginUninstallTitle),
        content: Text(l10n.pluginUninstallMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.uninstall),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _execute(
      ZeroBoxCommand(method: 'plugin.remove', params: {'id': widget.pluginId}),
    );
    await widget.onRemoved?.call();
    if (mounted && !widget.embedded) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final plugin = _plugin;
    final content = plugin == null
        ? Center(
            child: _error == null
                ? const CircularProgressIndicator()
                : Text(_error.toString()),
          )
        : Column(
            children: [
              _PluginHeader(
                plugin: plugin,
                tabs: _tabs,
                onClose: widget.embedded ? widget.onClose : null,
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _PluginFeatureView(nodes: _nodes, onInvoke: _invoke),
                    _PluginInformation(plugin: plugin, onUninstall: _remove),
                  ],
                ),
              ),
            ],
          );
    if (widget.embedded) return content;
    return Scaffold(
      appBar: SysAppBar(
        secondary: true,
        title: Text(plugin?['name']?.toString() ?? l10n.pluginDetails),
      ),
      body: PageContainer(
        padding: const EdgeInsets.symmetric(
          horizontal: StyleConstants.pagePadding,
        ),
        child: content,
      ),
    );
  }

  Future<Object?> _execute(ZeroBoxCommand command) async {
    final result = await _host.execute(command);
    if (!result.ok) {
      throw StateError('${result.error!.code}: ${result.error!.message}');
    }
    return result.value;
  }

  List<Map<String, Object?>> _nodeList(Object? value) =>
      (value as List?)
          ?.whereType<Map>()
          .map((node) => node.cast<String, Object?>())
          .toList(growable: false) ??
      const [];
}

class _PluginHeader extends StatelessWidget {
  const _PluginHeader({required this.plugin, required this.tabs, this.onClose});
  final Map<String, Object?> plugin;
  final TabController tabs;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final description = plugin['description']?.toString() ?? '';
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                onClose != null ? 48 : 16,
                12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  PluginIcon(base64: plugin['icon']?.toString(), size: 72),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plugin['name']?.toString() ?? '',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            description,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: color.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: tabs,
              dividerHeight: 0,
              tabs: [
                Tab(text: l10n.pluginFeatures),
                Tab(text: l10n.pluginDetails),
              ],
            ),
          ],
        ),
        if (onClose != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: onClose,
              icon: const Icon(Icons.close),
              visualDensity: VisualDensity.compact,
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ),
      ],
    );
  }
}

class _PluginFeatureView extends StatelessWidget {
  const _PluginFeatureView({required this.nodes, required this.onInvoke});
  final List<Map<String, Object?>> nodes;
  final Future<void> Function(String callback, [String? value]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final visible = nodes.where((node) => node['visibility'] != false).toList();
    if (visible.isEmpty) {
      return Center(
        child: Text(AppLocalizations.of(context)!.pluginNoFeatures),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      itemCount: visible.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final node = visible[index];
        final content =
            (node['content'] as Map?)?.cast<String, Object?>() ?? const {};
        final type = content['type']?.toString();
        final value = content['value'];
        final disabled = node['disabled'] == true;
        switch (type) {
          case 'Text':
            return Center(
              child: Text(value?.toString() ?? '', textAlign: TextAlign.center),
            );
          case 'Button':
            final button = (value as Map).cast<String, Object?>();
            final callback = button['callback_fun_id']?.toString() ?? '';
            return Center(
              child: button['primary'] == true
                  ? FilledButton(
                      onPressed: disabled ? null : () => onInvoke(callback),
                      child: Text(button['text']?.toString() ?? ''),
                    )
                  : FilledButton.tonal(
                      onPressed: disabled ? null : () => onInvoke(callback),
                      child: Text(button['text']?.toString() ?? ''),
                    ),
            );
          case 'Dropdown':
            final dropdown = (value as Map).cast<String, Object?>();
            final options =
                (dropdown['options'] as List?)
                    ?.map((item) => item.toString())
                    .toList(growable: false) ??
                const <String>[];
            return Center(
              child: DropdownMenu<String>(
                enabled: !disabled,
                dropdownMenuEntries: options
                    .map((item) => DropdownMenuEntry(value: item, label: item))
                    .toList(growable: false),
                onSelected: (selected) {
                  if (selected != null) {
                    onInvoke(
                      dropdown['callback_fun_id']?.toString() ?? '',
                      selected,
                    );
                  }
                },
              ),
            );
          case 'Input':
            final input = (value as Map).cast<String, Object?>();
            return Center(
              child: _PluginInput(
                key: ValueKey(node['node_id']),
                initialValue: input['text']?.toString() ?? '',
                enabled: !disabled,
                onSubmitted: (text) =>
                    onInvoke(input['callback_fun_id']?.toString() ?? '', text),
              ),
            );
          case 'HtmlDocument':
            return Center(
              child: CommunityHtmlContent(html: value?.toString() ?? ''),
            );
          default:
            return const SizedBox.shrink();
        }
      },
    );
  }
}

class _PluginNodePage extends StatelessWidget {
  const _PluginNodePage({
    required this.title,
    required this.nodes,
    required this.onInvoke,
  });

  final String title;
  final List<Map<String, Object?>> nodes;
  final Future<void> Function(String callback, [String? value]) onInvoke;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: SysAppBar(secondary: true, title: Text(title)),
      body: PageContainer(
        child: _PluginFeatureView(nodes: nodes, onInvoke: onInvoke),
      ),
    );
  }
}

class _PluginInput extends StatefulWidget {
  const _PluginInput({
    super.key,
    required this.initialValue,
    required this.enabled,
    required this.onSubmitted,
  });
  final String initialValue;
  final bool enabled;
  final ValueChanged<String> onSubmitted;

  @override
  State<_PluginInput> createState() => _PluginInputState();
}

class _PluginInputState extends State<_PluginInput> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focusNode = FocusNode()..addListener(_onFocusChanged);
  }

  @override
  void didUpdateWidget(covariant _PluginInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && widget.initialValue != _controller.text) {
      _controller.text = widget.initialValue;
    }
  }

  void _onFocusChanged() {
    if (!_focusNode.hasFocus) widget.onSubmitted(_controller.text);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focusNode,
    enabled: widget.enabled,
    textAlign: TextAlign.center,
  );
}

class _PluginInformation extends StatelessWidget {
  const _PluginInformation({required this.plugin, required this.onUninstall});
  final Map<String, Object?> plugin;
  final VoidCallback onUninstall;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final color = Theme.of(context).colorScheme;
    final website = plugin['website']?.toString();
    final permissions =
        (plugin['permissions'] as List?)
            ?.map((item) => item.toString())
            .toList(growable: false) ??
        const <String>[];
    return ListView(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      children: [
        _InfoGroup(
          title: l10n.pluginDetails,
          children: [
            _InfoLine(
              icon: Icons.person_outline,
              label: l10n.pluginAuthor,
              value: plugin['author']?.toString() ?? '',
            ),
            if (website != null && website.isNotEmpty)
              _InfoLine(
                icon: Icons.language,
                label: l10n.pluginWebsite,
                value: website,
                onOpen: () {
                  final uri = Uri.tryParse(website);
                  if (uri != null) launchUrl(uri);
                },
              ),
            _InfoLine(
              icon: Icons.info_outline,
              label: l10n.pluginVersion,
              value: plugin['version']?.toString() ?? '',
            ),
            _InfoLine(
              icon: Icons.numbers,
              label: l10n.pluginApiLevel,
              value: plugin['apiLevel']?.toString() ?? '',
            ),
          ],
        ),
        _InfoGroup(
          title: l10n.pluginPermissions,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: permissions
                  .map((permission) => Chip(label: Text(permission)))
                  .toList(growable: false),
            ),
          ],
        ),
        Center(
          child: FilledButton.icon(
            onPressed: onUninstall,
            icon: const Icon(Icons.delete_outline),
            label: Text(l10n.uninstall),
            style: FilledButton.styleFrom(
              backgroundColor: color.errorContainer,
              foregroundColor: color.onErrorContainer,
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoGroup extends StatelessWidget {
  const _InfoGroup({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: .5),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.icon,
    required this.label,
    required this.value,
    this.onOpen,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 12),
          SizedBox(
            width: 72,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (onOpen != null)
            InkWell(
              onTap: onOpen,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  Icons.open_in_new,
                  size: 16,
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
