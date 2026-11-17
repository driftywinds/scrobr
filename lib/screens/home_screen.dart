import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/concurrency.dart';
import '../core/format.dart';
import '../core/home_sort.dart';
import '../core/movie_shelf.dart';
import '../core/nav.dart';
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
  String _tab = 'shows';
  final Set<int> _checkedMovies = {};
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
    if (_seenHistoryRevision < 0) {
      _seenHistoryRevision = app.historyRevision;
    } else if (_seenHistoryRevision != app.historyRevision) {
      _seenHistoryRevision = app.historyRevision;
      _reload();
    }
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
      tooltip: 'Sort',
      icon: const Icon(Icons.sort_rounded),
      onSelected: (value) => _changeSort(value, shows: shows),
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
    final changed = await toggleWatched(
      context,
      {...item, 'type': 'episode'},
      target: true,
      promptRating: false,
    );
    if (!changed || !mounted) return;
    _seenHistoryRevision = ScrobScope.of(context).historyRevision;
    await _reload();
  }

  Future<void> _markMovieWatched(Map<String, dynamic> entry) async {
    final media = asMap(entry['media']);
    final changed = await toggleWatched(
      context,
      {...media, 'type': 'movie'},
      target: true,
      promptRating: false,
    );
    if (!changed || !mounted) return;
    final id = media.i('tmdb_id');
    if (id != null) setState(() => _checkedMovies.add(id));
    _seenHistoryRevision = ScrobScope.of(context).historyRevision;
    await _reload();
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
            onPressed: () => openSearch(
              context,
              type: _tab == 'movies' ? 'movie' : 'series',
            ),
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: _openMenu,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'lists', child: Text('Lists')),
              PopupMenuItem(value: 'calendar', child: Text('Calendar')),
              PopupMenuItem(value: 'progress', child: Text('Progress')),
              PopupMenuItem(value: 'dropped', child: Text('Dropped')),
              PopupMenuItem(value: 'requests', child: Text('Requests')),
              PopupMenuItem(value: 'settings', child: Text('Settings')),
            ],
          ),
        ],
      ),
      body: !_showsLoaded && _shows.isEmpty
          ? (_showsError == null
              ? const _UpNextSkeleton()
              : ErrorView(
                  message: '$_showsError',
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
                          const Spacer(),
                          _sortButton(shows: _tab == 'shows'),
                        ],
                      );
                    },
                  ),
                ),
                if (_sortLoading)
                  const LinearProgressIndicator(minHeight: 2),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _reload,
                    child: _tab == 'shows' ? _buildShows() : _buildMovies(),
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
    final ordered = sortShows(
      _shows,
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
          subtitle: item.s('episode_name') ?? item.s('title'),
          watched: stats?.i('episodes_watched'),
          total: stats?.i('episodes_total'),
          progress: stats?.d('watch_pct'),
          onTap: () => openMedia(context, {...item, 'type': 'episode'}),
          onCheck: () => _markShowWatched(item),
        );
      },
    );
  }

  Widget _buildMovies() {
    if (!_moviesLoaded && _movies.isEmpty) {
      return const PosterGridSkeleton();
    }
    if (_moviesError != null && _movies.isEmpty) {
      return ErrorView(message: '$_moviesError', onRetry: _reload);
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
        childAspectRatio: 0.54,
      ),
      itemCount: ordered.length,
      itemBuilder: (context, index) {
        final entry = ordered[index];
        final media = asMap(entry['media']);
        return MoviePosterTile(
          title: media.s('title') ?? '',
          posterUrl: app.imageUrl(posterPathFor(media), size: 'w185'),
          onTap: () => openMedia(context, media),
          onCheck: () => _markMovieWatched(entry),
        );
      },
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


/// Equal-width row of quick links, so Lists / Calendar / Progress etc. are one
/// tap away instead of hidden in the overflow menu.
class _Shortcuts extends StatelessWidget {
  const _Shortcuts({required this.onSelected});

  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    const items = [
      ('lists', Icons.view_list_rounded, 'Lists'),
      ('calendar', Icons.calendar_month_rounded, 'Calendar'),
      ('progress', Icons.timelapse_rounded, 'Progress'),
      ('dropped', Icons.do_not_disturb_on_outlined, 'Dropped'),
      ('requests', Icons.download_rounded, 'Requests'),
    ];
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
