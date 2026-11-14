import 'package:cached_network_image/cached_network_image.dart';
import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';

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
    final placeholder = Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F2F35), Color(0xFF1C1C20)],
        ),
      ),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, color: kMuted, size: 26),
          if (title != null) ...[
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
    this.hero = false,
  });

  final Map<String, dynamic> item;
  final double width;
  final bool showSubtitle;
  final VoidCallback? onTap;
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
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(20),
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
                if (watched && !isPerson)
                  Positioned(
                    right: 6,
                    top: 6,
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
    this.width = 124,
    this.height = 252,
  });

  final String title;
  final List<Map<String, dynamic>> items;
  final VoidCallback? onSeeAll;
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
            itemBuilder: (_, i) => MediaCard(item: items[i], width: width),
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
            child: const Padding(
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: Colors.white.withValues(alpha: 0.14),
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fraction.toDouble(),
          child: const DecoratedBox(
            decoration: BoxDecoration(gradient: kAccentGradient),
            child: SizedBox.expand(),
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
        borderRadius: BorderRadius.circular(20),
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

class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label, style: const TextStyle(fontSize: 10, color: kMuted)),
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


/// Pill-shaped action button used on detail pages (watched, rate, add to list…).
/// [active] fills it with the accent colour so state reads at a glance.
class ActionPill extends StatelessWidget {
  const ActionPill({
    super.key,
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active ? kAccent.withValues(alpha: 0.18) : kSurface,
      shape: StadiumBorder(
        side: BorderSide(
          color: active ? kAccent.withValues(alpha: 0.65) : kBorderStrong,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: active ? kAccentSoft : kMuted),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: active ? Colors.white : kBody,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
