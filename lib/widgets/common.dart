import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../core/friendly_error.dart';

class Poster extends StatelessWidget {
  const Poster({
    super.key,
    required this.url,
    this.title,
    this.radius = 10,
    this.fit = BoxFit.cover,
  });

  final String? url;
  final String? title;
  final double radius;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    // Small posters (list rows, calendar) already sit next to their title, so
    // repeating it inside a 50px box only wraps it letter by letter. Show the
    // title only when there is room, and keep it out of the accessibility tree
    // either way (the visible title next to it is what gets read).
    final placeholder = ExcludeSemantics(
      child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2F2F35), Color(0xFF1C1C20)],
          ),
        ),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(6),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final roomy = constraints.maxWidth >= 96 && constraints.maxHeight >= 120;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.movie_outlined,
                  color: kMuted,
                  size: roomy ? 26 : 22,
                ),
                if (title != null && roomy) ...[
                  const SizedBox(height: 4),
                  Text(
                    truncate(title, 40),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: kMuted),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );

    // A hairline border keeps dark posters from dissolving into the page.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedArtwork(
          url: url,
          fit: fit,
          placeholder: placeholder,
        ),
      ),
    );
  }
}

/// Disk-cached network artwork. Public posters hit the server image proxy with
/// the session header; on failure we retry the public TMDB/TVDB URL without it.
class CachedArtwork extends StatelessWidget {
  const CachedArtwork({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholder,
  });

  final String? url;
  final BoxFit fit;
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final empty = placeholder ?? Container(color: kCard);
    if (url == null || url!.isEmpty) return empty;
    return CachedNetworkImage(
      imageUrl: url!,
      httpHeaders: app.imageHeaders(url),
      fit: fit,
      fadeInDuration: const Duration(milliseconds: 160),
      placeholder: (_, __) => empty,
      errorWidget: (context, failedUrl, error) {
        final direct = app.directImageUrl(failedUrl);
        if (direct == null) return empty;
        return CachedNetworkImage(
          imageUrl: direct,
          fit: fit,
          fadeInDuration: const Duration(milliseconds: 160),
          placeholder: (_, __) => empty,
          errorWidget: (_, __, ___) => empty,
        );
      },
    );
  }
}

class MediaCard extends StatelessWidget {
  const MediaCard({
    super.key,
    required this.item,
    this.width = 124,
    this.showSubtitle = true,
    this.onTap,
    this.onWatchToggle,
    this.hero = false,
  });

  final Map<String, dynamic> item;
  final double width;
  final bool showSubtitle;
  final VoidCallback? onTap;
  final Future<void> Function()? onWatchToggle;
  final bool hero;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final type = item.s('type');
    final isEpisode = type == 'episode';
    final isPerson = type == 'person';
    final posterPath = posterPathFor(item);
    final url = app.imageUrl(posterPath, size: 'w342');
    final rawTitle = item.s('title') ?? item.s('name') ?? '';
    final showTitle = item.s('show_title') ?? '';
    final title =
        isEpisode && showTitle.isNotEmpty ? showTitle : rawTitle;
    final year = yearOf(item.s('release_date') ?? item.s('first_air_date'));
    final rating = item.d('tmdb_rating');
    final watched = item.b('watched') || (item.d('play_count') ?? 0) > 0;

