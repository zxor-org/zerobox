import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:zerobox/src/commands/command_protocol.dart';

class DebugLayoutInspector extends StatefulWidget {
  const DebugLayoutInspector({super.key, required this.nodes});
  final List<Map<String, Object?>> nodes;

  @override
  State<DebugLayoutInspector> createState() => _DebugLayoutInspectorState();
}

class _DebugLayoutInspectorState extends State<DebugLayoutInspector> {
  int? _selected;

  @override
  void didUpdateWidget(covariant DebugLayoutInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selected != null && _selected! >= widget.nodes.length) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.nodes.isEmpty) {
      return const Center(child: Text('This source has no layout tree'));
    }
    final selected = _selected == null ? null : widget.nodes[_selected!];
    return LayoutBuilder(
      builder: (context, constraints) {
        final tree = ListView.builder(
          itemCount: widget.nodes.length,
          itemBuilder: (context, index) {
            final node = widget.nodes[index];
            final content = (node['content'] as Map?)?.cast<String, Object?>();
            return ListTile(
              dense: true,
              selected: _selected == index,
              leading: const Icon(Icons.widgets_outlined, size: 18),
              title: Text(content?['type']?.toString() ?? 'Unknown'),
              subtitle: Text(
                node['node_id']?.toString() ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => setState(() => _selected = index),
            );
          },
        );
        final details = selected == null
            ? const Center(child: Text('Select an element'))
            : _JsonView(value: selected);
        if (constraints.maxWidth < 760) {
          return Column(
            children: [
              Expanded(child: tree),
              const Divider(height: 1),
              Expanded(child: details),
            ],
          );
        }
        return Row(
          children: [
            SizedBox(width: constraints.maxWidth * .42, child: tree),
            const VerticalDivider(width: 1),
            Expanded(child: details),
          ],
        );
      },
    );
  }
}

class DebugRuntimeInspector extends StatefulWidget {
  const DebugRuntimeInspector({
    super.key,
    required this.host,
    required this.source,
    required this.plugin,
  });

  final ZeroBoxCommandBus host;
  final String source;
  final Map<String, Object?>? plugin;

  @override
  State<DebugRuntimeInspector> createState() => _DebugRuntimeInspectorState();
}

