import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final List<Map<String, dynamic>> _events = [];
  int _page = 1;
  int _totalPages = 1;
  bool _loading = false;
  bool _started = false;
  bool _searching = false;
  String? _error;
  String _type = '';
  String _query = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load(reset: true);
    }
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 500) {
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!reset && _page > _totalPages) return;
    setState(() {
      _loading = true;
      if (reset) {
        _page = 1;
        _totalPages = 1;
        _events.clear();
        _error = null;
      }
    });
    try {
      final data = asMap(await ScrobScope.of(context).get('/history', {
        'page': _page,
        'page_size': 30,
        if (_type.isNotEmpty) 'type': _type,
        if (_query.isNotEmpty) 'q': _query,
      }));
      if (!mounted) return;
      setState(() {
        _events.addAll(data.maps('results'));
        _totalPages = data.i('total_pages') ?? 1;
        _page += 1;
      });
    } catch (e) {
      if (mounted) setState(() => _error = describeError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _reload() {
    _load(reset: true);
  }

  /// Removes the entry from the list immediately and only tells the server
  /// once the "Undo" snackbar closes without being tapped, so a mis-tap never
  /// costs a watch record.
  Future<void> _deleteEvent(int id) async {
    final index = _events.indexWhere((e) => e.i('id') == id);
    if (index < 0) return;
    final app = ScrobScope.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final removed = _events[index];
    setState(() => _events.removeAt(index));

    messenger.hideCurrentSnackBar();
    final reason = await messenger
        .showSnackBar(
          SnackBar(
            content: const Text('Entry removed'),
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'Undo', onPressed: () {}),
          ),
        )
        .closed;

    if (reason == SnackBarClosedReason.action) {
      if (!mounted) return;
      setState(() {
        final at = index > _events.length ? _events.length : index;
        _events.insert(at, removed);
      });
      return;
    }
    try {
      await app.delete('/history/event/$id');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        final at = index > _events.length ? _events.length : index;
        _events.insert(at, removed);
      });
      messenger.showSnackBar(
        SnackBar(content: Text('Could not delete entry: ${describeError(e)}')),
      );
    }
  }

  Future<void> _unwatch(Map<String, dynamic> media) async {
    final app = ScrobScope.of(context);
    try {
      await app.delete('/history/item', {
        if (media.i('id') != null) 'id': media.i('id'),
        'media_type': media.s('type'),
      });
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
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: '', label: Text('All')),
                ButtonSegment(value: 'movie', label: Text('Movies')),
                ButtonSegment(value: 'episode', label: Text('Episodes')),
              ],
              selected: {_type},
              onSelectionChanged: (value) {
                setState(() => _type = value.first);
                _reload();
              },
            ),
          ),
          Expanded(child: _buildList()),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_events.isEmpty && _loading) {
      return const SkeletonList();
    }
    if (_events.isEmpty && _error != null) {
      return ListView(
        children: [ErrorView(message: _error!, onRetry: _reload)],
      );
    }
    if (_events.isEmpty) {
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
    for (final event in _events) {
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
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Text(
              date,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1,
                color: kMuted,
              ),
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
    if (_loading) {
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
      onRefresh: () async {
        _reload();
      },
      child: ListView(
        controller: _scroll,
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
    // "import" / "manual" describe nearly every row, so showing them is just
    // noise. Only surface sources that tell you something (plex, jellyfin..).
    final rawSource = event.s('source');
    final source = rawSource != null &&
            !const {'import', 'manual', 'scrob'}
                .contains(rawSource.toLowerCase())
        ? rawSource
        : null;
    final progress = event.d('progress_percent');

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (episode.isNotEmpty)
                    Text(
                      episode,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, color: kMuted),
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        time,
                        style: const TextStyle(fontSize: 12, color: kMuted),
                      ),
                      if (source != null && source.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        TagChip(label: source),
                      ],
                      if (progress != null && progress > 0 && progress < 95)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            '${progress.round()}%',
                            style: const TextStyle(
                              fontSize: 12,
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
    );
  }
}
