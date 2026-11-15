import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/comments.dart';
import '../widgets/session.dart';
import '../widgets/trakt_comments.dart';
import '../widgets/common.dart';
import 'browse_screen.dart';

class MovieScreen extends StatefulWidget {
  const MovieScreen({super.key, required this.tmdbId});

  final int tmdbId;

  @override
  State<MovieScreen> createState() => _MovieScreenState();
}

class _MovieScreenState extends State<MovieScreen> {
  Future<_MovieData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_MovieData> _load() async {
    final app = ScrobScope.of(context);
    final results = await Future.wait([
      app.get('/media/movie/${widget.tmdbId}'),
      app.tryGet('/media/movie/${widget.tmdbId}/recommendations'),
    ]);
    return _MovieData(
      detail: asMap(results[0]),
      recommendations: asMaps(asMap(results[1])['results']),
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_MovieData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorView(
                message: '${snapshot.error}',
                onRetry: _reload,
              ),
            );
          }
          final data = snapshot.data!;
          return _MovieBody(
            data: data,
            reload: _reload,
          );
        },
      ),
    );
  }
}

class _MovieData {
  const _MovieData({required this.detail, required this.recommendations});

  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> recommendations;
}

class _MovieBody extends StatelessWidget {
  const _MovieBody({required this.data, required this.reload});

  final _MovieData data;
  final VoidCallback reload;

