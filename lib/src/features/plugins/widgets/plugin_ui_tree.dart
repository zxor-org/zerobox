import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:zerobox/src/app/generated/app_localizations.dart';
import 'package:zerobox/src/features/resources/widgets/community_html_content.dart';

/// Recursively renders a ZeroBox plugin UI tree.
///
/// Accepts either the new tree format `{type, props, children}`
/// or a legacy flat list (auto-wrapped in Column by the backend).
class PluginUITree extends StatelessWidget {
  const PluginUITree({super.key, required this.root, required this.onInvoke});

  final Object? root;
  final Future<void> Function(String callback, [String? value]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final tree = _unwrap(root);
    if (tree == null) {
      return Center(
        child: Text(AppLocalizations.of(context)!.pluginNoFeatures),
      );
    }
    return SingleChildScrollView(child: _buildNode(context, tree));
  }

  Map<String, Object?>? _unwrap(Object? value) {
    if (value is List) {
      // Legacy flat list — backend already wrapped in Column, so first is tree
      if (value.isEmpty) return null;
      final first = value.firstOrNull;
      if (first is Map) return first.cast<String, Object?>();
      return null;
    }
    if (value is Map) return value.cast<String, Object?>();
    return null;
  }

  Widget _buildNode(BuildContext context, Map<String, Object?> node) {
    final type = node['type']?.toString() ?? 'SizedBox';
    final props = (node['props'] as Map?)?.cast<String, Object?>() ?? const {};
    final raw = node['children'];
    final children = raw is List
        ? raw
              .whereType<Map>()
              .map((c) => _buildNode(context, c.cast<String, Object?>()))
              .toList(growable: false)
        : <Widget>[];

    final visible = props['visible'] != false;
    if (!visible) return const SizedBox.shrink();

    Widget child = switch (type) {
      'Column' => _Column(props: props, children: children),
      'Row' => _Row(props: props, children: children),
      'LazyColumn' => _LazyColumn(props: props, children: children),
      'Spacer' => const _PluginSpacer(),
      'Text' => _Text(props: props),
      'HtmlDocument' => _Html(props: props),
      'Button' => _Button(props: props, onInvoke: onInvoke),
      'TextField' => _TextField(props: props, onInvoke: onInvoke),
      'Switch' => _Switch(props: props, onInvoke: onInvoke),
      'Checkbox' => _Checkbox(props: props, onInvoke: onInvoke),
      'Slider' => _Slider(props: props, onInvoke: onInvoke),
      'Dropdown' => _Dropdown(props: props, onInvoke: onInvoke),
      'Image' => _Image(props: props),
      'Card' => _Card(
        props: props,
        child: children.isNotEmpty ? children.first : const SizedBox.shrink(),
      ),
      'Divider' => _Divider(props: props),
      'Badge' => _Badge(
        props: props,
        child: children.isNotEmpty ? children.first : const SizedBox.shrink(),
      ),
      'CircularProgress' => _CircularProgress(props: props),
      'LinearProgress' => _LinearProgress(props: props),
      'Modal' => _Modal(
        props: props,
        onInvoke: onInvoke,
        child: children.isNotEmpty ? children.first : const SizedBox.shrink(),
      ),
      'Tooltip' => _Tooltip(
        props: props,
        child: children.isNotEmpty ? children.first : const SizedBox.shrink(),
      ),
      'Tabs' => _Tabs(props: props, onInvoke: onInvoke, children: children),
      'TabContent' => _TabContent(
        props: props,
        child: children.isNotEmpty ? children.first : const SizedBox.shrink(),
      ),
      _ => const SizedBox.shrink(),
    };

    if (props['disabled'] == true) {
      child = AbsorbPointer(child: child);
    }
    if (props['opacity'] != null) {
      child = Opacity(
        opacity: (_num(props, 'opacity') ?? 1.0).clamp(0, 1),
        child: child,
      );
    }
    return child;
  }
}

double? _num(Map<String, Object?> props, String key) {
  final v = props[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v);
  return null;
}

