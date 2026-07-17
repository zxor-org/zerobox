import 'package:flutter/material.dart';
import 'package:zerobox/src/core/logging/diagnostic_event.dart';

class DebugConsole extends StatefulWidget {
  const DebugConsole({super.key, required this.records});
  final List<DiagnosticEvent> records;

  @override
  State<DebugConsole> createState() => _DebugConsoleState();
}

class _DebugConsoleState extends State<DebugConsole> {
  final _scroll = ScrollController();
  var _followTail = true;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_trackPosition);
    _scrollToTail();
  }

  @override
  void didUpdateWidget(covariant DebugConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_followTail && oldWidget.records.length != widget.records.length) {
      _scrollToTail();
    }
  }

  void _trackPosition() {
    if (!_scroll.hasClients) return;
    _followTail =
        _scroll.position.maxScrollExtent - _scroll.position.pixels < 48;
  }

  void _scrollToTail() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted || !_scroll.hasClients) return;
    _scroll.jumpTo(_scroll.position.maxScrollExtent);
  });

  @override
  void dispose() {
    _scroll
      ..removeListener(_trackPosition)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SelectionArea(
    child: ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.symmetric(vertical: 6),
      itemCount: widget.records.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = widget.records[index];
        final color = switch (record.level.name) {
          'SEVERE' => Theme.of(context).colorScheme.error,
          'WARNING' => Colors.orange,
          _ => Theme.of(context).colorScheme.onSurface,
        };
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          child: Text(
            '${record.time.toIso8601String()}  ${record.level.name.padRight(7)} '
            '[${record.scope}] ${record.source}  ${record.message}'
            '${record.error == null ? '' : '\n${record.error}'}',
            style: TextStyle(
              color: color,
              fontFamily: 'monospace',
              fontSize: 12.5,
              height: 1.35,
            ),
          ),
        );
      },
    ),
  );
}
