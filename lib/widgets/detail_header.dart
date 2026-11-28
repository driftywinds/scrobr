import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'common.dart';

/// Height of a standard app bar row (same value as Material's kToolbarHeight).
const double _kBarHeight = 56;

/// Collapsing header shared by the show, movie and episode pages.
///
/// Expanded: backdrop image with the title left-aligned over its lower edge,
/// wrapping onto as many lines as it needs (never cut short).
/// Collapsed: a normal pinned app bar on solid background, with the same title
/// left-aligned next to the back button (up to two lines).
///
/// The two titles cross-fade as you scroll, so the title never sits half way
/// between the two positions the way a stock [FlexibleSpaceBar] title does.
class DetailSliverAppBar extends StatelessWidget {
  const DetailSliverAppBar({
    super.key,
    required this.title,
    this.imageUrl,
    this.actions = const [],
    this.expandedHeight = 280,
    this.showTitleOnHero = true,
  });

  /// Title shown on the hero (when [showTitleOnHero]) and in the collapsed bar.
  final String title;
  final String? imageUrl;
  final List<Widget> actions;
  final double expandedHeight;

  /// Episode pages already print the title in the page body, so they only want
  /// it in the collapsed bar.
  final bool showTitleOnHero;

  double get _heroFontSize {
    final length = title.length;
    if (length > 90) return 20;
    if (length > 50) return 22;
    return 26;
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final collapsedHeight = topInset + _kBarHeight;
    // The bar's own buttons (back on the left, actions on the right) must stay
    // clear of the collapsed title.
    final rightInset = actions.isEmpty ? 16.0 : actions.length * 48.0 + 8;

    return SliverAppBar(
      pinned: true,
      expandedHeight: expandedHeight,
      backgroundColor: kBg,
      surfaceTintColor: Colors.transparent,
      actions: actions,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          // 1 = fully expanded, 0 = fully collapsed.
          final span = expandedHeight - _kBarHeight;
          final t = span <= 0
              ? 0.0
              : ((constraints.maxHeight - collapsedHeight) / span)
                  .clamp(0.0, 1.0);
          final heroOpacity = ((t - 0.55) / 0.35).clamp(0.0, 1.0);
          final barOpacity = ((0.4 - t) / 0.3).clamp(0.0, 1.0);
          // Solid background once collapsed so the bar never shows a sliver
          // of cropped artwork behind the title.
          final veil = (1 - t * 1.6).clamp(0.0, 1.0);

          return Stack(
            fit: StackFit.expand,
            children: [
              CachedArtwork(
                url: imageUrl,
                fit: BoxFit.cover,
                placeholder: Container(color: kCard),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                      kBg.withValues(alpha: 0.55),
                      kBg,
                    ],
                    stops: const [0, 0.3, 0.75, 1],
                  ),
                ),
              ),
              Positioned.fill(
                child: ColoredBox(color: kBg.withValues(alpha: veil)),
              ),
              if (showTitleOnHero)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 14,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: heroOpacity,
                      child: ExcludeSemantics(
                        excluding: t < 0.5,
                        child: Text(
                          title,
                          textAlign: TextAlign.left,
                          style: TextStyle(
                            fontSize: _heroFontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.6,
                            height: 1.1,
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black54, blurRadius: 10),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                left: 64,
                right: rightInset,
                top: topInset,
                height: _kBarHeight,
                child: IgnorePointer(
                  child: Opacity(
                    opacity: barOpacity,
                    child: ExcludeSemantics(
                      excluding: t >= 0.5,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