int? _int(Map<String, Object?> props, String key) {
  final v = props[key];
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

EdgeInsetsGeometry _parseEdgeInsets(Map<String, Object?> props) {
  final p = double.tryParse(props['padding']?.toString() ?? '');
  if (p != null && p > 0) return EdgeInsets.all(p);
  return EdgeInsets.zero;
}

class _Column extends StatelessWidget {
  const _Column({required this.props, required this.children});
  final Map<String, Object?> props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = _num(props, 'gap') ?? 0;
    final cross = switch (props['align']?.toString()) {
      'start' => CrossAxisAlignment.start,
      'end' => CrossAxisAlignment.end,
      'center' => CrossAxisAlignment.center,
      _ => CrossAxisAlignment.center,
    };
    var separated = gap > 0
        ? children
              .expand((widget) => [widget, SizedBox(width: gap, height: gap)])
              .toList()
        : children.toList();
    if (separated.isNotEmpty && gap > 0) separated.removeLast();
    separated = separated
        .map(
          (widget) =>
              widget is _PluginSpacer ? SizedBox(height: widget.size) : widget,
        )
        .toList(growable: false);
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Column(
        crossAxisAlignment: cross,
        mainAxisSize: MainAxisSize.min,
        children: separated,
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.props, required this.children});
  final Map<String, Object?> props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = _num(props, 'gap') ?? 0;
    var separated = gap > 0
        ? children
              .expand((widget) => [widget, SizedBox(width: gap, height: gap)])
              .toList()
        : children.toList();
    if (separated.isNotEmpty && gap > 0) separated.removeLast();
    separated = separated
        .map(
          (widget) => widget is _PluginSpacer
              ? Expanded(child: SizedBox(width: widget.size))
              : widget,
        )
        .toList(growable: false);
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: separated,
      ),
    );
  }
}

class _PluginSpacer extends StatelessWidget {
  const _PluginSpacer();

  double get size => 16;

  @override
  Widget build(BuildContext context) => SizedBox(width: size, height: size);
}

class _LazyColumn extends StatelessWidget {
  const _LazyColumn({required this.props, required this.children});
  final Map<String, Object?> props;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final gap = _num(props, 'gap') ?? 0;
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: _parseEdgeInsets(props),
      itemCount: children.length,
      itemBuilder: (_, i) => children[i],
      separatorBuilder: gap > 0
          ? (_, _) => SizedBox(width: gap, height: gap)
          : (_, _) => const SizedBox.shrink(),
    );
  }
}

class _Text extends StatelessWidget {
  const _Text({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final value = props['value']?.toString() ?? '';
    final size = _num(props, 'size');
    final color =
        _parseColor(props['color']?.toString()) ??
        _parseColor(props['text-color']?.toString());
    final weight = switch (props['weight']?.toString()) {
      'bold' => FontWeight.w700,
      'medium' => FontWeight.w500,
      _ => FontWeight.w400,
    };
    final align = switch (props['align']?.toString()) {
      'center' => TextAlign.center,
      'end' => TextAlign.end,
      _ => TextAlign.start,
    };
    final maxLines = _int(props, 'maxLines');
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Text(
        value,
        style: TextStyle(fontSize: size, color: color, fontWeight: weight),
        textAlign: align,
        maxLines: maxLines,
        overflow: maxLines != null ? TextOverflow.ellipsis : null,
      ),
    );
  }
}

class _Html extends StatelessWidget {
  const _Html({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final html = props['value']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: CommunityHtmlContent(html: html),
    );
  }
}

class _Button extends StatelessWidget {
  const _Button({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final label = props['text']?.toString() ?? '';
    final onClick = props['onClick']?.toString() ?? '';
    final primary = props['primary'] == true;
    final child = primary
        ? FilledButton(
            onPressed: onClick.isEmpty ? null : () => onInvoke(onClick),
            child: Text(label),
          )
        : FilledButton.tonal(
            onPressed: onClick.isEmpty ? null : () => onInvoke(onClick),
            child: Text(label),
          );
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Center(child: child),
    );
  }
}