    String subtitle = '';
    if (isEpisode) {
      final se = [
        if (item.i('season_number') != null) 'S${item.i('season_number')}',
        if (item.i('episode_number') != null) 'E${item.i('episode_number')}',
      ].join();
      subtitle = [se, rawTitle].where((e) => e.isNotEmpty).join(' · ');
    } else if (isPerson) {
      subtitle = item.s('known_for_department') ?? 'Person';
    } else {
      subtitle = [year, type == 'series' ? 'Series' : 'Movie']
          .where((e) => e.isNotEmpty)
          .join(' · ');
    }

    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap ?? () => openMedia(context, item),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: isPerson ? 1 : 2 / 3,
                  child: Poster(
                    url: url,
                    title: title,
                    radius: isPerson ? 100 : 10,
                  ),
                ),
                if (rating != null && rating > 0 && !isPerson)
                  Positioned(
                    left: 6,
                    top: 6,
                    child: Semantics(
                      label: 'Rating ${fmtRating(rating)}',
                      excludeSemantics: true,
                      child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, size: 11, color: kAmber),
                          const SizedBox(width: 2),
                          Text(
                            fmtRating(rating),
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ),
                  ),
                if (watched && !isPerson)
                  Positioned(
                    right: 6,
                    top: 6,
                    child: Semantics(
                      label: 'Watched',
                      excludeSemantics: true,
                      child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: kGreen,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_rounded, size: 11, color: Colors.black),
                    ),
                    ),
                  ),
                if (onWatchToggle != null && !watched && !isPerson)
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.7),
                      shape: const CircleBorder(),
                      child: Tooltip(
                        message: 'Mark watched',
                        child: InkWell(
                          customBorder: const CircleBorder(),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            onWatchToggle!.call();
                          },
                          child: const Padding(
                            padding: EdgeInsets.all(4),
                            child: Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              truncate(title, 46),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                height: 1.2,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (showSubtitle && subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    required this.items,
    this.onSeeAll,
    this.onWatchToggle,
    this.width = 124,
    this.height = 252,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;
  final Future<void> Function(Map<String, dynamic>)? onWatchToggle;
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: SectionHeader(title: title, onSeeAll: onSeeAll),
        ),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => MediaCard(
              item: items[i],
              width: width,
              onWatchToggle: onWatchToggle == null
                  ? null
                  : () => onWatchToggle!(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.onSeeAll});

  final String title;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 16,
          decoration: BoxDecoration(
            gradient: kAccentGradient,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
        ),
        if (onSeeAll != null)
          InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: onSeeAll,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'See all',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kAccentSoft,
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 16, color: kAccentSoft),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    this.body,
    this.icon = Icons.movie_filter_outlined,
  });

  final String title;
  final String? body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kAccent.withValues(alpha: 0.1),
              border: Border.all(color: kAccent.withValues(alpha: 0.25)),
            ),
            child: Icon(icon, size: 32, color: kAccentSoft),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kDanger.withValues(alpha: 0.1),
              border: Border.all(color: kDanger.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.cloud_off_rounded, color: kDanger, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 13, height: 1.4),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
          ],
        ],
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});

  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          if (label != null) ...[
            const SizedBox(height: 12),
            Text(label!, style: const TextStyle(color: kMuted, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, this.height = 6});

  final double value;
  final double height;

  @override
  Widget build(BuildContext context) {
    final fraction = (value.clamp(0, 100)) / 100;
    return Semantics(
      label: '${value.clamp(0, 100).round()} percent complete',
      excludeSemantics: true,
      child: ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: Colors.white.withValues(alpha: 0.14),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.toDouble(),
          child: DecoratedBox(
            decoration: value >= 100
                ? const BoxDecoration(color: kGreen)
                : BoxDecoration(gradient: kAccentGradient),
            child: const SizedBox.expand(),
          ),
        ),
      ),
      ),
    );
  }
}

class RatingChip extends StatelessWidget {
  const RatingChip({super.key, required this.rating, this.label});

  final num? rating;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (rating == null || rating! <= 0) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kAmber.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kAmber.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.star_rounded, size: 13, color: kAmber),
          const SizedBox(width: 3),
          Text(
            label ?? fmtRating(rating),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kAmber,
            ),
          ),
        ],
      ),
    );
  }
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, this.url, this.name, this.size = 40});

  final String? url;
  final String? name;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (url == null || url!.isEmpty) {
      return CircleAvatar(
        radius: size / 2,
        backgroundColor: kAccent.withValues(alpha: 0.25),
        child: Text(
          initials(name),
          style: TextStyle(
            fontSize: size * 0.34,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CachedArtwork(
          url: url,
          fit: BoxFit.cover,
          placeholder: CircleAvatar(
            radius: size / 2,
            backgroundColor: kCard,
            child: Text(
              initials(name),
              style: TextStyle(fontSize: size * 0.32),
            ),
          ),
        ),
      ),
    );
  }
}

class FollowAction extends StatefulWidget {
  const FollowAction({
    super.key,
    required this.type,
    required this.tmdbId,
    this.onChanged,
  });

  final String type;
  final int? tmdbId;
  final VoidCallback? onChanged;

  @override
  State<FollowAction> createState() => _FollowActionState();
}

class _FollowActionState extends State<FollowAction> {
  bool _following = false;
  bool _busy = false;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    final id = widget.tmdbId;
    if (id == null) return;
    try {
      final following = await ScrobScope.of(context).isFollowing(widget.type, id);
      if (mounted) setState(() => _following = following);
    } catch (_) {
      // Keep the neutral Follow state when the list cannot be read.
    }
  }

  Future<void> _toggle() async {
    final id = widget.tmdbId;
    if (id == null || _busy) return;
    setState(() => _busy = true);
    try {
      final following = await ScrobScope.of(context).toggleFollowing(
        widget.type,
        id,
      );
      if (!mounted) return;
      setState(() => _following = following);
      widget.onChanged?.call();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update Following: ${friendlyError(e)}')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ActionPill(
      icon: _following
          ? Icons.notifications_active_rounded
          : Icons.notifications_none_rounded,
      label: _following ? 'Following' : 'Follow',
      active: _following,
      onTap: widget.tmdbId == null || _busy ? null : _toggle,
    );
  }
}

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kBorderStrong),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: kBody,
        ),
      ),
    );
  }
}


