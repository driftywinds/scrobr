import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/app_time.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.userId});

  final int userId;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  Future<Map<String, dynamic>>? _future;
  String _range = 'all';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async {
    final now = AppTime.now();
    String? since;
    if (_range == 'year') {
      since = DateTime(now.year, 1, 1).toIso8601String().substring(0, 10);
    } else if (_range == 'month') {
      since = DateTime(now.year, now.month, 1)
          .toIso8601String()
          .substring(0, 10);
    } else if (_range == 'week') {
      since = now
          .subtract(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10);
    }
    return asMap(await ScrobScope.of(context).get(
      '/profile/${widget.userId}/stats',
      since == null ? null : {'since': since},
    ));
  }

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stats')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: SegmentedTabs<String>(segments: const [
                  ButtonSegment(value: 'all', label: Text('All time')),
                  ButtonSegment(value: 'year', label: Text('Year')),
                  ButtonSegment(value: 'month', label: Text('Month')),
                  ButtonSegment(value: 'week', label: Text('7 days')),
                ],
                selected: {_range},
                onSelectionChanged: (value) {
                  setState(() => _range = value.first);
                  _reload();
                },
              ),
          ),
          Expanded(
            child: FutureBuilder<Map<String, dynamic>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const LoadingView();
                }
                if (snapshot.hasError) {
                  return ErrorView(
                    message: '${snapshot.error}',
                    onRetry: _reload,
                  );
                }
                final stats = snapshot.data ?? const {};
                return _StatsBody(stats: stats);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBody extends StatelessWidget {
  const _StatsBody({required this.stats});

  final Map<String, dynamic> stats;

  Map<String, dynamic> _media(Map<String, dynamic> item, String type) => {
        ...item,
        'type': type,
        'release_date': item.s('release_date'),
        'poster_path': item.s('poster_path'),
      };

  /// Long histories collapse to one bar per year so the chart stays readable;
  /// shorter ranges show one bar per month.
  Widget _activityChart(List<Map<String, dynamic>> activity) {
    double count(Map<String, dynamic> e) =>
        (e.i('movies') ?? 0) + (e.i('episodes') ?? 0) + 0.0;
    if (activity.length > 18) {
      final byYear = <String, double>{};
      for (final e in activity) {
        final month = e.s('month') ?? '';
        if (month.length < 4) continue;
        final year = month.substring(0, 4);
        byYear[year] = (byYear[year] ?? 0) + count(e);
      }
      final years = byYear.keys.toList()..sort();
      return _BarChart(
        values: [for (final y in years) byYear[y]!],
        labels: [for (final y in years) y.length == 4 ? "'${y.substring(2)}" : y],
      );
    }
    return _BarChart(
      values: activity.map(count).toList(),
      labels: activity.map((e) => fmtMonthShort(e.s('month'))).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activity = stats.maps('watch_activity')
        .where((e) => e.s('month') != '1969-12')
        .toList();
    final ratings = stats.maps('rating_distribution');
    final weekdays = stats.maps('weekday_activity');
    final genres = stats.maps('top_movie_genres');
    final networks = stats.maps('top_networks');
    final people = asMap(stats['top_people']);
    final topMovies = stats.maps('top_movies');
    final topShows = stats.maps('top_shows');

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatCard(
                label: 'Watch time',
                value: fmtMinutes(stats.i('total_watch_minutes')),
              ),
              _StatCard(
                label: 'Movies',
                value: fmtCount(stats.i('movies_watched')),
              ),
              _StatCard(
                label: 'Shows',
                value: fmtCount(stats.i('shows_watched')),
              ),
              _StatCard(
                label: 'Episodes',
                value: fmtCount(stats.i('episodes_watched')),
              ),
              _StatCard(
                label: 'Rated',
                value:
                    '${fmtRating(stats.d('avg_movie_rating'))} / ${fmtRating(stats.d('avg_show_rating'))}',
              ),
            ],
          ),
        ),
        if (activity.isNotEmpty)
          _ChartSection(
            title: activity.length > 18 ? 'Activity by year' : 'Activity',
            child: _activityChart(activity),
          ),
        if (ratings.isNotEmpty)
          _ChartSection(
            title: 'Ratings',
            child: _BarChart(
              values: ratings.map((e) => (e.i('count') ?? 0) + 0.0).toList(),
              labels: ratings.map((e) {
                final r = e.d('rating') ?? 0;
                return r == r.roundToDouble()
                    ? r.toStringAsFixed(0)
                    : r.toStringAsFixed(1);
              }).toList(),
              color: kAmber,
            ),
          ),
        if (weekdays.isNotEmpty)
          _ChartSection(
            title: 'Weekday activity',
            child: _BarChart(
              values: weekdays.map((e) => e.d('avg') ?? 0).toList(),
              labels: weekdays.map((e) => e.s('day') ?? '').toList(),
              color: kGreen,
            ),
          ),
        if (topMovies.isNotEmpty)
          MediaRow(
            title: 'Most watched movies',
            items: topMovies.map((e) => _media(e, 'movie')).toList(),
          ),
        if (topShows.isNotEmpty)
          MediaRow(
            title: 'Most watched shows',
            items: topShows.map((e) => _media(e, 'series')).toList(),
          ),
        if (genres.isNotEmpty)
          _ChipsSection(
            title: 'Top movie genres',
            items: genres
                .map((e) => '${e.s('name')} · ${e.i('count')}')
                .toList(),
          ),
        if (networks.isNotEmpty)
          _ChipsSection(
            title: 'Top networks',
            items: networks
                .map((e) => '${e.s('name')} · ${e.i('count') ?? ''}')
                .toList(),
          ),
        if ((people['actors'] as List?)?.isNotEmpty ?? false)
          _ChipsSection(
            title: 'Top actors',
            items: asMaps(people['actors'])
                .map((e) =>
                    '${e.s('name')} · ${e.i('count') ?? e.i('plays') ?? 0}')
                .toList(),
          ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: (MediaQuery.sizeOf(context).width - 48) / 3,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          Text(
            label,
            style: const TextStyle(fontSize: 9, color: kMuted),
          ),
        ],
      ),
    );
  }
}

class _ChartSection extends StatelessWidget {
  const _ChartSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 6),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _BarChart extends StatelessWidget {
  _BarChart({
    required this.values,
    required this.labels,
    this.color,
  });

  final List<double> values;
  final List<String> labels;
  final Color? color;

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final barColor = color ?? kAccent;
    final showValues = values.length <= 14;
    final step = values.length > 14 ? (values.length / 12).ceil() : 1;
    final gap = values.length > 14 ? 1.0 : 3.0;
    return SizedBox(
      height: 150,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = maxValue <= 0 ? 0.0 : values[i] / maxValue;
          final isPeak = values[i] == maxValue && maxValue > 0;
          final label = step <= 1 || i % step == 0 || i == values.length - 1
              ? labels[i]
              : '';
          return Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: gap),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (showValues)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          values[i] > 0 ? _fmt(values[i]) : '',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isPeak ? Colors.white : kMuted,
                          ),
                        ),
                      ),
                    ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio == 0 ? 0.01 : ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                barColor,
                                barColor.withValues(alpha: 0.45),
                              ],
                            ),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  SizedBox(
                    height: 14,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 10, color: kMuted),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

class _ChipsSection extends StatelessWidget {
  const _ChipsSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: items.map((e) => TagChip(label: e)).toList(),
          ),
        ],
      ),
    );
  }
}
