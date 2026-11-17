import 'package:flutter/material.dart';

/// A horizontally swipeable set of tab bodies that follows the finger.
///
/// Dragging slides the pages 1:1 with the gesture, so you can stop mid-way and
/// see two columns side by side; releasing settles on the nearest page (or the
/// next one on a fling). Changing [index] from the outside (e.g. tapping a
/// segmented control) animates to that page.
///
/// [onIndexChanged] fires when the user's swipe crosses the halfway point, so
/// a tab bar bound to [index] follows the drag.
class SwipePages extends StatefulWidget {
  const SwipePages({
    super.key,
    required this.index,
    required this.onIndexChanged,
    required this.itemCount,
    required this.itemBuilder,
  });

  final int index;
  final ValueChanged<int> onIndexChanged;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<SwipePages> createState() => _SwipePagesState();
}

class _SwipePagesState extends State<SwipePages> {
  late final PageController _controller =
      PageController(initialPage: widget.index);
  bool _programmatic = false;

  @override
  void didUpdateWidget(SwipePages oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.index != oldWidget.index && _controller.hasClients) {
      final page = _controller.page ?? widget.index.toDouble();
      if (page.round() != widget.index) _animateTo(widget.index);
    }
  }

  Future<void> _animateTo(int index) async {
    _programmatic = true;
    try {
      await _controller.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    } finally {
      _programmatic = false;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PageView.builder(
      controller: _controller,
      itemCount: widget.itemCount,
      onPageChanged: (i) {
        if (!_programmatic) widget.onIndexChanged(i);
      },
      itemBuilder: (context, i) =>
          _KeepAlive(child: widget.itemBuilder(context, i)),
    );
  }
}

class _KeepAlive extends StatefulWidget {
  const _KeepAlive({required this.child});

  final Widget child;

  @override
  State<_KeepAlive> createState() => _KeepAliveState();
}

class _KeepAliveState extends State<_KeepAlive>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
