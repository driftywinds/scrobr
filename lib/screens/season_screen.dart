import 'package:material_ui/material_ui.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/season_collect.dart';
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

  Future<void> _bulkEpisodes(
    BuildContext context,
    List<Map<String, dynamic>> episodes,
    int? initial,
  ) async {
    final byNumber = <int, Map<String, dynamic>>{};
    for (final episode in episodes) {
      final number = episode.i('episode_number');
      if (number != null) byNumber[number] = episode;
    }
    if (byNumber.isEmpty) return;

    final selected = <int>{if (initial != null) initial};
    final result = await showModalBottomSheet<Map<String, Object>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final allSelected = selected.length == byNumber.length;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Select episodes',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() {
                            if (allSelected) {
                              selected.clear();
                            } else {
                              selected.addAll(byNumber.keys);
                            }
                          }),
                          child: Text(allSelected ? 'Clear all' : 'Select all'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final entry in byNumber.entries)
                          CheckboxListTile(
                            value: selected.contains(entry.key),
                            title: Text(
                              'S${widget.seasonNumber}E${entry.key} · '
                              '${entry.value.s('title') ?? 'Episode ${entry.key}'}',
                            ),
                            subtitle: Text(
                              entry.value.b('watched')
                                  ? 'Watched'
                                  : 'Unwatched',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: (on) => setSheet(() {
                              if (on == true) {
                                selected.add(entry.key);
                              } else {
                                selected.remove(entry.key);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(context, {
                                      'watched': true,
                                      'episodes': selected.toList(),
                                    }),
                            child: const Text('Mark watched'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(context, {
                                      'watched': false,
                                      'episodes': selected.toList(),
                                    }),
                            child: const Text('Unwatch'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !context.mounted) return;

    final app = ScrobScope.of(context);
    final numbers = (result['episodes'] as List).cast<int>();
    final watched = result['watched'] == true;
    var changed = 0;
    try {
      for (final number in numbers) {
        final episode = byNumber[number]!;
        if (watched) {
          await app.post('/history', {
            'media_type': 'episode',
            'completed': true,
            'tmdb_id': episode.i('tmdb_id'),
            'series_tmdb_id': widget.showTmdbId,
            'season_number':
                episode.i('season_number') ?? widget.seasonNumber,
            'episode_number': number,
          });
        } else {
          final id = episode.i('id');
          final tmdb = episode.i('tmdb_id');
          if (id == null && tmdb == null) continue;
          await app.delete('/history/item', {
            if (id != null) 'id': id,
            if (id == null) 'tmdb_id': tmdb,
            'media_type': 'episode',
          });
        }
        changed++;
      }
      app.bumpHistory();
      _reload();
      showSnack(
        context,
        '${watched ? 'Marked' : 'Unmarked'} $changed episode(s)',
      );
    } catch (e) {
      showSnack(context, 'Could not update episodes: $e');
    }
  }

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
                child: ActionGrid(
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
                      icon: season.b('season_in_library')
                          ? Icons.library_add_check_rounded
                          : Icons.library_add_outlined,
                      label: season.b('season_in_library')
                          ? 'Uncollect season'
                          : 'Collect season',
                      onTap: () async {
                        final app = ScrobScope.of(context);
                        final order = season.s('episode_order');
                        try {
                          if (season.b('season_in_library')) {
                            await app.delete(
                              '/media/collect-season',
                              seasonUncollectQuery(
                                seriesTmdbId: widget.showTmdbId,
                                seasonNumber: widget.seasonNumber,
                                episodeOrder: order,
                              ),
                            );
                          } else {
                            await app.post(
                              '/media/collect-season',
                              seasonCollectBody(
                                seriesTmdbId: widget.showTmdbId,
                                seasonNumber: widget.seasonNumber,
                                episodeOrder: order,
                              ),
                            );
                          }
                          if (mounted) _reload();
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Could not update collection: $e'),
                              ),
                            );
                          }
                        }
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
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
                child: Row(
                  children: [
                    const Expanded(child: SectionHeader(title: 'Episodes')),
                    if (episodes.isNotEmpty)
                      TextButton.icon(
                        onPressed: () => _bulkEpisodes(context, episodes, null),
                        icon: const Icon(Icons.checklist_rounded, size: 16),
                        label: const Text(
                          'Select',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                  ],
                ),
              ),
              ...episodes.map((episode) {
                final still = app.imageUrl(
                  episode.s('still_path') ?? episode.s('poster_path'),
                  size: 'w300',
                );
                final number = episode.i('episode_number') ?? 0;
                final watched = episode.b('watched');
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: Material(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(kRadius),
                  child: InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
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
                  onLongPress: () =>
                      _bulkEpisodes(context, episodes, number),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: kBorder),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 124,
                          height: 70,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              Opacity(
                                opacity: watched ? 0.55 : 1,
                                child: Poster(url: still, radius: 8),
                              ),
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
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
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
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: watched
                                            ? kMuted
                                            : Colors.white,
                                      ),
                                    ),
                                  ),
                                  if (episode.b('watched'))
                                    const Padding(
                                      padding: EdgeInsets.only(left: 6),
                                      child: Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: kGreen,
                                      ),
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
                                  fontSize: 11,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
  Widget build(BuildContext context) =>
      ActionPill(icon: icon, label: label, onTap: onTap);
}
