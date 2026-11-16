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
import 'browse_screen.dart';
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
      'scrobr_home_${app.userId ?? 0}_${app.server.hashCode}';

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
      app.tryGet('/history/continue-watching', {'limit': 12}),
      app.tryGet('/history/next-up', {'limit': 12}),
      app.tryGet('/media/recently-added', {'type': 'movie', 'limit': 20}),
      app.tryGet('/media/recently-added', {'type': 'episode', 'limit': 20}),
      app.tryGet('/media/trending/movies'),
      app.tryGet('/media/trending/shows'),
      app.tryGet('/history/now-playing'),
      app.tryGet('/media/airing-today/collected'),
    ]);
    if (results.every((result) => result == null)) {
      throw Exception('Could not load your dashboard');
    }
    final data = _HomeData(
      continueWatching: asMaps(asMap(results[0])['continue_watching']),
      nextUp: asMaps(asMap(results[1])['next_up']),
      recentMovies: asMaps(asMap(results[2])['results']),
      recentEpisodes: asMaps(asMap(results[3])['results']),
      trendingMovies: asMaps(asMap(results[4])['results']),
      trendingShows: asMaps(asMap(results[5])['results']),
      nowPlaying: asMaps(asMap(results[6])['now_playing']),
      airingToday: asMaps(asMap(results[7])['results']),
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

  Future<void> _clearSessions() async {
    try {
      await ScrobScope.of(context).delete('/history/sessions');
      await _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not clear sessions: $e')),
        );
      }
    }
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
            return const DashboardSkeleton();
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
          final hero = data.continueWatching.isNotEmpty
              ? data.continueWatching.first
              : null;
          return RefreshIndicator(
            onRefresh: _reload,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                if (app.isApiKeyMode)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: kAccent.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.key_rounded, size: 16, color: kAccentSoft),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'API-key session: account, comments and admin screens are limited.',
                            style: TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ),
                      ],
                    ),
                  ),
                _Shortcuts(onSelected: _openMenu),
                if (hero != null) _ContinueHero(item: hero),
                if (data.nowPlaying.isNotEmpty)
                  _NowPlayingStrip(
                    sessions: data.nowPlaying,
                    onClear: _clearSessions,
                  ),
                MediaRow(
                  title: 'Continue Watching',
                  items: data.continueWatching
                      .map((e) => asMap(e['media']))
                      .toList(),
                  onSeeAll: () => pushScreen(context, const ContinueWatchingScreen()),
                ),
                MediaRow(
                  title: 'Next Up',
                  items: data.nextUp,
                  onSeeAll: () => pushScreen(context, const NextUpScreen()),
                  onWatchToggle: (item) async {
                    final changed = await toggleWatched(
                      context,
                      {...item, 'type': item.s('type') ?? 'episode'},
                      target: true,
                      promptRating: false,
                    );
                    if (!changed || !mounted) return;
                    final app = ScrobScope.of(context);
                    _seenHistoryRevision = app.historyRevision;
                    setState(() {
                      _data = _data?.withoutNextUp(item);
                    });
                    _reload();
                  },
                ),
                MediaRow(
                  title: 'Airing Today',
                  items: data.airingToday,
                  onSeeAll: () => pushScreen(
                    context,
                    BrowseScreen.airingToday(),
                  ),
                ),
                MediaRow(
                  title: 'Recently Added Movies',
                  items: data.recentMovies,
                  onSeeAll: () => pushScreen(
                    context,
                    BrowseScreen.recentlyAdded(type: 'movie'),
                  ),
                ),
                MediaRow(
                  title: 'Recently Added Episodes',
                  items: data.recentEpisodes,
                  onSeeAll: () => pushScreen(
                    context,
                    BrowseScreen.recentlyAdded(type: 'episode'),
                  ),
                ),
                MediaRow(
                  title: 'Trending Movies',
                  items: data.trendingMovies,
                  onSeeAll: () => pushScreen(
                    context,
                    BrowseScreen.trending(type: 'movie'),
                  ),
                ),
                MediaRow(
                  title: 'Trending Shows',
                  items: data.trendingShows,
                  onSeeAll: () => pushScreen(
                    context,
                    BrowseScreen.trending(type: 'series'),
                  ),
                ),
                if (data.continueWatching.isEmpty &&
                    data.nextUp.isEmpty &&
                    data.recentMovies.isEmpty &&
                    data.recentEpisodes.isEmpty &&
                    data.trendingMovies.isEmpty &&
                    data.trendingShows.isEmpty)
                  const EmptyState(
                    title: 'Your dashboard is quiet',
                    body:
                        'Connect a media server in Settings, or add something from Discover.',
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HomeData {
  const _HomeData({
    required this.continueWatching,
    required this.nextUp,
    required this.recentMovies,
    required this.recentEpisodes,
    required this.trendingMovies,
    required this.trendingShows,
    required this.nowPlaying,
    required this.airingToday,
  });

  final List<Map<String, dynamic>> continueWatching;
  final List<Map<String, dynamic>> nextUp;
  final List<Map<String, dynamic>> recentMovies;
  final List<Map<String, dynamic>> recentEpisodes;
  final List<Map<String, dynamic>> trendingMovies;
  final List<Map<String, dynamic>> trendingShows;
  final List<Map<String, dynamic>> nowPlaying;
  final List<Map<String, dynamic>> airingToday;

  Map<String, dynamic> toJson() => {
        'continueWatching': continueWatching,
        'nextUp': nextUp,
        'recentMovies': recentMovies,
        'recentEpisodes': recentEpisodes,
        'trendingMovies': trendingMovies,
        'trendingShows': trendingShows,
        'nowPlaying': nowPlaying,
        'airingToday': airingToday,
      };

  factory _HomeData.fromJson(Map<String, dynamic> json) => _HomeData(
        continueWatching: asMaps(json['continueWatching']),
        nextUp: asMaps(json['nextUp']),
        recentMovies: asMaps(json['recentMovies']),
        recentEpisodes: asMaps(json['recentEpisodes']),
        trendingMovies: asMaps(json['trendingMovies']),
        trendingShows: asMaps(json['trendingShows']),
        nowPlaying: asMaps(json['nowPlaying']),
        airingToday: asMaps(json['airingToday']),
      );

  _HomeData withoutNextUp(Map<String, dynamic> item) {
    final tmdb = item.i('tmdb_id');
    final season = item.i('season_number');
    final episode = item.i('episode_number');
    return _HomeData(
      continueWatching: continueWatching,
      nextUp: nextUp
          .where((e) =>
              e.i('tmdb_id') != tmdb ||
              e.i('season_number') != season ||
              e.i('episode_number') != episode)
          .toList(),
      recentMovies: recentMovies,
      recentEpisodes: recentEpisodes,
      trendingMovies: trendingMovies,
      trendingShows: trendingShows,
      nowPlaying: nowPlaying,
      airingToday: airingToday,
    );
  }
}

class _ContinueHero extends StatelessWidget {
  const _ContinueHero({required this.item});

  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final media = asMap(item['media']);
    final backdrop = app.imageUrl(
      media.s('show_backdrop_path') ?? media.s('backdrop_path'),
      size: 'w780',
    );
    final title = media.s('show_title') ?? media.s('title') ?? '';
    final episode = media.s('type') == 'episode'
        ? 'S${media.i('season_number')}E${media.i('episode_number')} · ${media.s('title') ?? ''}'
        : yearOf(media.s('release_date'));
    final progress = item.d('progress_percent') ?? 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: kAccent.withValues(alpha: 0.12),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Stack(
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedArtwork(
                      url: backdrop,
                      fit: BoxFit.cover,
                      placeholder: Container(color: kCard),
                    ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.25),
                            Colors.transparent,
                            kBg.withValues(alpha: 0.75),
                            kBg,
                          ],
                          stops: const [0, 0.3, 0.7, 1],
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded,
                                size: 13, color: kAccentSoft),
                            SizedBox(width: 3),
                            Text(
                              'CONTINUE WATCHING',
                              style: TextStyle(
                                fontSize: 9,
                                letterSpacing: 1.2,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      right: 16,
                      bottom: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          if (episode.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: Text(
                                episode,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kMuted,
                                ),
                              ),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(child: ProgressBar(value: progress)),
                              const SizedBox(width: 10),
                              Text(
                                '${progress.round()}%',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(onTap: () => openMedia(context, media)),
                ),
              ),
            ],
          ),
        ),
      ),
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
                        Icon(items[i].$2, size: 20, color: kAccentSoft),
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

class _NowPlayingStrip extends StatelessWidget {
  const _NowPlayingStrip({required this.sessions, required this.onClear});

  final List<Map<String, dynamic>> sessions;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (sessions.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
      decoration: BoxDecoration(
        color: kGreen.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kGreen.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: const BoxDecoration(
                  color: kGreen,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: kGreen,
                ),
              ),
              const Spacer(),
              IconButton(
                visualDensity: VisualDensity.compact,
                tooltip: 'Clear sessions',
                onPressed: onClear,
                icon: const Icon(Icons.close_rounded, size: 16, color: kMuted),
              ),
            ],
          ),
          ...sessions.map((session) {
            final media = asMap(session['media']);
            final title = media.s('show_title') ?? media.s('title') ?? 'Unknown';
            final pct = session.d('progress_percent') ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6, right: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      Text(
                        '${pct.round()}%',
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  ProgressBar(value: pct, height: 3),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
