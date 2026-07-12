import 'package:flutter/material.dart';

/// A horizontally scrolling row of items with desktop-friendly affordances:
/// a draggable scrollbar and left/right buttons that appear when there is
/// content to scroll in that direction.
class HorizontalScroller extends StatefulWidget {
  const HorizontalScroller({
    super.key,
    required this.height,
    required this.children,
    this.spacing = 10,
  });

  final double height;
  final List<Widget> children;
  final double spacing;

  @override
  State<HorizontalScroller> createState() => _HorizontalScrollerState();
}

class _HorizontalScrollerState extends State<HorizontalScroller> {
  final _controller = ScrollController();
  bool _canScrollBack = false;
  bool _canScrollForward = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateButtons);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateButtons());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateButtons() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canBack = position.pixels > position.minScrollExtent + 1;
    final canForward = position.pixels < position.maxScrollExtent - 1;
    if (canBack != _canScrollBack || canForward != _canScrollForward) {
      setState(() {
        _canScrollBack = canBack;
        _canScrollForward = canForward;
      });
    }
  }

  void _scrollBy(double direction) {
    final step = (context.size?.width ?? 320) * 0.8;
    final position = _controller.position;
    final target = (_controller.offset + direction * step).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: widget.height + 8,
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: _canScrollBack || _canScrollForward,
            child: ListView.separated(
              controller: _controller,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.only(bottom: 8),
              itemCount: widget.children.length,
              separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
              itemBuilder: (_, index) => widget.children[index],
            ),
          ),
        ),
        if (_canScrollBack)
          Positioned(
            left: 4,
            top: 0,
            bottom: 8,
            child: Center(
              child: _ScrollButton(
                icon: Icons.chevron_left,
                onPressed: () => _scrollBy(-1),
              ),
            ),
          ),
        if (_canScrollForward)
          Positioned(
            right: 4,
            top: 0,
            bottom: 8,
            child: Center(
              child: _ScrollButton(
                icon: Icons.chevron_right,
                onPressed: () => _scrollBy(1),
              ),
            ),
          ),
      ],
    );
  }
}

class _ScrollButton extends StatelessWidget {
  const _ScrollButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerHighest.withValues(alpha: .85),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(icon, size: 22, color: colors.onSurface),
        ),
      ),
    );
  }
}
