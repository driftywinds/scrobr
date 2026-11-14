import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';

/// A softly pulsing placeholder block used while content loads.
///
/// Cheaper and less distracting than a spinner per poster; the animation is
/// paused automatically when the widget is off screen (TickerMode).
class SkeletonBox extends StatefulWidget {
  const SkeletonBox({
    super.key,
    this.width,
    this.height,
    this.radius = 10,
  });

  final double? width;
  final double? height;
  final double radius;

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(kSurface, kCard, t),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        );
      },
    );
  }
}

/// Skeleton for a horizontal poster row (title + 4 cards).
class SkeletonRow extends StatelessWidget {
  const SkeletonRow({super.key, this.width = 124, this.height = 252});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: SkeletonBox(width: 140, height: 18, radius: 6),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: 4,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 2 / 3,
                    child: SkeletonBox(width: width),
                  ),
                  const SizedBox(height: 8),
                  SkeletonBox(width: width * 0.8, height: 11, radius: 4),
                  const SizedBox(height: 5),
                  SkeletonBox(width: width * 0.5, height: 9, radius: 4),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Skeleton for a vertical list of poster+text rows (history, calendar).
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 6});

  final int rows;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: rows,
      itemBuilder: (_, __) => const Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBox(width: 58, height: 87, radius: 7),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(height: 14, radius: 5),
                  SizedBox(height: 8),
                  SkeletonBox(width: 160, height: 11, radius: 5),
                  SizedBox(height: 8),
                  SkeletonBox(width: 90, height: 11, radius: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
