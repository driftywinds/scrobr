import 'dart:math';

import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
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
      app.tryGet('/media/trending/trailers'),
    ]);
    if (results.every((result) => result == null)) {
      throw Exception('Could not load discovery');
    }
    return _DiscoverData(
      trending: asMaps(asMap(results[0])['results']),
      nowPlaying: asMaps(asMap(results[1])['results']),
      upcoming: asMaps(asMap(results[2])['results']),
      topRated: asMaps(asMap(results[3])['results']),
      hiddenGems: asMaps(asMap(results[4])['results']),
      forYou: asMaps(asMap(results[5])['results']),
      streaming: asMaps(asMap(results[6])['results']),
      trailers: asMaps(asMap(results[7])['results']),
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

  Future<void> _pick() async {
    final app = ScrobScope.of(context);
    try {
      final result = asMap(await app.get('/media/pick', {'type': _type}));
      if (!mounted) return;
      if (result.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Nothing to pick from yet')),
        );
        return;
      }
      openMedia(context, result);
    } on ApiException catch (e) {
      if (!e.message.contains('no_sources')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not pick: $e')),
          );
        }
        return;
      }
      // The server only personalises picks when the user has a streaming
      // service or media-server source. Fall back to public trending titles
      // so the button still does something useful.
      try {
        final data = asMap(await app.get(
          _type == 'movie' ? '/media/trending/movies' : '/media/trending/shows',
        ));
        final items = data.maps('results');
        if (items.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Add a source in Connections to get picks'),
              ),
            );
          }
          return;
        }
        if (!mounted) return;
        openMedia(context, items[Random().nextInt(items.length)]);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Picked from trending — add a source in Connections for personalised picks',
            ),
          ),
        );
      } catch (fallbackError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not pick: $fallbackError')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not pick: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
        actions: [
          IconButton(
            tooltip: 'Explore',
            onPressed: () => openExplore(context, type: _type),
            icon: const Icon(Icons.grid_view_rounded),
          ),
          IconButton(
            tooltip: 'Pick something for me',
            onPressed: _pick,
            icon: const Icon(Icons.casino_outlined),
          ),
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
            child: SegmentedTabs<String>(segments: const [
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
                  return const DashboardSkeleton();
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
                        title: 'Top Rated',
                        items: data.topRated,
                        onSeeAll: () => pushScreen(
                          context,
                          BrowseScreen.topRated(type: _type),
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
                      MediaRow(title: 'For You', items: data.forYou),
                      MediaRow(
                        title: 'Hidden Gems',
                        items: data.hiddenGems,
                      ),
                      MediaRow(
                        title: 'On Your Services',
                        items: data.streaming,
                      ),
                      if (_type == 'movie')
                        _TrailerRow(items: data.trailers),
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
    required this.trailers,
  });

  final List<Map<String, dynamic>> trending;
  final List<Map<String, dynamic>> nowPlaying;
  final List<Map<String, dynamic>> upcoming;
  final List<Map<String, dynamic>> topRated;
  final List<Map<String, dynamic>> hiddenGems;
  final List<Map<String, dynamic>> forYou;
  final List<Map<String, dynamic>> streaming;
  final List<Map<String, dynamic>> trailers;
}


class _TrailerRow extends StatelessWidget {
  const _TrailerRow({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 18, 16, 10),
          child: SectionHeader(title: 'Trending trailers'),
        ),
        SizedBox(
          height: 150,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = items[index];
              final url = ScrobScope.of(context)
                  .imageUrl(item.s('backdrop_path'), size: 'w300');
              return SizedBox(
                width: 210,
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () async {
                    final key = item.s('trailer_key');
                    if (key == null) return;
                    await launchUrl(
                      Uri.parse('https://www.youtube.com/watch?v=$key'),
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Poster(url: url, radius: 8),
                            const Center(
                              child: Icon(
                                Icons.play_circle_fill_rounded,
                                size: 38,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.s('title') ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
