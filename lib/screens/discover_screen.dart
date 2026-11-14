import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'browse_screen.dart';

class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  String _type = 'movie';
  Future<_DiscoverData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_DiscoverData> _load() async {
    final app = ScrobScope.of(context);
    final isMovie = _type == 'movie';
    final results = await Future.wait([
      app.tryGet(isMovie ? '/media/trending/movies' : '/media/trending/shows'),
      app.tryGet(isMovie ? '/media/now-playing' : '/media/on-air-this-week'),
      app.tryGet(isMovie ? '/media/upcoming' : '/media/new-episodes'),
      app.tryGet(isMovie ? '/media/top-rated-movies' : '/media/top-rated-shows'),
      app.tryGet('/media/hidden-gems', {'type': _type}),
      app.tryGet('/media/for-you'),
      app.tryGet('/media/streaming', {'type': _type}),
    ]);
    return _DiscoverData(
      trending: asMaps(asMap(results[0])['results']),
      nowPlaying: asMaps(asMap(results[1])['results']),
      upcoming: asMaps(asMap(results[2])['results']),
      topRated: asMaps(asMap(results[3])['results']),
      hiddenGems: asMaps(asMap(results[4])['results']),
      forYou: asMaps(asMap(results[5])['results']),
      streaming: asMaps(asMap(results[6])['results']),
    );
  }

  Future<void> _reload() async {
    final next = _load();
    setState(() => _future = next);
    await next;
  }

  void _setType(String value) {
    if (value == _type) return;
    setState(() {
      _type = value;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            onPressed: () => openSearch(context),
            icon: const Icon(Icons.search_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'series', label: Text('Shows')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => _setType(value.first),
            ),
          ),
          Expanded(
            child: FutureBuilder<_DiscoverData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView(label: 'Finding something to watch');
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final data = snapshot.data;
                if (data == null) {
                  return const EmptyState(title: 'Nothing to discover');
                }
                return RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 28),
                    children: [
                      MediaRow(
                        title: 'Trending ${_type == 'movie' ? 'Movies' : 'Shows'}',
                        items: data.trending,
                        onSeeAll: () => pushScreen(
                          context,
                          BrowseScreen.trending(type: _type),
                        ),
                      ),
                      MediaRow(
                        title: _type == 'movie' ? 'Now Playing' : 'On Air This Week',
                        items: data.nowPlaying,
                      ),
                      MediaRow(
                        title: _type == 'movie' ? 'Upcoming' : 'New Episodes',
                        items: data.upcoming,
                      ),
                      MediaRow(
                        title: 'Top Rated',
                        items: data.topRated,
                        onSeeAll: () => pushScreen(
                          context,
                          BrowseScreen.topRated(type: _type),
                        ),
                      ),
                      MediaRow(title: 'For You', items: data.forYou),
                      MediaRow(
                        title: 'Hidden Gems',
                        items: data.hiddenGems,
                      ),
                      MediaRow(
                        title: 'On Your Services',
                        items: data.streaming,
                      ),
                      if (data.trending.isEmpty &&
                          data.nowPlaying.isEmpty &&
                          data.upcoming.isEmpty &&
                          data.topRated.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: kSurface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Metadata is not available',
                                  style: TextStyle(fontWeight: FontWeight.w700),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'An admin needs a TMDB key in the Scrob admin settings to power Discover.',
                                  style: TextStyle(color: kMuted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DiscoverData {
  const _DiscoverData({
    required this.trending,
    required this.nowPlaying,
    required this.upcoming,
    required this.topRated,
    required this.hiddenGems,
    required this.forYou,
    required this.streaming,
  });

  final List<Map<String, dynamic>> trending;
  final List<Map<String, dynamic>> nowPlaying;
  final List<Map<String, dynamic>> upcoming;
  final List<Map<String, dynamic>> topRated;
  final List<Map<String, dynamic>> hiddenGems;
  final List<Map<String, dynamic>> forYou;
  final List<Map<String, dynamic>> streaming;
}
