import 'dart:convert';

import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/app_state.dart';
import '../core/following_calendar.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'episode_screen.dart';
import 'movie_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  Future<Map<String, dynamic>>? _future;
  Map<String, dynamic>? _data;
  bool _cacheRead = false;
  bool _refreshing = false;
  int _seenFollowingRevision = -1;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    if (!_cacheRead) {
      _cacheRead = true;
      _readCache(app);
    }
    if (_future == null) {
      _seenFollowingRevision = app.followingRevision;
      _future = _load();
    } else if (_seenFollowingRevision != app.followingRevision) {
      _seenFollowingRevision = app.followingRevision;
      _future = _load();
    }
  }

  String _cacheKey(AppState app) =>
      'scrobr_calendar_${app.userId ?? 0}_${app.server.hashCode}_${app.calendarDays}';

  Future<void> _readCache(AppState app) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey(app));
      if (raw == null || raw.isEmpty || !mounted || _data != null) return;
      setState(() => _data = asMap(jsonDecode(raw)));
    } catch (_) {
      // A corrupt cache should not block the network refresh.
    }
  }

  Future<void> _saveCache(AppState app, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey(app), jsonEncode(data));
    } catch (_) {
      // Cache writes are best-effort.
    }
  }

  Future<Map<String, dynamic>> _load() async {
    final app = ScrobScope.of(context);
    // Server calendar and followed-show details are independent; fetch them
    // together instead of waiting for one before starting the other.
    final followedFuture = followedCalendarEntries(
      app,
      days: app.calendarDays,
    ).catchError((_) => <Map<String, dynamic>>[]);
    final data = asMap(
      await app.get('/calendar', {'days': app.calendarDays}),
    );
    final calendar = asMap(data['calendar']);
    final merged = calendar.maps('entries');
    final seen = <String>{
      for (final entry in merged)
        if (entry.s('media_type') != 'movie')
          '${entry.i('show_tmdb_id') ?? entry.s('show_title')}:'
              '${entry.i('season_number')}:${entry.i('episode_number')}',
    };

    final followed = await followedFuture;
    for (final entry in followed) {
      final key = entry.s('media_type') == 'movie'
          ? 'movie:${entry.i('tmdb_id')}'
          : '${entry.i('show_tmdb_id') ?? entry.s('show_title')}:'
              '${entry.i('season_number')}:${entry.i('episode_number')}';
      if (seen.add(key)) merged.add(entry);
    }

    data['calendar'] = {...calendar, 'entries': merged};
    _data = data;
    _saveCache(app, data);
    return data;
  }

  Widget _daysControl(AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 7, label: Text('7d')),
            ButtonSegment(value: 14, label: Text('14d')),
            ButtonSegment(value: 21, label: Text('21d')),
            ButtonSegment(value: 30, label: Text('30d')),
            ButtonSegment(value: 60, label: Text('60d')),
            ButtonSegment(value: 90, label: Text('90d')),
          ],
          selected: {app.calendarDays},
          onSelectionChanged: (value) async {
            await app.setCalendarDays(value.first);
            if (mounted) _reload();
          },
        ),
      ),
    );
  }

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
          final app = ScrobScope.of(context);
          final data = snapshot.data ?? _data;
          if (data == null &&
              snapshot.connectionState == ConnectionState.waiting) {
            return const DashboardSkeleton();
          }
          if (data == null && snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          if (data == null) {
            return const EmptyState(title: 'Nothing airing');
          }
          final calendar = asMap(data['calendar']);
          final entries = calendar.maps('entries');
          if (entries.isEmpty) {
            return Column(
              children: [
                _daysControl(app),
                const Expanded(
                  child: EmptyState(
                    title: 'Nothing airing',
                    body:
                        'Collect or follow a show, or mark an episode watched, and its upcoming episodes will appear here.',
                    icon: Icons.calendar_month_outlined,
                  ),
                ),
              ],
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
                _daysControl(app),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    'Next ${app.calendarDays} days · ${entries.length} items',
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
                      ..._groupByShow(items).map((group) {
                        final first = group.first;
                        return first.s('media_type') == 'movie'
                            ? _CalendarMovieGroup(entry: first)
                            : _CalendarShowGroup(episodes: group);
                      }),
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
      final key = item.s('media_type') == 'movie'
          ? 'movie:${item.i('tmdb_id')}'
          : item.i('show_tmdb_id') ?? item.s('show_title');
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
                          if (entry.b('following'))
                            const TagChip(label: 'Following')
                          else if (entry.b('watched'))
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

class _CalendarMovieGroup extends StatelessWidget {
  const _CalendarMovieGroup({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final tmdbId = entry.i('tmdb_id');
    final poster = app.imageUrl(entry.s('poster_path'), size: 'w185');
    return InkWell(
      borderRadius: BorderRadius.circular(kRadius),
      onTap: tmdbId == null
          ? null
          : () => pushScreen(context, MovieScreen(tmdbId: tmdbId)),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: panelDecoration(),
        child: Row(
          children: [
            SizedBox(
              width: 46,
              height: 69,
              child: Poster(
                url: poster,
                title: entry.s('title'),
                radius: 7,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.s('title') ?? '',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  const Text(
                    'Movie release',
                    style: TextStyle(fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
            const TagChip(label: 'Following'),
          ],
        ),
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
                        style: TextStyle(
                          fontSize: 17,
                          height: 1.05,
                          fontWeight: FontWeight.w900,
                          color: isToday ? kAccentOn : kText,
                        ),
                      ),
                      Text(
                        _months[d.month - 1],
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                          color: isToday ? kAccentOn : kMuted,
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