class _DebugRuntimeInspectorState extends State<DebugRuntimeInspector> {
  Timer? _timer;
  Map<String, Object?>? _environment;
  Map<String, Object?>? _plugin;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
    _timer = Timer.periodic(const Duration(seconds: 2), (_) => _refresh());
  }

  @override
  void didUpdateWidget(covariant DebugRuntimeInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) unawaited(_refresh());
  }

  Future<void> _refresh() async {
    try {
      final environment = await _remoteEnvironment();
      final plugin = await _remotePlugin();
      if (mounted) {
        setState(() {
          _environment = environment;
          _plugin = plugin;
          _error = null;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<Map<String, Object?>> _remoteEnvironment() async {
    final result = await widget.host.execute(
      const ZeroBoxCommand(method: 'debug.runtime'),
    );
    if (!result.ok) throw StateError(result.error!.message);
    return (result.value as Map).cast<String, Object?>();
  }

  Future<Map<String, Object?>?> _remotePlugin() async {
    final id = widget.plugin?['id']?.toString();
    if (id == null) return null;
    final result = await widget.host.execute(
      ZeroBoxCommand(method: 'debug.plugin.snapshot', params: {'id': id}),
    );
    if (!result.ok) throw StateError(result.error!.message);
    return (result.value as Map).cast<String, Object?>();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) return Center(child: Text(_error.toString()));
    final environment = _environment;
    if (environment == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final sections = <(String, Object?)>[
      ('System environment', environment['system']),
      ('Host process', environment['host']),
      ('Runtime environment', environment['runtime']),
      if (_plugin != null) ('Plugin runtime', _pluginRuntime(_plugin!)),
    ];
    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (final section in sections) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Text(
                section.$1,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            _PropertyTable(value: section.$2),
          ],
        ],
      ),
    );
  }

  Map<String, Object?> _pluginRuntime(Map<String, Object?> plugin) => {
    'id': plugin['id'],
    'name': plugin['name'],
    'version': plugin['version'],
    'engine': plugin['runtime'],
    'state': plugin['state'],
    'running': plugin['running'],
    'wasmInstances': plugin['wasmInstances'],
    'runtimeState': plugin['runtimeState'],
    if (plugin['failure'] != null) 'failure': plugin['failure'],
  };
}

class DebugStorageInspector extends StatefulWidget {
  const DebugStorageInspector({
    super.key,
    required this.host,
    required this.source,
    required this.plugin,
  });

  final ZeroBoxCommandBus host;
  final String source;
  final Map<String, Object?>? plugin;

  @override
  State<DebugStorageInspector> createState() => _DebugStorageInspectorState();
}

class _DebugStorageInspectorState extends State<DebugStorageInspector> {
  List<Map<String, Object?>> _roots = const [];
  List<Map<String, Object?>> _entries = const [];
  String? _root;
  String _path = '';
  bool _loading = true;
  Object? _error;
  Map<String, Object?>? _preview;

  String? get _pluginId => widget.plugin?['id']?.toString();

  @override
  void initState() {
    super.initState();
    unawaited(_reset());
  }

  @override
  void didUpdateWidget(covariant DebugStorageInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.source != widget.source) unawaited(_reset());
  }

  Future<void> _reset() async {
    _root = null;
    _path = '';
    _preview = null;
    if (_pluginId != null) {
      _roots = const [];
      await _loadDirectory();
      return;
    }
    setState(() => _loading = true);
    final result = await widget.host.execute(
      const ZeroBoxCommand(method: 'debug.storage.roots'),
    );
    if (!mounted) return;
    if (!result.ok) {
      setState(() {
        _error = result.error!.message;
        _loading = false;
      });
      return;
    }
    _roots = (result.value as List? ?? const [])
        .whereType<Map>()
        .map((entry) => entry.cast<String, Object?>())
        .toList(growable: false);
    setState(() {
      _entries = _roots;
      _error = null;
      _loading = false;
    });
  }

  Future<void> _loadDirectory() async {
    setState(() {
      _loading = true;
      _preview = null;
    });
    final result = await widget.host.execute(
      ZeroBoxCommand(
        method: 'debug.storage.list',
        params: {
          if (_pluginId != null) 'pluginId': _pluginId,
          if (_root != null) 'root': _root,
          'path': _path,
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result.ok) {
        _entries = (result.value as List? ?? const [])
            .whereType<Map>()
            .map((entry) => entry.cast<String, Object?>())
            .toList(growable: false);
        _error = null;
      } else {
        _error = result.error!.message;
      }
      _loading = false;
    });
  }

  Future<void> _open(Map<String, Object?> entry) async {
    if (entry['isDirectory'] != true) {
      await _read(entry['path']?.toString() ?? '');
      return;
    }
    if (_pluginId == null && _root == null) {
      _root = entry['name'].toString();
      _path = '';
    } else {
      _path = entry['path']?.toString() ?? '';
    }
    await _loadDirectory();
  }

  Future<void> _read(String path) async {
    setState(() => _loading = true);
    final result = await widget.host.execute(
      ZeroBoxCommand(
        method: 'debug.storage.read',
        params: {
          if (_pluginId != null) 'pluginId': _pluginId,
          if (_root != null) 'root': _root,
          'path': path,
        },
      ),
    );
    if (!mounted) return;
    setState(() {
      if (result.ok) {
        _preview = (result.value as Map).cast<String, Object?>();
        _error = null;
      } else {
        _error = result.error!.message;
      }
      _loading = false;
    });
  }

  Future<void> _up() async {
    if (_path.isNotEmpty) {
      final parts = _path.split('/')..removeLast();
      _path = parts.join('/');
      if (_pluginId != null && _path.isEmpty) {
        await _loadDirectory();
        return;
      }
      await _loadDirectory();
      return;
    }
    if (_pluginId == null && _root != null) {
      _root = null;
      setState(() => _entries = _roots);
    }
  }

  @override
  Widget build(BuildContext context) {
    final location = _pluginId != null
        ? '${widget.plugin?['name'] ?? _pluginId}:${_path.isEmpty ? '/' : _path}'
        : _root == null
        ? 'ZeroBox host'
        : '$_root/${_path.isEmpty ? '' : _path}';
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Row(
            children: [
              IconButton(
                onPressed: _path.isNotEmpty || _root != null ? _up : null,
                icon: const Icon(Icons.arrow_upward),
                tooltip: 'Parent directory',
              ),
              Expanded(
                child: SelectableText(
                  location,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
              IconButton(
                onPressed: _loading ? null : _loadDirectory,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _storageBody()),
      ],
    );
  }

  Widget _storageBody() {
    if (_error != null) return Center(child: Text(_error.toString()));
    final files = _entries.isEmpty
        ? const Center(child: Text('Empty directory'))
        : ListView.separated(
            itemCount: _entries.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final entry = _entries[index];
              final directory = entry['isDirectory'] == true;
              return ListTile(
                dense: true,
                leading: Icon(
                  directory
                      ? Icons.folder_outlined
                      : Icons.insert_drive_file_outlined,
                  size: 20,
                ),
                title: Text(entry['name']?.toString() ?? ''),
                subtitle: entry['nativePath'] == null
                    ? null
                    : Text(
                        entry['nativePath'].toString(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                trailing: directory
                    ? const Icon(Icons.chevron_right)
                    : Text(_formatBytes(entry['size'])),
                onTap: () => _open(entry),
              );
            },
          );
    final preview = _preview;
    if (preview == null) return files;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '${preview['path']}  ·  ${_formatBytes(preview['size'])}'
            '${preview['truncated'] == true ? '  ·  preview truncated' : ''}',
            style: const TextStyle(fontFamily: 'monospace'),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SelectionArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(12),
              child: Text(
                preview['content']?.toString() ?? '',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
              ),
            ),
          ),
        ),
      ],
    );
    return LayoutBuilder(
      builder: (context, constraints) => constraints.maxWidth < 760
          ? Column(
              children: [
                Expanded(child: files),
                const Divider(height: 1),
                Expanded(child: details),
              ],
            )
          : Row(
              children: [
                SizedBox(width: constraints.maxWidth * .42, child: files),
                const VerticalDivider(width: 1),
                Expanded(child: details),
              ],
            ),
    );
  }
}

