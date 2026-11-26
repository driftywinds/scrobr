import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../core/friendly_error.dart';

class ContinueWatchingScreen extends StatefulWidget {
  const ContinueWatchingScreen({super.key});

  @override
  State<ContinueWatchingScreen> createState() => _ContinueWatchingScreenState();
}

class _ContinueWatchingScreenState extends State<ContinueWatchingScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = asMap(
      await ScrobScope.of(context)
          .get('/history/continue-watching', {'limit': 100}),
    );
    return data.maps('continue_watching');
  }

  Future<void> _dismiss(int mediaId) async {
    final app = ScrobScope.of(context);
    await app.delete('/history/continue-watching', {'media_id': mediaId});
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Continue Watching')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListRowsSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final items = snapshot.data ?? const [];
          if (items.isEmpty) {
            return const EmptyState(
              title: 'Nothing in progress',
              body: 'Start watching something and it will show up here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final entry = items[index];
                final media = asMap(entry['media']);
                final pct = entry.d('progress_percent') ?? 0;
                return _WideMediaTile(
                  media: media,
                  subtitle:
                      'S${media.i('season_number') ?? ''}E${media.i('episode_number') ?? ''} · ${pct.round()}% watched',
                  trailing: IconButton(
                    tooltip: 'Dismiss',
                    onPressed: () {
                      final id = media.i('id');
                      if (id != null) _dismiss(id);
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                  progress: pct,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class NextUpScreen extends StatefulWidget {
  const NextUpScreen({super.key});

  @override
  State<NextUpScreen> createState() => _NextUpScreenState();
}

class _NextUpScreenState extends State<NextUpScreen> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  bool _includeHidden = false;
  bool _searching = false;
  int _seenHistoryRevision = -1;
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<Map<String, dynamic>> _filter(List<Map<String, dynamic>> items) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return items;
    return items.where((item) {
      final text = [
        item.s('show_title'),
        item.s('title'),
        item.s('episode_name'),
        if (item.i('season_number') != null)
          's${item.i('season_number')}',
        if (item.i('episode_number') != null)
          'e${item.i('episode_number')}',
      ].whereType<String>().join(' ').toLowerCase();
      return text.contains(query);
    }).toList();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    if (_seenHistoryRevision < 0) {
      _seenHistoryRevision = app.historyRevision;
    } else if (_seenHistoryRevision != app.historyRevision) {
      _seenHistoryRevision = app.historyRevision;
      if (mounted) setState(() => _future = _load());
    }
    _future ??= _load();
  }

  Future<void> _markWatched(Map<String, dynamic> item) async {
    final changed = await toggleWatched(
      context,
      {...item, 'type': item.s('type') ?? 'episode'},
      target: true,
      promptRating: false,
    );
    if (!changed || !mounted) return;
    final app = ScrobScope.of(context);
    _seenHistoryRevision = app.historyRevision;
    setState(() => _future = _load());
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = asMap(await ScrobScope.of(context).get(
      '/history/next-up',
      {'limit': 100, 'include_hidden': _includeHidden},
    ));
    return data.maps('next_up');
  }

  Future<void> _hide(int showId) async {
    await ScrobScope.of(context)
        .post('/history/next-up/hide', {'show_id': showId});
    if (!mounted) return;
    setState(() => _future = _load());
  }

  Future<void> _unhide(int showId) async {
    await ScrobScope.of(context)
        .delete('/history/next-up/hide', {'show_id': showId});
    if (!mounted) return;
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Next Up'),
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search Next Up',
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _search.clear();
                  _query = '';
                }
              });
            },
            icon: Icon(
              _searching ? Icons.search_off_rounded : Icons.search_rounded,
            ),
          ),
          IconButton(
            tooltip: _includeHidden ? 'Hide hidden shows' : 'Show hidden shows',
            onPressed: () {
              setState(() => _includeHidden = !_includeHidden);
              setState(() => _future = _load());
            },
            icon: Icon(
              _includeHidden
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => setState(() => _future = _load()),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_searching)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 4),
              child: TextField(
                controller: _search,
                autofocus: true,
                onChanged: (value) => setState(() => _query = value),
                textInputAction: TextInputAction.search,
                autocorrect: false,
                decoration: InputDecoration(
                  hintText: 'Search shows or episodes',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Clear search',
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
              ),
            ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListRowsSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: friendlyError(snapshot.error),
                    onRetry: () => setState(() => _future = _load()),
                  );
                }
                final all = snapshot.data ?? const [];
                final items = _filter(all);
                if (all.isEmpty) {
                  return const EmptyState(
                    title: 'You are all caught up',
                    body:
                        'Watch an episode and the next one will appear here.',
                  );
                }
                if (items.isEmpty) {
                  return const EmptyState(
                    title: 'No matches',
                    body: 'Try a show name or episode number.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    setState(() => _future = _load());
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final left = item.i('episodes_left');
                      return _WideMediaTile(
                        media: item,
                        subtitle:
                            'S${item.i('season_number')}E${item.i('episode_number')} · ${item.s('show_title') ?? ''}${left != null ? ' · $left left' : ''}',
                        onWatchToggle: () => _markWatched(item),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            final showId = item.i('show_id');
                            if (showId == null) return;
                            if (value == 'hide') _hide(showId);
                            if (value == 'unhide') _unhide(showId);
                          },
                          itemBuilder: (_) => [
                            if (item.b('next_up_hidden'))
                              const PopupMenuItem(
                                value: 'unhide',
                                child: Text('Unhide show'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'hide',
                                child: Text('Hide show'),
                              ),
                          ],
                        ),
                      );
                    },
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

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  String _type = 'watched';
  bool _hideComplete = false;
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final app = ScrobScope.of(context);
    final data = asMap(await app.get('/history/progress', {
      'type': _type,
      'sort': 'recent',
      'hide_complete': _hideComplete,
      'page_size': 200,
    }));
    return data.maps('shows');
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Progress')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
            child: SegmentedTabs<String>(segments: const [
                ButtonSegment(value: 'watched', label: Text('Watched')),
                ButtonSegment(value: 'collection', label: Text('Collected')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
                _reload();
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilterChip(
                label: const Text('Hide completed'),
                avatar: Icon(
                  _hideComplete
                      ? Icons.check_rounded
                      : Icons.visibility_off_outlined,
                  size: 16,
                ),
                selected: _hideComplete,
                showCheckmark: false,
                onSelected: (value) {
                  setState(() => _hideComplete = value);
                  _reload();
                },
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const ListRowsSkeleton();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: friendlyError(snapshot.error),
                    onRetry: _reload,
                  );
                }
                final shows = snapshot.data ?? const [];
                if (shows.isEmpty) {
                  return EmptyState(
                    title: _hideComplete
                        ? 'Everything here is finished'
                        : 'No progress to show',
                    body: _hideComplete
                        ? 'Turn off "Hide completed" to see finished shows.'
                        : 'Start a show and its progress will appear here.',
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    _reload();
                    await _future;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: shows.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (context, index) {
                      final show = shows[index];
                      final watched = show.i('episodes_watched') ?? 0;
                      final total = show.i('episodes_total') ?? 0;
                      final pct = show.d('watch_pct') ?? 0;
                      return _WideMediaTile(
                        media: {
                          'type': 'series',
                          'tmdb_id': show.i('tmdb_id'),
                          'title': show.s('title'),
                          'poster_path': show.s('poster_path'),
                        },
                        subtitle: pct >= 100
                            ? 'Completed · $total episodes'
                            : '$watched / $total episodes · ${pct.round()}%',
                        progress: pct,
                        onTap: show.i('tmdb_id') == null
                            ? null
                            : () => openShow(context, show.i('tmdb_id')!),
                      );
                    },
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

class DroppedScreen extends StatefulWidget {
  const DroppedScreen({super.key});

  @override
  State<DroppedScreen> createState() => _DroppedScreenState();
}

class _DroppedScreenState extends State<DroppedScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      asMap(await ScrobScope.of(context).get('/history/dropped'));

  Future<void> _undropShow(int showId) async {
    await ScrobScope.of(context)
        .delete('/history/drop/show', {'show_id': showId});
    if (mounted) setState(() => _future = _load());
  }

  Future<void> _undropMovie(int mediaId) async {
    await ScrobScope.of(context)
        .delete('/history/drop/movie', {'media_id': mediaId});
    if (mounted) setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dropped')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ListRowsSkeleton();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: friendlyError(snapshot.error),
              onRetry: () => setState(() => _future = _load()),
            );
          }
          final data = snapshot.data ?? const {};
          final shows = data.maps('shows');
          final movies = data.maps('movies');
          if (shows.isEmpty && movies.isEmpty) {
            return const EmptyState(
              title: 'Nothing dropped',
              body: 'Shows and movies you drop will appear here.',
            );
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _load());
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
              children: [
                if (shows.isNotEmpty) const SectionHeader(title: 'Shows'),
                ...shows.map((show) {
                  final id = show.i('tmdb_id');
                  return _WideMediaTile(
                    media: {
                      'type': 'series',
                      'tmdb_id': id,
                      'title': show.s('title'),
                      'poster_path': show.s('poster_path'),
                    },
                    subtitle: show.s('status') ?? '',
                    onTap: id == null ? null : () => openShow(context, id),
                    trailing: TextButton(
                      onPressed: () {
                        final internal = show.i('id');
                        if (internal != null) _undropShow(internal);
                      },
                      child: const Text('Undrop'),
                    ),
                  );
                }),
                if (movies.isNotEmpty) const SectionHeader(title: 'Movies'),
                ...movies.map((movie) {
                  final tmdb = movie.i('tmdb_id');
                  return _WideMediaTile(
                    media: {
                      'type': 'movie',
                      'tmdb_id': tmdb,
                      'title': movie.s('title'),
                      'poster_path': movie.s('poster_path'),
                      'release_date': movie.s('release_date'),
                    },
                    subtitle: yearOf(movie.s('release_date')),
                    onTap: tmdb == null ? null : () => openMovie(context, tmdb),
                    trailing: TextButton(
                      onPressed: () {
                        final mediaId = movie.i('media_id');
                        if (mediaId != null) _undropMovie(mediaId);
                      },
                      child: const Text('Undrop'),
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _WideMediaTile extends StatelessWidget {
  const _WideMediaTile({
    required this.media,
    this.subtitle,
    this.trailing,
    this.progress,
    this.onTap,
    this.onWatchToggle,
  });

  final Map<String, dynamic> media;
  final String? subtitle;
  final Widget? trailing;
  final double? progress;
  final VoidCallback? onTap;
  final Future<void> Function()? onWatchToggle;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final poster = app.imageUrl(posterPathFor(media), size: 'w185');
    final title = media.s('show_title') ?? media.s('title') ?? '';
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap ?? () => openMedia(context, media),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              height: 93,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Poster(url: poster, title: title, radius: 8),
                  if (onWatchToggle != null && !media.b('watched'))
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Material(
                        color: Colors.black.withValues(alpha: 0.7),
                        shape: const CircleBorder(),
                        child: Tooltip(
                          message: 'Mark watched',
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              onWatchToggle!.call();
                            },
                            child: const Padding(
                              padding: EdgeInsets.all(7),
                              child: Icon(
                                Icons.check_rounded,
                                size: 18,
                                color: Colors.white,
                              ),
                            ),
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
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                    ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    ProgressBar(value: progress!),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
