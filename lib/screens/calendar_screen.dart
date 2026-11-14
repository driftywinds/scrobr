import 'package:material_ui/material_ui.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import '../widgets/skeleton.dart';
import 'episode_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Future<Map<String, dynamic>>? _future;
  bool _refreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async =>
      asMap(await ScrobScope.of(context).get('/calendar', {'days': 21}));

  void _reload() => setState(() => _future = _load());

  Future<void> _refresh() async {
    setState(() => _refreshing = true);
    try {
      await ScrobScope.of(context).post('/calendar/refresh');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not refresh calendar: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            onPressed: _refreshing ? null : _refresh,
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SkeletonList(rows: 5);
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: describeError(snapshot.error!),
              onRetry: _reload,
            );
          }
          final data = snapshot.data ?? const {};
          final calendar = asMap(data['calendar']);
          final entries = calendar.maps('entries');
          if (entries.isEmpty) {
            return const EmptyState(
              title: 'Nothing airing',
              body:
                  'Episodes from shows in your library will appear here for the next few weeks.',
              icon: Icons.calendar_month_outlined,
            );
          }
          final grouped = <String, List<Map<String, dynamic>>>{};
          for (final entry in entries) {
            final date = entry.s('air_date') ?? 'Unknown';
            grouped.putIfAbsent(date, () => []).add(entry);
          }
          final dates = grouped.keys.toList()..sort();
          return RefreshIndicator(
            onRefresh: () async {
              _reload();
              await _future;
            },
            child: ListView(
              padding: const EdgeInsets.only(bottom: 28),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Next 21 days · ${entries.length} episodes',
                    style: const TextStyle(fontSize: 13, color: kMuted),
                  ),
                ),
                ...dates.map((date) {
                  final items = grouped[date]!;
                  final parsed = DateTime.tryParse(date);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                        child: Text(
                          parsed == null
                              ? date
                              : '${fmtDay(parsed)}${date == calendar.s('today') ? ' · Today' : ''}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: date == calendar.s('today')
                                ? kAccent
                                : kMuted,
                          ),
                        ),
                      ),
                      ..._groupByShow(items)
                          .map((group) => _CalendarShowGroup(entries: group)),
                    ],
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

/// Episodes of the same show on the same day (a weekly drop of 2-4 episodes)
/// collapse into one poster with an episode list, instead of repeating the
/// identical poster once per episode.
List<List<Map<String, dynamic>>> _groupByShow(
  List<Map<String, dynamic>> items,
) {
  final groups = <String, List<Map<String, dynamic>>>{};
  for (final entry in items) {
    final key = '${entry.i('show_tmdb_id') ?? entry.s('show_title') ?? ''}';
    groups.putIfAbsent(key, () => []).add(entry);
  }
  return groups.values.toList();
}

class _CalendarShowGroup extends StatelessWidget {
  const _CalendarShowGroup({required this.entries});

  final List<Map<String, dynamic>> entries;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final first = entries.first;
    final poster = app.imageUrl(first.s('poster_path'), size: 'w185');
    final showTitle = first.s('show_title') ?? '';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 52,
            height: 78,
            child: Poster(url: poster, title: showTitle, radius: 7),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 2),
                  child: Text(
                    showTitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                for (final entry in entries) _CalendarEpisodeRow(entry: entry),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CalendarEpisodeRow extends StatelessWidget {
  const _CalendarEpisodeRow({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final showId = entry.i('show_tmdb_id');
    final season = entry.i('season_number');
    final episode = entry.i('episode_number');
    final name = entry.s('episode_name') ?? '';
    final label = 'S${season ?? '?'}E${episode ?? '?'}'
        '${name.isEmpty ? '' : ' · $name'}';

    // Only states that carry information get an icon; "airing" is the default
    // for everything on a calendar, so it gets nothing.
    Widget? status;
    if (entry.b('watched')) {
      status = const Icon(Icons.check_circle_rounded, size: 16, color: kGreen);
    } else if (entry.b('collected')) {
      status = const Icon(Icons.download_done_rounded, size: 16, color: kMuted);
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: showId == null || season == null || episode == null
          ? null
          : () => pushScreen(
                context,
                EpisodeScreen(
                  showTmdbId: showId,
                  seasonNumber: season,
                  episodeNumber: episode,
                  showTitle: entry.s('show_title'),
                ),
              ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: kMuted),
              ),
            ),
            if (status != null) ...[const SizedBox(width: 8), status],
          ],
        ),
      ),
    );
  }
}
