import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../core/concurrency.dart';
import '../core/format.dart';
import '../core/friendly_error.dart';
import '../core/home_shortcuts.dart';
import '../core/home_sort.dart';
import '../core/watch_sync.dart';
import '../core/movie_shelf.dart';
import '../core/nav.dart';
import '../widgets/swipe_pages.dart';
import '../widgets/watch_sync_sheet.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/movie_poster_tile.dart';
import '../widgets/up_next_tile.dart';
import 'discover_screen.dart';
import 'requests_screen.dart';
import 'shelf_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<void>? _showsFuture;
  Future<void>? _moviesFuture;
  List<Map<String, dynamic>> _shows = const [];
  List<Map<String, dynamic>> _progress = const [];
  List<Map<String, dynamic>> _movies = const [];
  bool _showsLoaded = false;
  bool _moviesLoaded = false;
  Object? _showsError;
  Object? _moviesError;
  bool _cacheRead = false;
  int _seenHistoryRevision = -1;
  int _seenFollowingRevision = -1;
  int _seenListRevision = -1;
  String _tab = 'shows';
  final Set<int> _checkedMovies = {};
  final Set<int> _undoneShows = {};
  final Map<int, Map<String, dynamic>?> _showOverrides = {};
  final Map<String, List<Map<String, dynamic>>> _seasonCache = {};
  HomeSort _showSort = HomeSort.lastWatched;
  HomeSort _movieSort = HomeSort.recentlyAdded;
  Map<int, String> _showAddedAt = {};
  Map<int, Map<String, dynamic>> _showRatings = {};
  bool _sortLoading = false;
  int _randomSeed = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    if (!_cacheRead) {
      _cacheRead = true;
      _readCache(app);
    }
    var needsReload = false;
    if (_seenHistoryRevision < 0) {
      _seenHistoryRevision = app.historyRevision;
    } else if (_seenHistoryRevision != app.historyRevision) {
      _seenHistoryRevision = app.historyRevision;
      needsReload = true;
    }
    if (_seenFollowingRevision < 0) {
      _seenFollowingRevision = app.followingRevision;
    } else if (_seenFollowingRevision != app.followingRevision) {
      _seenFollowingRevision = app.followingRevision;
      needsReload = true;
    }
    if (_seenListRevision < 0) {
      _seenListRevision = app.listRevision;
    } else if (_seenListRevision != app.listRevision) {
      _seenListRevision = app.listRevision;
      needsReload = true;
    }
    if (needsReload) _reload();
    _showsFuture ??= _loadShows();
    _moviesFuture ??= _loadMovies();
  }

  Future<void> _readCache(AppState app) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final showsRaw = prefs.getString(_showsCacheKey(app));
      final moviesRaw = prefs.getString(_moviesCacheKey(app));
      if (!mounted) return;
      setState(() {
        if (showsRaw != null && showsRaw.isNotEmpty) {
          final cached = asMap(jsonDecode(showsRaw));
          _shows = asMaps(cached['shows']);
          _progress = asMaps(cached['progress']);
          _showsLoaded = true;
        }
        if (moviesRaw != null && moviesRaw.isNotEmpty) {
          final cached = asMap(jsonDecode(moviesRaw));
          _movies = asMaps(cached['movies']);
          _showAddedAt = {
            for (final entry in asMap(cached['showAddedAt']).entries)
              if (int.tryParse(entry.key) != null && entry.value is String)
                int.parse(entry.key): entry.value as String,
          };
          _moviesLoaded = true;
        }
        _showSort = homeSortFromId(
          prefs.getString('scrobr_shows_sort'),
          HomeSort.lastWatched,
        );
        _movieSort = homeSortFromId(
          prefs.getString('scrobr_movies_sort'),
          HomeSort.recentlyAdded,
        );
      });
    } catch (_) {
      // A corrupt cache should never block the network refresh.
    }
  }

  String _showsCacheKey(AppState app) =>
      'scrobr_up_next_shows_${app.userId ?? 0}_${app.server.hashCode}';

  String _moviesCacheKey(AppState app) =>
      'scrobr_up_next_movies_${app.userId ?? 0}_${app.server.hashCode}';

  Future<void> _saveCache(String key, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(data));
    } catch (_) {
      // Cache writes are best-effort.
    }
  }

  Future<List<Map<String, dynamic>>> _watchlistEntries(AppState app) async {
    final data = await app.tryGet('/lists');
    if (data == null) return const [];
    Map<String, dynamic>? watchlist;
    for (final list in asMaps(asMap(data)['lists'])) {
      if (list.b('is_watchlist')) {
        watchlist = list;
        break;
      }
    }
    final id = watchlist?.i('id');
    if (id == null) return const [];
    final detail = await app.tryGet('/lists/$id');
    if (detail == null) return const [];
    return asMaps(asMap(detail)['items']);
  }

  Future<void> _loadShows() async {
    final app = ScrobScope.of(context);
    _showsError = null;
    try {
      final results = await Future.wait([
        app.tryGet('/history/next-up', {'limit': 100}),
        app.tryGet('/history/progress', {
          'type': 'watched',
          'sort': 'recent',
          'page_size': 200,
        }),
      ]);
      if (results.every((result) => result == null)) {
        throw Exception('Could not load your Up Next');
      }
      final shows = asMaps(asMap(results[0])['next_up']);
      final progress = asMaps(asMap(results[1])['shows']);
      _shows = shows;
      _progress = progress;
      _showsLoaded = true;
      _showOverrides.clear();
      _saveCache(_showsCacheKey(app), {'shows': shows, 'progress': progress});
      if (mounted) setState(() {});
    } catch (e) {
      _showsError = e;
      if (mounted) setState(() {});
    }
  }

  Future<void> _loadMovies() async {
    final app = ScrobScope.of(context);
    _moviesError = null;
    try {
      // Start both list requests together. The Following list usually has its
      // id cached, so this is normally one detail request per source.
      final results = await Future.wait([
        _watchlistEntries(app),
        app.followingItems().catchError((_) => <Map<String, dynamic>>[]),
      ]);
      final watchlist = asMaps(results[0]);
      final following = asMaps(results[1]);
      final movies = buildMovieRows(
        continueWatching: const [],
        watchlist: watchlist,
        following: following,
      );
      final addedAt = <int, String>{};
      for (final entry in [...watchlist, ...following]) {
        final media = asMap(entry['media']);
        if (media.s('type') != 'series') continue;
        final id = media.i('tmdb_id');
        final date = entry.s('added_at') ?? media.s('added_at');
        if (id == null || date == null) continue;
        final current = addedAt[id];
        if (current == null || date.compareTo(current) > 0) {
          addedAt[id] = date;
        }
      }
      _movies = movies;
      _showAddedAt = addedAt;
      _moviesLoaded = true;
      _saveCache(_moviesCacheKey(app), {
        'movies': movies,
        'showAddedAt': addedAt,
      });
      if (mounted) setState(() {});
    } catch (e) {
      _moviesError = e;
      if (mounted) setState(() {});
    }
  }

  Future<void> _ensureShowRatings() async {
    final app = ScrobScope.of(context);
    final missing = <int>{};
    for (final item in _shows) {
      final id = item.i('show_tmdb_id') ?? item.i('tmdb_id');
      if (id != null && !_showRatings.containsKey(id)) missing.add(id);
    }
    if (missing.isEmpty) return;
    setState(() => _sortLoading = true);
    final results = await mapConcurrent(
      missing.toList(),
      6,
      (id) async => MapEntry(id, asMap(await app.tryGet('/shows/$id'))),
    );
    if (!mounted) return;
    setState(() {
      for (final entry in results) {
        _showRatings[entry.key] = entry.value;
      }
      _sortLoading = false;
    });
  }

  Future<void> _changeSort(HomeSort sort, {required bool shows}) async {
    setState(() {
      if (shows) {
        _showSort = sort;
      } else {
        _movieSort = sort;
      }
      _randomSeed = DateTime.now().microsecondsSinceEpoch;
      _sortLoading = shows &&
          (sort == HomeSort.tmdbRating || sort == HomeSort.myRating);
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      shows ? 'scrobr_shows_sort' : 'scrobr_movies_sort',
      sort.id,
    );
    if (!mounted) return;
    if (shows && (sort == HomeSort.tmdbRating || sort == HomeSort.myRating)) {
      await _ensureShowRatings();
    }
    if (shows && sort == HomeSort.recentlyAdded) {
      await _moviesFuture;
      if (mounted) setState(() {});
    }
  }

  PopupMenuButton<HomeSort> _sortButton({required bool shows}) {
    final current = shows ? _showSort : _movieSort;
    final options = shows ? showSortOptions : movieSortOptions;
    return PopupMenuButton<HomeSort>(
      tooltip: 'Sort: ${current.label}',
      onSelected: (value) => _changeSort(value, shows: shows),
      // Showing the current sort means the state is visible, not hidden
      // behind an anonymous icon.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort_rounded, size: 18, color: kMuted),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                current.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: kBody,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down_rounded, size: 20, color: kMuted),
          ],
        ),
      ),
      itemBuilder: (_) => [
        for (final option in options)
          PopupMenuItem(
            value: option,
            child: Row(
              children: [
                SizedBox(
                  width: 24,
                  child: option == current
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                ),
                const SizedBox(width: 4),
                Text(option.label),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _reload() async {
    setState(() {
      _showsFuture = _loadShows();
      _moviesFuture = _loadMovies();
    });
    await Future.wait([_showsFuture!, _moviesFuture!]);
  }

  void _openMenu(String value) {
    switch (value) {
      case 'lists':
        openLists(context);
      case 'calendar':
        openCalendar(context);
      case 'progress':
        pushScreen(context, const ProgressScreen());
      case 'dropped':
        pushScreen(context, const DroppedScreen());
      case 'requests':
        pushScreen(context, const RequestsScreen());
      case 'settings':
        openSettings(context);
    }
  }

  Future<void> _markShowWatched(Map<String, dynamic> item) async {
    final app = ScrobScope.of(context);
    final queued = {...item, 'type': 'episode'};
    if (!app.queueWatch(queued)) return;
    final showId = item.i('show_tmdb_id') ?? item.i('tmdb_id');
    if (showId == null) return;
    _undoneShows.remove(showId);
    _offerUndo(
      label: watchLabelFor(queued),
      key: watchKeyFor(queued),
      onUndone: () {
        _undoneShows.add(showId);
        if (mounted) setState(() => _showOverrides.remove(showId));
      },
    );
    final season = item.i('season_number') ?? 1;
    final episode = item.i('episode_number') ?? 0;
    // Keep the show visible while the real next episode is looked up. This
    // placeholder is replaced as soon as the season data arrives.
    if (mounted) {
      setState(() {
        _showOverrides[showId] = {
          ...item,
          'type': 'episode',
          'season_number': season,
          'episode_number': episode + 1,
          'episode_name': null,
          'title': item.s('show_title') ?? item.s('title'),
          'tmdb_id': null,
          'watched': false,
          '_loading': true,
        };
      });
    }
    try {
      final next = await _nextEpisode(item);
      if (!mounted) return;
      if (_undoneShows.remove(showId)) return;
      setState(() {
        // Null means the series has no next episode, so remove the row then.
        _showOverrides[showId] = next;
      });
    } catch (_) {
      if (!mounted) return;
      if (_undoneShows.remove(showId)) return;
      setState(() {
        _showOverrides[showId] = {
          ...item,
          'episode_name': 'Could not load next episode',
          'title': 'Could not load next episode',
          'tmdb_id': null,
          'watched': false,
        };
      });
    }
  }

  Future<Map<String, dynamic>?> _nextEpisode(
    Map<String, dynamic> item,
  ) async {
    final app = ScrobScope.of(context);
    final showId = item.i('show_tmdb_id');
    final season = item.i('season_number');
    final episode = item.i('episode_number');
    if (showId == null || season == null || episode == null) return null;

    Map<String, dynamic> merge(Map<String, dynamic> next) => {
          ...item,
          ...next,
          'type': 'episode',
          'show_tmdb_id': showId,
          'show_title': item.s('show_title') ?? item.s('title'),
          'show_poster_path': item.s('show_poster_path'),
          'watched': false,
        };

    final current = await _seasonEpisodes(showId, season);
    for (final next in current) {
      final number = next.i('episode_number');
      if (number != null &&
          number > episode &&
          !next.b('watched') &&
          _isAired(next)) {
        return merge(next);
      }
    }

    final show = asMap(await app.tryGet('/shows/$showId'));
    final seasons = show.maps('seasons_meta')
      ..sort(
        (a, b) => (a.i('season_number') ?? 0).compareTo(
          b.i('season_number') ?? 0,
        ),
      );
    for (final meta in seasons) {
      final number = meta.i('season_number');
      if (number == null || number <= season) continue;
      final episodes = await _seasonEpisodes(showId, number);
      for (final next in episodes) {
        if (!next.b('watched') && _isAired(next)) return merge(next);
      }
    }
    return null;
  }

  bool _isAired(Map<String, dynamic> episode) {
    final airDate = DateTime.tryParse(episode.s('air_date') ?? '');
    if (airDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return !DateTime(airDate.year, airDate.month, airDate.day).isAfter(today);
  }

  Future<List<Map<String, dynamic>>> _seasonEpisodes(
    int showId,
    int season,
  ) async {
    final key = '$showId:$season';
    final cached = _seasonCache[key];
    if (cached != null) return cached;
    final data = asMap(
      await ScrobScope.of(context).get('/shows/$showId/season/$season'),
    );
    final episodes = data.maps('episodes');
    _seasonCache[key] = episodes;
    return episodes;
  }

  Future<void> _markMovieWatched(Map<String, dynamic> entry) async {
    final media = asMap(entry['media']);
    final app = ScrobScope.of(context);
    final queued = {...media, 'type': 'movie'};
    if (!app.queueWatch(queued)) return;
    final id = media.i('tmdb_id');
    if (id != null && mounted) setState(() => _checkedMovies.add(id));
    _offerUndo(
      label: watchLabelFor(queued),
      key: watchKeyFor(queued),
      onUndone: () {
        if (id != null && mounted) setState(() => _checkedMovies.remove(id));
      },
    );
  }

  /// Snackbar with Undo for the optimistic watch queue. Undo only works while
  /// the item is still waiting in the queue (it syncs after a short pause);
  /// after that the History tab is the place to unwatch it.
  void _offerUndo({
    required String label,
    required String? key,
    required VoidCallback onUndone,
  }) {
    if (!mounted) return;
    final app = ScrobScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 5),
          content: Text('Marked $label as watched'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () {
              if (key != null && app.unqueueWatch(key)) {
                onUndone();
              } else {
                messenger
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Already synced. Remove it from History to undo.',
                      ),
                    ),
                  );
              }
            },
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            SvgPicture.asset(
              'assets/scrobr.svg',
              width: 28,
              height: 28,
              placeholderBuilder: (_) =>
                  const Icon(Icons.movie_filter, size: 28),
            ),
            const SizedBox(width: 8),
            const Text('Scrobr'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () async {
              await openSearch(
                context,
                type: _tab == 'movies' ? 'movie' : 'series',
              );
              if (mounted) _reload();
            },
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Sync status',
            onPressed: () => showWatchSyncSheet(context),
            icon: Badge(
              isLabelVisible: app.watchPendingCount > 0,
              label: Text('${app.watchPendingCount}'),
              child: Icon(
                app.watchSyncing
                    ? Icons.sync_rounded
                    : app.watchPendingCount > 0
                        ? Icons.schedule_rounded
                        : app.watchSyncError != null
                            ? Icons.cloud_off_rounded
                            : Icons.cloud_done_outlined,
              ),
            ),
          ),
          // The shortcut row already offers every visible destination, so the
          // menu only carries what the row doesn't: shortcuts you have hidden
          // (so nothing becomes unreachable) and Settings.
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: _openMenu,
            itemBuilder: (_) => [
              for (final id in app.homeShortcutOrder)
                if (app.hiddenHomeShortcuts.contains(id))
                  PopupMenuItem(value: id, child: Text(homeShortcutLabel(id))),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: !_showsLoaded && _shows.isEmpty
          ? (_showsError == null
              ? const _UpNextSkeleton()
              : ErrorView(
                  message: friendlyError(_showsError),
                  onRetry: _reload,
                ))
          : Column(
              children: [
                if (app.isApiKeyMode) _ApiKeyBanner(),
                _Shortcuts(onSelected: _openMenu),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final tabsWidth =
                          (constraints.maxWidth * 0.56).clamp(160.0, 260.0).toDouble();
                      return Row(
                        children: [
                          SizedBox(
                            width: tabsWidth,
                            child: SegmentedTabs<String>(
                              segments: const [
                                ButtonSegment(
                                  value: 'shows',
                                  label: Text('Shows'),
                                ),
                                ButtonSegment(
                                  value: 'movies',
                                  label: Text('Movies'),
                                ),
                              ],
                              selected: {_tab},
                              onSelectionChanged: (value) {
                                setState(() => _tab = value.first);
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Align(
                              alignment: Alignment.centerRight,
                              child: _sortButton(shows: _tab == 'shows'),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                if (_sortLoading)
                  const LinearProgressIndicator(minHeight: 2),
                if (app.watchSyncError != null && app.watchPendingCount > 0)
                  _SyncErrorBanner(
                    count: app.watchPendingCount,
                    message: app.watchSyncError!,
                    onRetry: app.flushWatchQueue,
                    onDetails: () => showWatchSyncSheet(context),
                  ),
                Expanded(
                  child: SwipePages(
                    index: _tab == 'shows' ? 0 : 1,
                    onIndexChanged: (i) =>
                        setState(() => _tab = i == 0 ? 'shows' : 'movies'),
                    itemCount: 2,
                    itemBuilder: (context, i) => RefreshIndicator(
                      onRefresh: _reload,
                      child: i == 0 ? _buildShows() : _buildMovies(),
                    ),
                  ),
                ),
              ],
            ),

    );
  }

  Widget _buildShows() {
    if (!_showsLoaded && _shows.isEmpty) {
      return const LoadingView();
    }
    if (_shows.isEmpty) {
      return _EmptyUpNext(
        title: 'You are all caught up',
        body: 'Start a show and its next episode will appear here.',
        icon: Icons.play_circle_outline_rounded,
      );
    }
    final progress = {
      for (final show in _progress)
        if (show.i('tmdb_id') != null) show.i('tmdb_id')!: show,
    };
    final visibleShows = <Map<String, dynamic>>[];
    for (final item in _shows) {
      final showId = item.i('show_tmdb_id') ?? item.i('tmdb_id');
      if (showId != null && _showOverrides.containsKey(showId)) {
        final override = _showOverrides[showId];
        if (override != null) visibleShows.add(override);
      } else {
        visibleShows.add(item);
      }
    }
    if (visibleShows.isEmpty) {
      return _EmptyUpNext(
        title: 'You are all caught up',
        body: 'Queued episodes will sync after a short pause.',
        icon: Icons.cloud_done_outlined,
      );
    }
    final ordered = sortShows(
      visibleShows,
      sort: _showSort,
      progress: progress,
      ratings: _showRatings,
      addedAt: _showAddedAt,
      randomSeed: _randomSeed,
    );
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: ordered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = ordered[index];
        final showTmdb = item.i('show_tmdb_id') ?? item.i('tmdb_id');
        final stats = showTmdb == null ? null : progress[showTmdb];
        final season = item.i('season_number');
        final episode = item.i('episode_number');
        final code = season == null || episode == null
            ? null
            : 'S${season.toString().padLeft(2, '0')}'
                'E${episode.toString().padLeft(2, '0')}';
        return UpNextTile(
          title: item.s('show_title') ?? item.s('title') ?? '',
          posterUrl: ScrobScope.of(context).imageUrl(
            posterPathFor(item),
            size: 'w185',
          ),
          episodeCode: code,
          subtitle: item.b('_loading')
              ? null
              : (item.s('episode_name') ?? item.s('title')),
          loading: item.b('_loading'),
          watched: stats?.i('episodes_watched'),
          total: stats?.i('episodes_total'),
          progress: stats?.d('watch_pct'),
          onTap: () => openMedia(context, {...item, 'type': 'episode'}),
          onCheck: item.i('tmdb_id') == null
              ? null
              : () => _markShowWatched(item),
        );
      },
    );
  }

  Widget _buildMovies() {
    if (!_moviesLoaded && _movies.isEmpty) {
      return const PosterGridSkeleton();
    }
    if (_moviesError != null && _movies.isEmpty) {
      return ErrorView(message: friendlyError(_moviesError), onRetry: _reload);
    }
    final app = ScrobScope.of(context);
    final movies = _movies.where((entry) {
      final media = asMap(entry['media']);
      final id = media.i('tmdb_id');
      if (id == null) return true;
      return !_checkedMovies.contains(id) &&
          !app.isMovieWatched(id) &&
          !media.b('watched');
    }).toList();
    if (movies.isEmpty) {
      return _EmptyUpNext(
        title: 'No movies saved',
        body:
            'Add a movie to your watchlist or follow it to see it here.',
        icon: Icons.movie_outlined,
      );
    }
    final ordered = sortMovies(
      movies,
      sort: _movieSort,
      randomSeed: _randomSeed,
    );
    return GridView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        mainAxisSpacing: 12,
        crossAxisSpacing: 10,
        childAspectRatio: 0.5,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final entry = ordered[index];
        final media = asMap(entry['media']);
        return MoviePosterTile(
          title: media.s('title') ?? '',
          posterUrl: app.imageUrl(posterPathFor(media), size: 'w185'),
          subtitle: () {
            final year = yearOf(media.s('release_date'));
            return year.isEmpty ? null : year;
          }(),
          onTap: () => openMedia(context, media),
          onCheck: () => _markMovieWatched(entry),
        );
      },
    );
  }
}

/// Inline notice when queued watches could not be sent. Without it the only
/// sign of a failed sync is a small icon change in the app bar.
class _SyncErrorBanner extends StatelessWidget {
  const _SyncErrorBanner({
    required this.count,
    required this.message,
    required this.onRetry,
    required this.onDetails,
  });

  final int count;
  final String message;
  final Future<void> Function() onRetry;
  final VoidCallback onDetails;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
      decoration: BoxDecoration(
        color: kDanger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDanger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off_rounded, size: 18, color: kDanger),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: onDetails,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  count == 1
                      ? "1 watched item hasn't synced. $message"
                      : "$count watched items haven't synced. $message",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: kBody),
                ),
              ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

class _ApiKeyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kAccent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kAccent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.key_rounded, size: 16, color: kAccentSoft),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'API-key session: account, comments and admin screens are limited.',
              style: TextStyle(fontSize: 12, color: kMuted),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyUpNext extends StatelessWidget {
  const _EmptyUpNext({
    required this.title,
    required this.body,
    required this.icon,
  });

  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(top: 54, bottom: 24),
      children: [
        EmptyState(title: title, body: body, icon: icon),
        Center(
          child: TextButton.icon(
            onPressed: () => pushScreen(context, const DiscoverScreen()),
            icon: const Icon(Icons.explore_outlined),
            label: const Text('Find something to watch'),
          ),
        ),
      ],
    );
  }
}

