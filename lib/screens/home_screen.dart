import 'dart:convert';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
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
  Future<_HomeData>? _future;
  _HomeData? _data;
  bool _cacheRead = false;
  int _seenHistoryRevision = -1;
  String _tab = 'shows';

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
    _future ??= _load();
  }

  Future<void> _readCache(AppState app) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(app));
      if (raw == null || raw.isEmpty || !mounted || _data != null) return;
      final cached = _HomeData.fromJson(asMap(jsonDecode(raw)));
      setState(() => _data = cached);
    } catch (_) {
      // A corrupt cache should never block the network refresh.
    }
  }

  String _cacheKey(AppState app) =>
      'scrobr_up_next_${app.userId ?? 0}_${app.server.hashCode}';

  Future<void> _saveCache(AppState app, _HomeData data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(app), jsonEncode(data.toJson()));
    } catch (_) {
      // Cache writes are best-effort.
    }
  }

  Future<_HomeData> _load() async {
    final app = ScrobScope.of(context);
    final results = await Future.wait([
      app.tryGet('/history/next-up', {'limit': 100}),
      app.tryGet('/history/progress', {
        'type': 'watched',
        'sort': 'recent',
        'page_size': 200,
      }),
      app.tryGet('/history/continue-watching', {'limit': 100}),
    ]);
    if (results.every((result) => result == null)) {
      throw Exception('Could not load your Up Next');
    }
    final data = _HomeData(
      shows: asMaps(asMap(results[0])['next_up']),
      progress: asMaps(asMap(results[1])['shows']),
      movies: asMaps(asMap(results[2])['continue_watching'])
          .where((entry) => asMap(entry['media']).s('type') == 'movie')
          .toList(),
    );
    _data = data;
    _saveCache(app, data);
    return data;
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
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
            onPressed: () => openSearch(context),
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
      body: FutureBuilder<_HomeData>(
        future: _future,
        builder: (context, snapshot) {
          final data = snapshot.data ?? _data;
          if (data == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const _UpNextSkeleton();
          }
          if (data == null && snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          if (data == null) {
            return const EmptyState(title: 'Nothing to show yet');
          }
          return Column(
            children: [
              if (app.isApiKeyMode) _ApiKeyBanner(),
              _Shortcuts(onSelected: _openMenu),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: SegmentedTabs<String>(
                  segments: const [
                    ButtonSegment(value: 'shows', label: Text('Shows')),
                    ButtonSegment(value: 'movies', label: Text('Movies')),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) {
                    setState(() => _tab = value.first);
                  },
                ),
              ),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: _reload,
                  child: _tab == 'shows'
                      ? _buildShows(data)
                      : _buildMovies(data),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildShows(_HomeData data) {
    if (data.shows.isEmpty) {
      return _EmptyUpNext(
        title: 'You are all caught up',
        body: 'Start a show and its next episode will appear here.',
        icon: Icons.play_circle_outline_rounded,
      );
    }
    final progress = {
      for (final show in data.progress)
        if (show.i('tmdb_id') != null) show.i('tmdb_id')!: show,
    };
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: data.shows.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = data.shows[index];
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

  Widget _buildMovies(_HomeData data) {
    if (data.movies.isEmpty) {
      return _EmptyUpNext(
        title: 'No movies in progress',
        body:
            'Start watching a movie and it will appear here until you finish it.',
        icon: Icons.movie_outlined,
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: data.movies.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final entry = data.movies[index];
        final media = asMap(entry['media']);
        final pct = entry.d('progress_percent') ??
            media.d('progress_percent') ??
            0;
        return UpNextTile(
          title: media.s('title') ?? '',
          posterUrl: ScrobScope.of(context).imageUrl(
            posterPathFor(media),
            size: 'w185',
          ),
          subtitle: yearOf(media.s('release_date')),
          progress: pct.toDouble(),
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

class _HomeData {
  const _HomeData({
    required this.shows,
    required this.progress,
    required this.movies,
  });

  final List<Map<String, dynamic>> shows;
  final List<Map<String, dynamic>> progress;
  final List<Map<String, dynamic>> movies;

  Map<String, dynamic> toJson() => {
        'shows': shows,
        'progress': progress,
        'movies': movies,
      };

  factory _HomeData.fromJson(Map<String, dynamic> json) => _HomeData(
        shows: asMaps(json['shows']),
        progress: asMaps(json['progress']),
        movies: asMaps(json['movies']),
      );
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
