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
    final app = ScrobScope.of(context);
    final placeholder = Container(
      color: kCard,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.movie_outlined, color: kMuted, size: 28),
          if (title != null)
            Text(
              truncate(title, 40),
              maxLines: 2,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 10, color: kMuted),
            ),
        ],
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: url == null || url!.isEmpty
          ? placeholder
          : Image.network(
              url!,
              headers: app.imageHeaders(url),
              fit: fit,
              errorBuilder: (_, __, ___) {
                final fallback = app.directImageUrl(url);
                if (fallback == null) return placeholder;
                return Image.network(
                  fallback,
                  fit: fit,
                  errorBuilder: (_, __, ___) => placeholder,
                );
              },
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return Container(color: kCard, child: const Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ));
              },
            ),
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
    final posterPath = item.s('poster_path') ?? item.s('show_poster_path');
    final url = app.imageUrl(posterPath, size: 'w342');
    final title = item.s('title') ?? item.s('name') ?? '';
    final year = yearOf(item.s('release_date') ?? item.s('first_air_date'));
    final rating = item.d('tmdb_rating');
    final watched = item.b('watched') || (item.d('play_count') ?? 0) > 0;

    String subtitle = '';
    if (isEpisode) {
      final show = item.s('show_title') ?? '';
      final se = [
        if (item.i('season_number') != null) 'S${item.i('season_number')}',
        if (item.i('episode_number') != null) 'E${item.i('episode_number')}',
      ].join();
      subtitle = [show, se].where((e) => e.isNotEmpty).join(' · ');
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
                          const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(6),
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
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: kGreen,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check, size: 11, color: Colors.black),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              truncate(title, 46),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            if (showSubtitle && subtitle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: kMuted),
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
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ),
        if (onSeeAll != null)
          TextButton(
            onPressed: onSeeAll,
            child: const Text(
              'See all',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
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
          Icon(icon, size: 42, color: kMuted),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: kMuted, fontSize: 12),
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
          const Icon(Icons.cloud_off_rounded, color: kMuted, size: 42),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: kMuted, fontSize: 12),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: LinearProgressIndicator(
        value: (value.clamp(0, 100)) / 100,
        minHeight: height,
        backgroundColor: kCard,
        valueColor: const AlwaysStoppedAnimation(kAccent),
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
    return ClipOval(
      child: Image.network(
        url!,
        headers: ScrobScope.of(context).imageHeaders(url),
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => CircleAvatar(
          radius: size / 2,
          backgroundColor: kCard,
          child: Text(initials(name), style: TextStyle(fontSize: size * 0.32)),
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