class _PropertyTable extends StatelessWidget {
  const _PropertyTable({required this.value});
  final Object? value;

  @override
  Widget build(BuildContext context) {
    final map = value;
    if (map is! Map) return _JsonView(value: map);
    final entries = map.entries.toList(growable: false);
    return Column(
      children: [
        for (final entry in entries) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 180,
                  child: Text(
                    entry.key.toString(),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: SelectableText(
                    entry.value is Map || entry.value is List
                        ? const JsonEncoder.withIndent(
                            '  ',
                          ).convert(entry.value)
                        : _propertyValue(entry.key.toString(), entry.value),
                    style: const TextStyle(fontFamily: 'monospace'),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
        ],
      ],
    );
  }

  String _propertyValue(String key, Object? value) {
    if (value is int && key.toLowerCase().contains('memory')) {
      return '${_formatBytes(value)} ($value bytes)';
    }
    return value?.toString() ?? 'null';
  }
}

class _JsonView extends StatelessWidget {
  const _JsonView({required this.value});
  final Object? value;

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: Text(
          const JsonEncoder.withIndent('  ').convert(value),
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
        ),
      ),
    ),
  );
}

String _formatBytes(Object? raw) {
  final bytes = raw is num ? raw.toDouble() : 0;
  if (bytes < 1024) return '${bytes.toInt()} B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KiB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MiB';
  }
  return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GiB';
}
