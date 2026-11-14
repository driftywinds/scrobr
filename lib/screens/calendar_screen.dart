import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
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
            return const LoadingView(label: 'Building your schedule');
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
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
                    style: const TextStyle(fontSize: 11, color: kMuted),
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
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: kMuted,
                          ),
                        ),
                      ),
                      ...items.map((entry) => _CalendarEntry(entry: entry)),
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

class _CalendarEntry extends StatelessWidget {
  const _CalendarEntry({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final poster = app.imageUrl(entry.s('poster_path'), size: 'w185');
    final showId = entry.i('show_tmdb_id');
    final season = entry.i('season_number');
    final episode = entry.i('episode_number');
    return InkWell(
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 69,
              child: Poster(
                url: poster,
                title: entry.s('show_title'),
                radius: 7,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.s('show_title') ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'S${season ?? '?'}E${episode ?? '?'} · ${entry.s('episode_name') ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: kMuted),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (entry.b('watched'))
                        const TagChip(label: 'Watched')
                      else if (entry.b('collected'))
                        const TagChip(label: 'Collected')
                      else
                        const TagChip(label: 'Airing'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
