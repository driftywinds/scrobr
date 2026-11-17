import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../widgets/swipe_pages.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

const _historyTypes = ['', 'movie', 'episode'];

/// Paged history for one tab. Each tab keeps its own list so adjacent tabs can
/// be shown side by side while swiping.
class _Feed {
  final events = <Map<String, dynamic>>[];
  final scroll = ScrollController();
  int page = 1;
  int totalPages = 1;
  bool loading = false;
  bool started = false;
  String? error;
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _search = TextEditingController();
  final Map<String, _Feed> _feeds = {
    for (final type in _historyTypes) type: _Feed(),
  };
  int _seenRevision = -1;
  bool _searching = false;
  bool _initialised = false;
  String _type = '';
  String _query = '';

  @override
  void initState() {
    super.initState();
    for (final type in _historyTypes) {
      final feed = _feeds[type]!;
      feed.scroll.addListener(() {
        if (!feed.scroll.hasClients) return;
        final position = feed.scroll.position;
        if (position.pixels > position.maxScrollExtent - 500) {
          _load(type);
        }
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    if (!_initialised) {
      _initialised = true;
      _seenRevision = app.historyRevision;
    } else if (_seenRevision != app.historyRevision) {
      _seenRevision = app.historyRevision;
      _invalidateAll();
    }
  }

  @override
  void dispose() {
    _search.dispose();
    for (final feed in _feeds.values) {
      feed.scroll.dispose();
    }
    super.dispose();
  }

  /// Marks every tab stale. Tabs that are on screen (or kept alive next to it)
  /// reload themselves the next time they are built.
  void _invalidateAll() {
    setState(() {
      for (final feed in _feeds.values) {
        feed.started = false;
      }
    });
  }

  Future<void> _load(String type, {bool reset = false}) async {
    final feed = _feeds[type]!;
    if (feed.loading) return;
    if (!reset && feed.page > feed.totalPages) return;
    feed.started = true;
    setState(() {
      feed.loading = true;
      if (reset) {
        feed.page = 1;
        feed.totalPages = 1;
        feed.events.clear();
        feed.error = null;
      }
    });
    try {
      final data = asMap(await ScrobScope.of(context).get('/history', {
        'page': feed.page,
        'page_size': 30,
        if (type.isNotEmpty) 'type': type,
        if (_query.isNotEmpty) 'q': _query,
      }));
      if (!mounted) return;
      setState(() {
        feed.events.addAll(data.maps('results'));
        feed.totalPages = data.i('total_pages') ?? 1;
        feed.page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => feed.error = '$e');
    } finally {
      if (mounted) setState(() => feed.loading = false);
    }
  }

  void _setType(String value) {
    if (value == _type) return;
    setState(() => _type = value);
  }

  void _reload() => _invalidateAll();

  Future<void> _deleteEvent(int id) async {
    try {
      await ScrobScope.of(context).delete('/history/event/$id');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete entry: $e')),
        );
      }
    }
  }

  Future<void> _unwatch(Map<String, dynamic> media) async {
    final app = ScrobScope.of(context);
    try {
      await app.delete('/history/item', {
        if (media.i('id') != null) 'id': media.i('id'),
        'media_type': media.s('type'),
      });
      if (media.s('type') == 'movie') {
        final tmdb = media.i('tmdb_id');
        if (tmdb != null) app.noteMovieWatched(tmdb, false);
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not unwatch: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _search,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Search history',
                  isDense: true,
                ),
                onSubmitted: (value) {
                  _query = value.trim();
                  _reload();
                },
              )
            : const Text('History'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _search.clear();
                _query = '';
                _reload();
              }
            },
            icon: Icon(
              _searching ? Icons.close_rounded : Icons.search_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedTabs<String>(segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'episode', label: Text('Episodes')),
              ],
              selected: {_type},
              onSelectionChanged: (value) => _setType(value.first),
            ),
          ),
          Expanded(
            child: SwipePages(
              index: _historyTypes.indexOf(_type),
              onIndexChanged: (i) => _setType(_historyTypes[i]),
              itemCount: _historyTypes.length,
              itemBuilder: (context, i) => _buildList(_historyTypes[i]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList(String type) {
    final feed = _feeds[type]!;
    if (!feed.started && !feed.loading) {
      // First time this tab is built (or it was invalidated): fetch it.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !feed.started) _load(type, reset: true);
      });
    }
    if (feed.events.isEmpty && feed.loading) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: SkeletonBox(height: 99, radius: 12),
            ),
        ],
      );
    }
    if (feed.events.isEmpty && feed.error != null) {
      return ListView(
        children: [ErrorView(message: feed.error!, onRetry: () => _load(type, reset: true))],
      );
    }
    if (feed.events.isEmpty) {
      return ListView(
        children: const [
          EmptyState(
            title: 'No watch history yet',
            body: 'Mark something watched or connect a media server.',
          ),
        ],
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    String? lastDate;
    final children = <Widget>[];
    for (final event in feed.events) {
      final watchedAt =
          DateTime.tryParse(event.s('watched_at') ?? '')?.toLocal();
      final date = watchedAt == null
          ? 'Unknown date'
          : DateTime(watchedAt.year, watchedAt.month, watchedAt.day) == today
              ? 'Today'
              : DateTime(watchedAt.year, watchedAt.month, watchedAt.day) ==
                      today.subtract(const Duration(days: 1))
                  ? 'Yesterday'
                  : fmtDay(watchedAt);
      if (date != lastDate) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
            child: Row(
              children: [
                if (date == 'Today')
                  Container(
                    width: 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: kAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                Text(
                  date.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: date == 'Today' ? kAccentSoft : kMuted,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(child: Divider()),
              ],
            ),
          ),
        );
        lastDate = date;
      }
      children.add(_HistoryTile(
        event: event,
        onTap: () => openMedia(context, asMap(event['media'])),
        onDelete: () {
          final id = event.i('id');
          if (id != null) _deleteEvent(id);
        },
        onUnwatch: () => _unwatch(asMap(event['media'])),
      ));
    }
    if (feed.loading) {
      children.add(
        const Padding(
          padding: EdgeInsets.all(16),
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => _load(type, reset: true),
      child: ListView(
        controller: feed.scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 24),
        children: children,
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.event,
    required this.onTap,
    required this.onDelete,
    required this.onUnwatch,
  });

  final Map<String, dynamic> event;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onUnwatch;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final media = asMap(event['media']);
    final isEpisode = media.s('type') == 'episode';
    final poster = app.imageUrl(posterPathFor(media), size: 'w185');
    final title = media.s('show_title') ?? media.s('title') ?? '';
    final episode = isEpisode
        ? 'S${media.i('season_number')}E${media.i('episode_number')} · ${media.s('title') ?? ''}'
        : yearOf(media.s('release_date'));
    final time = event.s('watched_at') != null
        ? fmtDateTime(event.s('watched_at')).split(', ').last
        : '';
    final source = event.s('source');
    final progress = event.d('progress_percent');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: kSurface,
        borderRadius: BorderRadius.circular(kRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kRadius),
          onTap: onTap,
          child: Container(
        padding: const EdgeInsets.fromLTRB(8, 8, 2, 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(kRadius),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 58,
              height: 87,
              child: Poster(url: poster, title: title, radius: 7),
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
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (episode.isNotEmpty)
                    Text(
                      episode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: kMuted),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.schedule_rounded, size: 12, color: kMuted),
                      const SizedBox(width: 4),
                      Text(
                        time,
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                      if (source != null &&
                          source.isNotEmpty &&
                          source != 'import' &&
                          source != 'manual') ...[
                        const SizedBox(width: 6),
                        TagChip(label: source),
                      ],
                      if (progress != null && progress > 0 && progress < 95)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '${progress.round()}%',
                            style: const TextStyle(
                              fontSize: 9,
                              color: kMuted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              iconSize: 18,
              onSelected: (value) {
                if (value == 'delete') onDelete();
                if (value == 'unwatch') onUnwatch();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'unwatch', child: Text('Unwatch title')),
                PopupMenuItem(value: 'delete', child: Text('Delete entry')),
              ],
            ),
          ],
        ),
          ),
        ),
      ),
    );
  }
}