/// Pulsing placeholder block used by skeleton loaders.
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
      builder: (context, _) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(kSurface, kCard, _controller.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

/// Skeleton for a horizontal poster row (title + a few posters).
class MediaRowSkeleton extends StatelessWidget {
  const MediaRowSkeleton({super.key, this.width = 124, this.count = 4});

  final double width;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 22, 16, 12),
          child: SkeletonBox(width: 130, height: 16, radius: 6),
        ),
        SizedBox(
          height: width * 1.5 + 36,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: count,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, __) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: width, height: width * 1.5),
                const SizedBox(height: 8),
                SkeletonBox(width: width * 0.8, height: 11, radius: 4),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-screen skeleton: a hero block followed by two poster rows.
class DashboardSkeleton extends StatelessWidget {
  const DashboardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      children: const [
        Padding(
          padding: EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: SkeletonBox(radius: 18),
          ),
        ),
        MediaRowSkeleton(),
        MediaRowSkeleton(),
      ],
    );
  }
}


/// Action button used on detail pages (watched, rate, add to list…). It fills
/// whatever width it is given, so place it inside [ActionGrid].
/// [active] tints it with the accent colour so state reads at a glance.
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.primary = false,
    this.destructive = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;

  /// The one main action on a page: solid accent fill so it reads first.
  final bool primary;

  /// Bulk or irreversible actions: danger tint so they never look like a
  /// neighbour of the safe action.
  final bool destructive;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color fill;
    final Color border;
    final Color iconColor;
    final Color textColor;
    if (primary) {
      fill = kAccentSolid;
      border = kAccentSolid;
      iconColor = kAccentSolidOn;
      textColor = kAccentSolidOn;
    } else if (destructive) {
      fill = kDanger.withValues(alpha: 0.08);
      border = kDanger.withValues(alpha: 0.4);
      iconColor = kDanger;
      textColor = kDanger;
    } else if (active) {
      fill = kAccentSolid.withValues(alpha: 0.16);
      border = kAccentSolid.withValues(alpha: 0.6);
      iconColor = kAccentSoft;
      textColor = Colors.white;
    } else {
      fill = kSurface;
      border = kBorder;
      iconColor = kMuted;
      textColor = kBody;
    }
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
            height: primary ? 50 : 46,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kRadius),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: primary ? 20 : 18, color: iconColor),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: primary ? 14 : 12.5,
                      fontWeight: primary ? FontWeight.w800 : FontWeight.w700,
                      color: textColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays actions out in an even grid (equal widths and heights). A trailing
/// odd item spans the full row so nothing looks orphaned.
class ActionGrid extends StatelessWidget {
  const ActionGrid({super.key, required this.children, this.columns = 2});

  final List<Widget> children;
  final int columns;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i += columns) {
      final chunk = children.skip(i).take(columns).toList();
      if (rows.isNotEmpty) rows.add(const SizedBox(height: 8));
      rows.add(
        Row(
          children: [
            for (var k = 0; k < chunk.length; k++) ...[
              if (k > 0) const SizedBox(width: 8),
              Expanded(child: chunk[k]),
            ],
          ],
        ),
      );
    }
    return Column(children: rows);
  }
}

/// Full-width segmented control. Segments share the width equally and labels
/// shrink to fit, so it never overflows or hugs the left edge.
/// API-compatible with the bits of [SegmentedButton] this app uses.
class SegmentedTabs<T> extends StatelessWidget {
  const SegmentedTabs({
    super.key,
    required this.segments,
    required this.selected,
    required this.onSelectionChanged,
  });