class _UpNextSkeleton extends StatelessWidget {
  const _UpNextSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (var i = 0; i < 6; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const SkeletonBox(width: 72, height: 108, radius: 8),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonBox(width: 180, height: 16),
                      SizedBox(height: 8),
                      SkeletonBox(width: 130, height: 12),
                      SizedBox(height: 10),
                      SkeletonBox(width: 220, height: 10),
                      SizedBox(height: 7),
                      SkeletonBox(width: 220, height: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}


/// Equal-width row of quick links, so enabled shortcuts are one tap away
/// instead of hidden in the overflow menu. Hidden cards are omitted entirely;
/// the remaining cards expand evenly to fill the row.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onSelected});

  final ValueChanged<String> onSelected;

  static const _icons = {
    'lists': Icons.view_list_rounded,
    'calendar': Icons.calendar_month_rounded,
    'progress': Icons.timelapse_rounded,
    'dropped': Icons.do_not_disturb_on_outlined,
    'requests': Icons.download_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final items = [
      for (final id in app.homeShortcutOrder)
        if (!app.hiddenHomeShortcuts.contains(id) && _icons[id] != null)
          (id, _icons[id]!, homeShortcutLabel(id)),
    ];
    if (items.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(
              child: Material(
                color: kSurface,
                borderRadius: BorderRadius.circular(kRadius),
                child: InkWell(
                  borderRadius: BorderRadius.circular(kRadius),
                  onTap: () => onSelected(items[i].$1),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(kRadius),
                      border: Border.all(color: kBorder),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(items[i].$2, size: 20, color: kAccentSolid),
                        const SizedBox(height: 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            items[i].$3,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: kBody,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
