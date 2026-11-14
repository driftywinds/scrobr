import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
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
    final now = DateTime.now();
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
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<String>(showSelectedIcon: false, 
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All time')),
                  ButtonSegment(value: 'year', label: Text('This year')),
                  ButtonSegment(value: 'month', label: Text('This month')),
                  ButtonSegment(value: 'week', label: Text('Last 7 days')),
                ],
                selected: {_range},
                onSelectionChanged: (value) {
                  setState(() => _range = value.first);
                  _reload();
                },
              ),
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
            title: 'Activity',
            child: _BarChart(
              values: activity
                  .map((e) =>
                      (e.i('movies') ?? 0) + (e.i('episodes') ?? 0) + 0.0)
                  .toList(),
              labels: activity
                  .map((e) => fmtMonthShort(e.s('month')))
                  .toList(),
              maxLabels: 8,
            ),
          ),
        if (ratings.isNotEmpty)
          _ChartSection(
            title: 'Ratings',
            child: _BarChart(
              values: ratings.map((e) => (e.i('count') ?? 0) + 0.0).toList(),
              labels: ratings
                  .map((e) => (e.d('rating') ?? 0).toStringAsFixed(0))
                  .toList(),
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
      width: 104,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
  const _BarChart({
    required this.values,
    required this.labels,
    this.color = kAccent,
    this.maxLabels = 0,
  });

  final List<double> values;
  final List<String> labels;
  final Color color;
  final int maxLabels;

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return const SizedBox.shrink();
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final step = maxLabels > 0 && values.length > maxLabels
        ? (values.length / maxLabels).ceil()
        : 1;
    return SizedBox(
      height: 120,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: List.generate(values.length, (i) {
          final ratio = maxValue <= 0 ? 0.0 : values[i] / maxValue;
          final showLabel = step <= 1 || i % step == 0 || i == values.length - 1;
          final label = showLabel ? labels[i] : '';
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: FractionallySizedBox(
                        heightFactor: ratio == 0 ? 0.01 : ratio,
                        child: Container(
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.75),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    style: const TextStyle(fontSize: 7, color: kMuted),
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
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
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
