import 'package:material_ui/material_ui.dart';

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

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
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
    ]);
    return _HomeData(
      continueWatching: asMaps(asMap(results[0])['continue_watching']),
      nextUp: asMaps(asMap(results[1])['next_up']),
      recentMovies: asMaps(asMap(results[2])['results']),
      recentEpisodes: asMaps(asMap(results[3])['results']),
      trendingMovies: asMaps(asMap(results[4])['results']),
      trendingShows: asMaps(asMap(results[5])['results']),
      nowPlaying: asMaps(asMap(results[6])['now_playing']),
    );
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
            Image.asset(
              'assets/scrob.png',
              width: 28,
              height: 28,
              errorBuilder: (_, __, ___) => const Icon(Icons.movie_filter),
            ),
            const SizedBox(width: 8),
            const Text('Scrob'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Search',
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
          IconButton(
            tooltip: 'Calendar',
            onPressed: () => openCalendar(context),
            icon: const Icon(Icons.calendar_month_outlined),
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
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView(label: 'Loading your dashboard');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final data = snapshot.data;
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
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: kAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'API-key session: account, comments and admin screens are limited.',
                      style: TextStyle(fontSize: 11, color: kMuted),
                    ),
                  ),
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
  });

  final List<Map<String, dynamic>> continueWatching;
  final List<Map<String, dynamic>> nextUp;
  final List<Map<String, dynamic>> recentMovies;
  final List<Map<String, dynamic>> recentEpisodes;
  final List<Map<String, dynamic>> trendingMovies;
  final List<Map<String, dynamic>> trendingShows;
  final List<Map<String, dynamic>> nowPlaying;
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
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => openMedia(context, media),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop != null)
                  Image.network(backdrop, fit: BoxFit.cover)
                else
                  Container(color: kCard),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        kBg.withValues(alpha: 0.6),
                        kBg,
                      ],
                      stops: const [0.2, 0.65, 1],
                    ),
                  ),
                ),
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'CONTINUE WATCHING',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1.4,
                          fontWeight: FontWeight.w800,
                          color: kAccent,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (episode.isNotEmpty)
                        Text(
                          episode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11, color: kMuted),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(child: ProgressBar(value: progress)),
                          const SizedBox(width: 10),
                          Text(
                            '${progress.round()}%',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
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
        ),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'NOW PLAYING',
                style: TextStyle(
                  fontSize: 9,
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
                icon: const Icon(Icons.close_rounded, size: 14),
              ),
            ],
          ),
          ...sessions.map((session) {
            final media = asMap(session['media']);
            final title = media.s('show_title') ?? media.s('title') ?? 'Unknown';
            final pct = session.d('progress_percent') ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  const Icon(Icons.play_circle_fill, color: kGreen, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  Text(
                    '${pct.round()}%',
                    style: const TextStyle(fontSize: 10, color: kMuted),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}


