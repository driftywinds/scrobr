import 'package:material_ui/material_ui.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/comments.dart';
import '../widgets/trakt_comments.dart';
import '../widgets/common.dart';
import 'episode_screen.dart';

class SeasonScreen extends StatefulWidget {
  const SeasonScreen({
    super.key,
    required this.showTmdbId,
    required this.seasonNumber,
    this.showTitle,
  });

  final int showTmdbId;
  final int seasonNumber;
  final String? showTitle;

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async => asMap(
        await ScrobScope.of(context)
            .get('/shows/${widget.showTmdbId}/season/${widget.seasonNumber}'),
      );

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.showTitle != null
              ? '${widget.showTitle} · S${widget.seasonNumber}'
              : 'Season ${widget.seasonNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final season = snapshot.data ?? const {};
          final episodes = season.maps('episodes');
          final app = ScrobScope.of(context);
          final pct = season.d('season_watch_pct') ??
              season.d('watch_pct') ??
              0;
          final poster =
              app.imageUrl(season.s('poster_path'), size: 'w342');
          return ListView(
            padding: const EdgeInsets.only(bottom: 30),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 92,
                      height: 138,
                      child: Poster(
                        url: poster,
                        title: season.s('name'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            season.s('name') ??
                                'Season ${widget.seasonNumber}',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              if (season.s('air_date') != null)
                                TagChip(
                                  label: yearOf(season.s('air_date')),
                                ),
                              if (season.d('tmdb_rating') != null)
                                RatingChip(rating: season.d('tmdb_rating')),
                              if (season.d('season_user_rating') != null)
                                RatingChip(
                                  rating: season.d('season_user_rating'),
                                  label:
                                      'You ${fmtRating(season.d('season_user_rating'))}',
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ProgressBar(value: pct),
                          const SizedBox(height: 4),
                          Text(
                            '${pct.round()}% watched',
                            style: const TextStyle(
                              fontSize: 10,
                              color: kMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (season.s('overview') != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    season.s('overview')!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: Color(0xFFD4D4D8),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallAction(
                      icon: Icons.done_all_rounded,
                      label: 'Mark season',
                      onTap: () async {
                        final ok = await markSeasonWatched(
                          context,
                          widget.showTmdbId,
                          widget.seasonNumber,
                        );
                        if (ok) _reload();
                      },
                    ),
                    _SmallAction(
                      icon: Icons.remove_done_rounded,
                      label: 'Unwatch season',
                      onTap: () async {
                        final ok = await unmarkSeasonWatched(
                          context,
                          widget.showTmdbId,
                          widget.seasonNumber,
                        );
                        if (ok) _reload();
                      },
                    ),
                    _SmallAction(
                      icon: Icons.star_outline_rounded,
                      label: 'Rate season',
                      onTap: () async {
                        final changed = await openRatingDialog(
                          context,
                          {
                            'type': 'series',
                            'tmdb_id': widget.showTmdbId,
                            'title': season.s('name') ?? 'Season',
                            'user_rating': season.d('season_user_rating'),
                          },
                          seasonNumber: widget.seasonNumber,
                        );
                        if (changed) _reload();
                      },
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 18, 16, 6),
                child: Text(
                  'Episodes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
              ...episodes.map((episode) {
                final still = app.imageUrl(episode.s('still_path'), size: 'w300');
                final number = episode.i('episode_number') ?? 0;
                final watched = episode.b('watched');
                return InkWell(
                  onTap: () async {
                    await pushScreen(
                      context,
                      EpisodeScreen(
                        showTmdbId: widget.showTmdbId,
                        seasonNumber: widget.seasonNumber,
                        episodeNumber: number,
                        showTitle: widget.showTitle,
                        seasonTitle: season.s('name'),
                      ),
                    );
                    if (mounted) _reload();
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 112,
                          height: 63,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Poster(url: still, radius: 7),
                              Positioned(
                                left: 4,
                                bottom: 4,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'E$number',
                                    style: const TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      episode.s('title') ??
                                          'Episode $number',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: watched
                                            ? kMuted
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (episode.b('watched'))
                                    const Icon(
                                      Icons.check_circle,
                                      size: 15,
                                      color: kGreen,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                [
                                  if (episode.s('air_date') != null)
                                    fmtDate(episode.s('air_date')),
                                  if (episode.i('runtime') != null)
                                    fmtRuntime(episode.i('runtime')),
                                  if (episode.d('tmdb_rating') != null &&
                                      episode.d('tmdb_rating')! > 0)
                                    '★ ${fmtRating(episode.d('tmdb_rating'))}',
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              CommentsSection(
                mediaType: 'series',
                tmdbId: widget.showTmdbId,
                seasonNumber: widget.seasonNumber,
                title: 'Season comments',
              ),
              TraktCommentsSection(
                mediaType: 'series',
                tmdbId: widget.showTmdbId,
                seasonNumber: widget.seasonNumber,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF3F3F46)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kMuted),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 10)),
          ],
        ),
      ),
    );
  }
}