  Future<void> _act(BuildContext context, Future<bool> Function() action) async {
    final changed = await action();
    if (changed) reload();
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final media = data.detail;
    final title = media.s('title') ?? 'Movie';
    final backdrop = app.imageUrl(media.s('backdrop_path'), size: 'w780');
    final poster = app.imageUrl(media.s('poster_path'), size: 'w342');
    final rating = media.d('tmdb_rating');
    final genres = media.strings('genres');
    final cast = media.maps('cast');
    final crew = media.maps('crew');
    final collection = asMap(media['collection']);
    final releaseDates = asMap(media['release_dates']);
    final whereToWatch = media.maps('where_to_watch');
    final companies = media.maps('production_companies');
    final watched = media.b('watched');
    final userRating = media.d('user_rating');
    final playCount = media.i('play_count') ?? 0;

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 280,
          backgroundColor: kBg,
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 72, right: 16, bottom: 14),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            background: Stack(
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
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        kBg.withValues(alpha: 0.55),
                        kBg,
                      ],
                      stops: const [0, 0.3, 0.75, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  height: 162,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Poster(url: poster, title: title),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (media.s('tagline') != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            media.s('tagline')!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: kMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Row(
                        children: [
                          if (rating != null && rating > 0) ...[
                            RatingChip(rating: rating),
                            const SizedBox(width: 8),
                          ],
                          if (yearOf(media.s('release_date')).isNotEmpty)
                            TagChip(label: yearOf(media.s('release_date'))),
                          if (media.i('runtime') != null) ...[
                            const SizedBox(width: 6),
                            TagChip(label: fmtRuntime(media.i('runtime'))),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: genres.map((g) => TagChip(label: g)).toList(),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        [
                          if (media.s('status') != null) media.s('status')!,
                          if (media.s('age_rating') != null) media.s('age_rating')!,
                          if (playCount > 0) '$playCount plays',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: ActionGrid(
              children: [
                _ActionPill(
                  icon: watched ? Icons.check_circle : Icons.check_circle_outline,
                  label: watched ? 'Watched' : 'Mark watched',
                  active: watched,
                  onTap: () => _act(
                    context,
                    () => toggleWatched(context, media),
                  ),
                ),
                _ActionPill(
                  icon: Icons.star_outline_rounded,
                  label: userRating != null && userRating > 0
                      ? 'Rated ${fmtRating(userRating)}'
                      : 'Rate',
                  active: userRating != null && userRating > 0,
                  onTap: () => _act(
                    context,
                    () => openRatingDialog(context, media),
                  ),
                ),
                _ActionPill(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to list',
                  onTap: () => _act(
                    context,
                    () => addToListDialog(context, media),
                  ),
                ),
                _ActionPill(
                  icon: media.b('in_library')
                      ? Icons.library_add_check_rounded
                      : Icons.library_add_outlined,
                  label: media.b('in_library') ? 'In library' : 'Collect',
                  active: media.b('in_library'),
                  onTap: () => _act(
                    context,
                    () => toggleCollect(context, media),
                  ),
                ),
                _ActionPill(
                  icon: Icons.movie_outlined,
                  label: 'Trailer',
                  onTap: () => openTrailer(context, media),
                ),
                _ActionPill(
                  icon: Icons.timer_outlined,
                  label: 'Session',
                  onTap: () async {
                    await startManualSession(context, media);
                    reload();
                  },
                ),
                if (media.b('request_enabled'))
                  _ActionPill(
                    icon: Icons.download_rounded,
                    label: media.s('request_status') ?? 'Request',
                    onTap: () => _act(
                      context,
                      () => requestMedia(context, media),
                    ),
                  ),
                _ActionPill(
                  icon: Icons.more_horiz_rounded,
                  label: 'More',
                  onTap: () => _more(context, media),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              media.s('overview') ?? 'No overview available.',
              style: const TextStyle(fontSize: 13, height: 1.5, color: Color(0xFFD4D4D8)),
            ),
          ),
        ),
        if (collection.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  final id = collection.i('id');
                  if (id != null) pushScreen(context, BrowseScreen.collection(id));
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.collections_bookmark_outlined, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          collection.s('name') ?? 'Collection',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: kMuted),
                    ],
                  ),
                ),
              ),
            ),
          ),
        if (releaseDates.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Release dates',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  ...releaseDates.entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '${e.key[0].toUpperCase()}${e.key.substring(1)}: ${fmtDate('${e.value}')}',
                        style: const TextStyle(fontSize: 12, color: kMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (cast.isNotEmpty)
          SliverToBoxAdapter(
            child: PeopleRow(title: 'Cast', people: cast),
          ),
        if (crew.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Crew',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  ...crew.take(8).map(
                        (c) => Padding(
                          padding: const EdgeInsets.only(bottom: 3),
                          child: Text(
                            '${c.s('job') ?? ''} · ${c.s('name') ?? ''}',
                            style: const TextStyle(fontSize: 12, color: kMuted),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        if (whereToWatch.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Where to watch',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: whereToWatch
                        .map(
                          (w) => TagChip(
                            label:
                                '${w.s('name') ?? ''}${w.s('type') != null ? ' · ${w.s('type')}' : ''}',
                          ),
                        )
                        .toList(),
                  ),
                ],
              ),
            ),
          ),
        if (companies.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Production companies',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: companies.map((company) {
                      final id = company.i('id');
                      return ActionChip(
                        label: Text(
                          company.s('name') ?? '',
                          style: const TextStyle(fontSize: 11),
                        ),
                        onPressed: id == null
                            ? null
                            : () => openStudio(
                                  context,
                                  id,
                                  isNetwork: false,
                                ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        if (data.recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: MediaRow(
              title: 'More like this',
              items: data.recommendations,
            ),
          ),
        SliverToBoxAdapter(
          child: CommentsSection(
            mediaType: 'movie',
            tmdbId: media.i('tmdb_id'),
            title: 'Comments',
          ),
        ),
        SliverToBoxAdapter(
          child: TraktCommentsSection(
            mediaType: 'movie',
            tmdbId: media.i('tmdb_id'),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  Future<void> _more(BuildContext context, Map<String, dynamic> media) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.do_not_disturb_on_outlined),
              title: Text(media.b('dropped') ? 'Undrop movie' : 'Drop movie'),
              onTap: () => Navigator.pop(context, 'drop'),
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new_rounded),
              title: const Text('Open in TMDB'),
              onTap: () => Navigator.pop(context, 'tmdb'),
            ),
          ],
        ),
      ),
    );
    if (action == 'drop') {
      final changed = await toggleDrop(context, media);
      if (changed) reload();
    } else if (action == 'tmdb') {
      final id = media.i('tmdb_id');
      if (id != null) {
        await launchTmdb(id);
      }
    }
  }
}

Future<void> launchTmdb(int id) async {
  await launchUrl(
    Uri.parse('https://www.themoviedb.org/movie/$id'),
    mode: LaunchMode.externalApplication,
  );
}

class _ActionPill extends StatelessWidget {
  const _ActionPill({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionPill(icon: icon, label: label, active: active, onTap: onTap);
  }
}


