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
            return const DashboardSkeleton();
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
                    style: const TextStyle(fontSize: 12, color: kMuted),
                  ),
                ),
                ...dates.map((date) {
                  final items = grouped[date]!;
                  final parsed = DateTime.tryParse(date);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _DateHeader(
                        raw: date,
                        parsed: parsed,
                        isToday: date == calendar.s('today'),
                        count: items.length,
                      ),
                      ..._groupByShow(items).map(
                        (episodes) => _CalendarShowGroup(episodes: episodes),
                      ),
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

  List<List<Map<String, dynamic>>> _groupByShow(
    List<Map<String, dynamic>> items,
  ) {
    final groups = <Object, List<Map<String, dynamic>>>{};
    for (final item in items) {
      final key = item.i('show_tmdb_id') ?? item.s('show_title');
      groups.putIfAbsent(key ?? item, () => []).add(item);
    }
    return groups.values.toList();
  }
}

class _CalendarShowGroup extends StatelessWidget {
  const _CalendarShowGroup({required this.episodes});

  final List<Map<String, dynamic>> episodes;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final first = episodes.first;
    final poster = app.imageUrl(first.s('poster_path'), size: 'w185');
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(10),
      decoration: panelDecoration(),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 46,
            height: 69,
            child: Poster(
              url: poster,
              title: first.s('show_title'),
              radius: 7,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  first.s('show_title') ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                ...episodes.map((entry) {
                  final showId = entry.i('show_tmdb_id');
                  final season = entry.i('season_number');
                  final episode = entry.i('episode_number');
                  final label =
                      'S${season ?? '?'}E${episode ?? '?'} · ${entry.s('episode_name') ?? ''}';
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
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: kMuted,
                              ),
                            ),
                          ),
                          if (entry.b('watched'))
                            const TagChip(label: 'Watched')
                          else if (entry.b('collected'))
                            const TagChip(label: 'Collected'),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.raw,
    required this.parsed,
    required this.isToday,
    required this.count,
  });

  final String raw;
  final DateTime? parsed;
  final bool isToday;
  final int count;

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _months = [
    'JAN', 'FEB', 'MAR', 'APR', 'MAY', 'JUN',
    'JUL', 'AUG', 'SEP', 'OCT', 'NOV', 'DEC',
  ];

  @override
  Widget build(BuildContext context) {
    final d = parsed;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: isToday ? kAccentGradient : null,
              color: isToday ? null : kSurface,
              borderRadius: BorderRadius.circular(12),
              border: isToday ? null : Border.all(color: kBorder),
            ),
            child: d == null
                ? const Icon(Icons.help_outline_rounded, color: kMuted)
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${d.day}',
                        style: const TextStyle(
                          fontSize: 17,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        _months[d.month - 1],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isToday ? Colors.white : kMuted,
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  d == null
                      ? raw
                      : (isToday ? 'Today' : _weekdays[d.weekday - 1]),
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isToday ? kAccentSoft : Colors.white,
                  ),
                ),
                Text(
                  '$count ${count == 1 ? 'episode' : 'episodes'}',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