class _TextField extends StatefulWidget {
  const _TextField({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  State<_TextField> createState() => _TextFieldState();
}

class _TextFieldState extends State<_TextField> {
  late final TextEditingController _ctrl;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(
      text: widget.props['value']?.toString() ?? '',
    );
    _focus = FocusNode()..addListener(_onBlur);
  }

  @override
  void didUpdateWidget(covariant _TextField old) {
    super.didUpdateWidget(old);
    if (!_focus.hasFocus) {
      final newValue = widget.props['value']?.toString() ?? '';
      if (_ctrl.text != newValue) _ctrl.text = newValue;
    }
  }

  void _onBlur() {
    if (!_focus.hasFocus) {
      final cb = widget.props['onChange']?.toString() ?? '';
      if (cb.isNotEmpty) widget.onInvoke(cb, _ctrl.text);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_onBlur);
    _focus.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final placeholder = widget.props['placeholder']?.toString();
    final multiline = widget.props['multiline'] == true;
    return Padding(
      padding: _parseEdgeInsets(widget.props),
      child: TextField(
        controller: _ctrl,
        focusNode: _focus,
        maxLines: multiline ? null : 1,
        decoration: placeholder != null
            ? InputDecoration(
                hintText: placeholder,
                border: const OutlineInputBorder(),
              )
            : null,
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  const _Switch({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final checked = props['checked'] == true;
    final onChange = props['onChange']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Switch(
        value: checked,
        onChanged: onChange.isEmpty
            ? null
            : (v) => onInvoke(onChange, v.toString()),
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final checked = props['checked'] == true;
    final label = props['label']?.toString();
    final onChange = props['onChange']?.toString() ?? '';
    final cb = Checkbox(
      value: checked,
      onChanged: onChange.isEmpty
          ? null
          : (v) => onInvoke(onChange, v.toString()),
    );
    if (label == null) {
      return Padding(padding: _parseEdgeInsets(props), child: cb);
    }
    return Padding(
      padding: _parseEdgeInsets(props),
      child: InkWell(
        onTap: onChange.isEmpty
            ? null
            : () => onInvoke(onChange, (!checked).toString()),
        child: Row(mainAxisSize: MainAxisSize.min, children: [cb, Text(label)]),
      ),
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(props['value']?.toString() ?? '') ?? 0;
    final min = double.tryParse(props['min']?.toString() ?? '') ?? 0;
    final max = double.tryParse(props['max']?.toString() ?? '') ?? 1;
    final onChange = props['onChange']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Slider(
        value: value.clamp(min, max),
        min: min,
        max: max,
        onChanged: onChange.isEmpty
            ? null
            : (v) => onInvoke(onChange, v.toString()),
      ),
    );
  }
}

class _Dropdown extends StatelessWidget {
  const _Dropdown({required this.props, required this.onInvoke});
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;

  @override
  Widget build(BuildContext context) {
    final value = props['value']?.toString();
    final options =
        (props['options'] as List?)?.map((o) => o.toString()).toList() ??
        const <String>[];
    final onChange = props['onChange']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: DropdownMenu<String>(
        initialSelection: value != null && options.contains(value)
            ? value
            : null,
        dropdownMenuEntries: options
            .map((o) => DropdownMenuEntry(value: o, label: o))
            .toList(),
        onSelected: onChange.isEmpty ? null : (v) => onInvoke(onChange, v),
      ),
    );
  }
}

class _Image extends StatelessWidget {
  const _Image({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final encoded = props['data']?.toString() ?? '';
    final width = _num(props, 'width');
    final height = _num(props, 'height');
    final radius = _num(props, 'radius') ?? 0;
    if (encoded.isEmpty) return const SizedBox.shrink();
    Uint8List bytes;
    try {
      bytes = base64Decode(encoded);
    } on FormatException {
      return const SizedBox.shrink();
    }
    final fit = switch (props['fit']?.toString()) {
      'contain' => BoxFit.contain,
      'fill' => BoxFit.fill,
      'fitWidth' => BoxFit.fitWidth,
      'fitHeight' => BoxFit.fitHeight,
      'none' => BoxFit.none,
      'scaleDown' => BoxFit.scaleDown,
      _ => BoxFit.cover,
    };
    return Padding(
      padding: _parseEdgeInsets(props),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.memory(
          bytes,
          width: width,
          height: height ?? width ?? 64,
          fit: fit,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.props, required this.child});
  final Map<String, Object?> props;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Card(
        elevation: 0,
        color: Theme.of(
          context,
        ).colorScheme.surfaceContainerHighest.withValues(alpha: .5),
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final thickness = _num(props, 'thickness');
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Divider(thickness: thickness),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.props, required this.child});
  final Map<String, Object?> props;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final count = _int(props, 'count');
    return Badge(
      label: count != null ? Text(count > 99 ? '99+' : count.toString()) : null,
      child: child,
    );
  }
}

class _CircularProgress extends StatelessWidget {
  const _CircularProgress({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final size = _num(props, 'size');
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Center(
        child: SizedBox(
          width: size,
          height: size,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _LinearProgress extends StatelessWidget {
  const _LinearProgress({required this.props});
  final Map<String, Object?> props;

  @override
  Widget build(BuildContext context) {
    final value = double.tryParse(props['value']?.toString() ?? '') ?? 0;
    final max = double.tryParse(props['max']?.toString() ?? '') ?? 1;
    return Padding(
      padding: _parseEdgeInsets(props),
      child: LinearProgressIndicator(value: max > 0 ? value / max : 0),
    );
  }
}

class _Modal extends StatelessWidget {
  const _Modal({
    required this.props,
    required this.onInvoke,
    required this.child,
  });
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final title = props['title']?.toString();
    final onDismiss = props['onDismiss']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Center(
        child: OutlinedButton(
          onPressed: () async {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: title != null ? Text(title) : null,
                content: child,
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      if (onDismiss.isNotEmpty) onInvoke(onDismiss);
                    },
                    child: Text(AppLocalizations.of(context)!.close),
                  ),
                ],
              ),
            );
          },
          child: Text(title ?? AppLocalizations.of(context)!.open),
        ),
      ),
    );
  }
}

class _Tooltip extends StatelessWidget {
  const _Tooltip({required this.props, required this.child});
  final Map<String, Object?> props;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final text = props['text']?.toString() ?? '';
    return Padding(
      padding: _parseEdgeInsets(props),
      child: Tooltip(message: text, child: child),
    );
  }
}

class _Tabs extends StatefulWidget {
  const _Tabs({
    required this.props,
    required this.onInvoke,
    required this.children,
  });
  final Map<String, Object?> props;
  final Future<void> Function(String, [String?]) onInvoke;
  final List<Widget> children;

  @override
  State<_Tabs> createState() => _TabsState();
}

class _TabsState extends State<_Tabs> with SingleTickerProviderStateMixin {
  late TabController _controller;

  @override
  void initState() {
    super.initState();
    final tabs =
        (widget.props['tabs'] as List?)
            ?.whereType<Map>()
            .map((t) => t.cast<String, Object?>())
            .toList() ??
        const [];
    _controller = TabController(length: tabs.length, vsync: this);
  }

  @override
  void didUpdateWidget(covariant _Tabs oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldLength = (oldWidget.props['tabs'] as List?)?.length ?? 0;
    final newLength = (widget.props['tabs'] as List?)?.length ?? 0;
    if (oldLength == newLength) return;
    _controller.dispose();
    _controller = TabController(length: newLength, vsync: this);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tabs =
        (widget.props['tabs'] as List?)
            ?.whereType<Map>()
            .map((t) => t.cast<String, Object?>())
            .toList() ??
        const [];
    final onChange = widget.props['onChange']?.toString() ?? '';
    return TabBar(
      controller: _controller,
      isScrollable: widget.props['scrollable'] == true,
      tabAlignment: widget.props['scrollable'] == true
          ? TabAlignment.start
          : TabAlignment.fill,
      onTap: (i) {
        final id = tabs[i]['id']?.toString() ?? '';
        if (onChange.isNotEmpty) widget.onInvoke(onChange, id);
      },
      tabs: tabs.map((t) => Tab(text: t['label']?.toString() ?? '')).toList(),
    );
  }
}

class _TabContent extends StatelessWidget {
  const _TabContent({required this.props, required this.child});
  final Map<String, Object?> props;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final tabId = props['tabId']?.toString() ?? '';
    final activeId = props['activeId']?.toString() ?? '';
    return tabId == activeId ? child : const SizedBox.shrink();
  }
}

Color? _parseColor(String? value) {
  if (value == null || value.isEmpty) return null;
  try {
    var hex = value.replaceFirst('#', '');
    // Expand 3-char shorthand: #abc → aabbcc
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    return Color(int.parse('FF$hex', radix: 16));
  } catch (_) {
    return null;
  }
}