  final List<ButtonSegment<T>> segments;
  final Set<T> selected;
  final ValueChanged<Set<T>> onSelectionChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          for (final seg in segments)
            Expanded(
              child: _SegmentCell(
                active: selected.contains(seg.value),
                onTap: () => onSelectionChanged({seg.value}),
                icon: seg.icon,
                label: seg.label,
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentCell extends StatelessWidget {
  const _SegmentCell({
    required this.active,
    required this.onTap,
    this.icon,
    this.label,
  });

  final bool active;
  final VoidCallback onTap;
  final Widget? icon;
  final Widget? label;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? kAccentSolid : Colors.transparent,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        borderRadius: BorderRadius.circular(11),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          alignment: Alignment.center,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: DefaultTextStyle(
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: active ? kAccentSolidOn : kMuted,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 6)],
                  if (label != null) label!,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


/// Skeleton matching the poster grids used by Library, Explore, Search, Browse.
class PosterGridSkeleton extends StatelessWidget {
  const PosterGridSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 16,
        crossAxisSpacing: 10,
        childAspectRatio: 0.50,
      ),
      itemCount: 12,
      itemBuilder: (_, __) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          AspectRatio(aspectRatio: 2 / 3, child: SkeletonBox()),
          SizedBox(height: 8),
          SkeletonBox(width: 90, height: 11, radius: 4),
        ],
      ),
    );
  }
}

/// Card-style row for a person or user: avatar, name, subtitle, chevron.
class PersonTile extends StatelessWidget {
  const PersonTile({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.onTap,
  });

  final String name;
  final String? subtitle;
  final String? avatarUrl;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      borderRadius: BorderRadius.circular(kRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kRadius),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kRadius),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              UserAvatar(url: avatarUrl, name: name, size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    if (subtitle != null && subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: kMuted, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: kMuted),
            ],
          ),
        ),
      ),
    );
  }
}


/// Horizontal strip of people (cast, guest stars…) with a section header.
class PeopleRow extends StatelessWidget {
  const PeopleRow({super.key, required this.title, required this.people});

  final String title;
  final List<Map<String, dynamic>> people;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SectionHeader(title: title),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final person = people[index];
                final id = person.i('tmdb_id');
                return SizedBox(
                  width: 84,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(kRadius),
                    onTap: id == null ? null : () => openPerson(context, id),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: kBorderStrong),
                          ),
                          child: UserAvatar(
                            url: app.imageUrl(
                              person.s('profile_path'),
                              size: 'w185',
                            ),
                            name: person.s('name'),
                            size: 70,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          person.s('name') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          person.s('character') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10.5, color: kMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


/// Skeleton for a detail page (show, season, episode, movie): a hero block,
/// title, action buttons and a few text lines. Used while the page's own data
/// loads so the screen is never a bare spinner on black.
class DetailSkeleton extends StatelessWidget {
  const DetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: const [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: SkeletonBox(radius: 16),
        ),
        SizedBox(height: 16),
        SkeletonBox(width: 220, height: 24, radius: 6),
        SizedBox(height: 10),
        Row(
          children: [
            SkeletonBox(width: 56, height: 22, radius: 8),
            SizedBox(width: 8),
            SkeletonBox(width: 56, height: 22, radius: 8),
            SizedBox(width: 8),
            SkeletonBox(width: 56, height: 22, radius: 8),
          ],
        ),
        SizedBox(height: 18),
        SkeletonBox(height: 50, radius: 12),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 46, radius: 12)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 46, radius: 12)),
          ],
        ),
        SizedBox(height: 20),
        SkeletonBox(height: 12, radius: 4),
        SizedBox(height: 8),
        SkeletonBox(height: 12, radius: 4),
        SizedBox(height: 8),
        SkeletonBox(width: 240, height: 12, radius: 4),
      ],
    );
  }
}

/// Skeleton for the Profile tab: avatar + name, stat tiles, a poster row.
class ProfileSkeleton extends StatelessWidget {
  const ProfileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: const [
        Row(
          children: [
            SkeletonBox(width: 76, height: 76, radius: 38),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonBox(width: 140, height: 22, radius: 6),
                  SizedBox(height: 8),
                  SkeletonBox(width: 190, height: 12, radius: 4),
                ],
              ),
            ),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: SkeletonBox(height: 46, radius: 12)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 46, radius: 12)),
            SizedBox(width: 8),
            Expanded(child: SkeletonBox(height: 46, radius: 12)),
          ],
        ),
        SizedBox(height: 14),
        SkeletonBox(height: 72, radius: 14),
        MediaRowSkeleton(),
      ],
    );
  }
}

/// Skeleton for poster-left list rows (Progress, History, Lists).
class ListRowsSkeleton extends StatelessWidget {
  const ListRowsSkeleton({super.key, this.count = 6});

  final int count;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 14),
      itemBuilder: (_, __) => const Row(
        children: [
          SkeletonBox(width: 60, height: 90, radius: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonBox(width: 160, height: 14, radius: 5),
                SizedBox(height: 8),
                SkeletonBox(width: 110, height: 11, radius: 4),
                SizedBox(height: 12),
                SkeletonBox(height: 6, radius: 3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
