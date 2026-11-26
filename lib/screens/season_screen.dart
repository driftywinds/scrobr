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
import '../core/friendly_error.dart';

class SeasonScreen extends StatefulWidget {
  const SeasonScreen({
    super.key,
    required this.showTmdbId,
    required this.seasonNumber,
    this.showTitle,
    this.cast = const [],
  });

  final int showTmdbId;
  final int seasonNumber;
  final String? showTitle;
  final List<Map<String, dynamic>> cast;

  @override
  State<SeasonScreen> createState() => _SeasonScreenState();
}

class _SeasonScreenState extends State<SeasonScreen> {
  Future<Map<String, dynamic>>? _future;

  /// Last successfully loaded season. Reloads after a tap keep showing it
  /// instead of flashing a spinner and jumping back to the top of the list.
  Map<String, dynamic>? _cached;

  /// Optimistic watched state per episode number while a toggle is in flight.
  final Map<int, bool> _override = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final data = asMap(
      await ScrobScope.of(context)
          .get('/shows/${widget.showTmdbId}/season/${widget.seasonNumber}'),
    );
    _cached = data;
    return data;
  }

  void _reload() => setState(() => _future = _load());

  bool _isAired(Map<String, dynamic> episode) {
    final date = DateTime.tryParse(episode.s('air_date') ?? '');
    if (date == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(date.year, date.month, date.day).isAfter(today);
  }

  /// One-tap toggle from the episode row. Updates the row immediately, then
  /// refreshes quietly in the background.
  Future<void> _toggleEpisode(
    Map<String, dynamic> episode,
    int number,
    bool target,
  ) async {
    setState(() => _override[number] = target);
    final ok = await toggleWatched(
      context,
      {
        ...episode,
        'type': 'episode',
        'series_tmdb_id': widget.showTmdbId,
        'season_number': episode.i('season_number') ?? widget.seasonNumber,
      },
      target: target,
      promptRating: false,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() => _override.remove(number));
      return;
    }
    try {
      final fresh = await _load();
      if (!mounted) return;
      setState(() {
        _future = Future.value(fresh);
        _override.clear();
      });
    } catch (_) {
      // Keep the optimistic state; pull-to-refresh will reconcile.
    }
  }

  Future<void> _toggleCollect(Map<String, dynamic> season) async {
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
        showSnack(
          context,
          'Could not update collection: ${friendlyError(e)}',
        );
      }
    }
  }

  Future<void> _rateSeason(Map<String, dynamic> season) async {
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
  }

  Future<void> _unwatchSeason() async {
    final ok = await confirmAction(
      context,
      title: 'Unwatch this season?',
      message: 'Every episode of this season will be marked unwatched.',
      confirmLabel: 'Unwatch season',
    );
    if (!ok || !mounted) return;
    final done = await unmarkSeasonWatched(
      context,
      widget.showTmdbId,
      widget.seasonNumber,
    );
    if (done) _reload();
  }

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
      showSnack(context, 'Could not update episodes: ${friendlyError(e)}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // The season name is shown in the header below, so the bar only needs
        // the show to avoid saying "Season 1" twice.
        title: Text(
          widget.showTitle ?? 'Season ${widget.seasonNumber}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Season options',
            onSelected: (value) {
              final season = _cached ?? const <String, dynamic>{};
              switch (value) {
                case 'unwatch':
                  _unwatchSeason();
                case 'collect':
                  _toggleCollect(season);
                case 'rate':
                  _rateSeason(season);
              }
            },
            itemBuilder: (_) {
              final inLibrary = _cached?.b('season_in_library') ?? false;
              return [
                const PopupMenuItem(
                  value: 'rate',
                  child: Text('Rate season'),
                ),
                PopupMenuItem(
                  value: 'collect',
                  child: Text(
                    inLibrary ? 'Uncollect season' : 'Collect season',
                  ),
                ),
                const PopupMenuItem(
                  value: 'unwatch',
                  child: Text(
                    'Unwatch season',
                    style: TextStyle(color: kDanger),
                  ),
                ),
              ];
            },
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _cached;
          if (data == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const ListRowsSkeleton();
          }
          if (data == null && snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error),
              onRetry: _reload,
            );
          }
          final season = data ?? const <String, dynamic>{};
          final episodes = season.maps('episodes');
          final app = ScrobScope.of(context);
          final pct = season.d('season_watch_pct') ??
              season.d('watch_pct') ??
              0;
          final poster =
              app.imageUrl(season.s('poster_path'), size: 'w342');

          bool watchedOf(Map<String, dynamic> episode) =>
              _override[episode.i('episode_number') ?? -1] ??
              episode.b('watched');

          // The first aired, unwatched episode is what to watch next.
          int? nextNumber;
          for (final episode in episodes) {
            if (!watchedOf(episode) && _isAired(episode)) {
              nextNumber = episode.i('episode_number');
              break;
            }
          }

          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 30),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 78,
                        height: 117,
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: ActionPill(
                    primary: pct < 100,
                    active: pct >= 100,
                    icon: Icons.done_all_rounded,
                    label: pct >= 100 ? 'Season watched' : 'Mark season watched',
                    onTap: pct >= 100
                        ? null
                        : () async {
                            final ok = await markSeasonWatched(
                              context,
                              widget.showTmdbId,
                              widget.seasonNumber,
                            );
                            if (ok) _reload();
                          },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Row(
                    children: [
                      const Expanded(child: SectionHeader(title: 'Episodes')),
                      if (episodes.isNotEmpty)
                        TextButton.icon(
                          onPressed: () =>
                              _bulkEpisodes(context, episodes, null),
                          icon: const Icon(Icons.checklist_rounded, size: 16),
                          label: const Text(
                            'Select',
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ),
                if (episodes.isEmpty)
                  const EmptyState(
                    title: 'No episodes listed',
                    body: 'Pull down to refresh, or check back closer to the air date.',
                  ),
                ...episodes.map((episode) {
                  final still = app.imageUrl(
                    episode.s('still_path') ?? episode.s('poster_path'),
                    size: 'w300',
                  );
                  final number = episode.i('episode_number') ?? 0;
                  final watched = watchedOf(episode);
                  final aired = _isAired(episode);
                  final isNext = number == nextNumber;
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
                          padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(kRadius),
                            border: Border.all(
                              color: isNext
                                  ? kAccentSolid.withValues(alpha: 0.7)
                                  : kBorder,
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 112,
                                height: 63,
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
                                          color: Colors.black
                                              .withValues(alpha: 0.7),
                                          borderRadius:
                                              BorderRadius.circular(4),
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
                                    if (isNext)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 3),
                                        child: Text(
                                          'UP NEXT',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1,
                                            color: kAccentSoft,
                                          ),
                                        ),
                                      ),
                                    Text(
                                      episode.s('title') ?? 'Episode $number',
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
                                    const SizedBox(height: 3),
                                    Text(
                                      [
                                        if (!aired) 'Upcoming',
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
                              // One tap marks or unmarks the episode without
                              // opening it or entering "Select" mode.
                              if (aired)
                                IconButton(
                                  tooltip: watched
                                      ? 'Mark unwatched'
                                      : 'Mark watched',
                                  onPressed: () =>
                                      _toggleEpisode(episode, number, !watched),
                                  icon: Icon(
                                    watched
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    size: 26,
                                    color: watched ? kGreen : kMuted,
                                  ),
                                )
                              else
                                const SizedBox(width: 12),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
                if (season.s('overview') != null &&
                    season.s('overview')!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                    child: Text(
                      season.s('overview')!,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Color(0xFFD4D4D8),
                      ),
                    ),
                  ),
                if (widget.cast.isNotEmpty)
                  PeopleRow(title: 'Series cast', people: widget.cast),
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
            ),
          );
        },
      ),
    );
  }
}
