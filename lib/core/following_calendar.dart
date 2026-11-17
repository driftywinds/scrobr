import 'app_state.dart';
import 'concurrency.dart';
import 'format.dart';

class _CachedDetail {
  _CachedDetail(this.at, this.data);

  final DateTime at;
  final Map<String, dynamic> data;
}

final _detailCache = <String, _CachedDetail>{};
final _detailInflight = <String, Future<Map<String, dynamic>>>{};

Future<Map<String, dynamic>> _detail(AppState app, String path) {
  final key = '${app.server}|${app.userId}|$path';
  final cached = _detailCache[key];
  if (cached != null &&
      DateTime.now().difference(cached.at) < const Duration(hours: 8)) {
    return Future.value(cached.data);
  }
  final inflight = _detailInflight[key];
  if (inflight != null) return inflight;

  final future = () async {
    try {
      final data = asMap(await app.get(path));
      _detailCache[key] = _CachedDetail(DateTime.now(), data);
      return data;
    } finally {
      _detailInflight.remove(key);
    }
  }();
  _detailInflight[key] = future;
  return future;
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Calendar rows for shows/movies the user follows but has not collected.
/// The server's /calendar only includes collected or watched shows, so these
/// are fetched and merged client-side.
Future<List<Map<String, dynamic>>> followedCalendarEntries(
  AppState app, {
  required int days,
}) async {
  final items = await app.followingItems();
  if (items.isEmpty) return const [];

  final today = _dateOnly(DateTime.now());
  final start = today.subtract(const Duration(days: 7));
  final end = today.add(Duration(days: days));

  // The old path fetched every followed show one-by-one. With a large
  // calendar that was the dominant cost, so resolve a handful at a time.
  final groups = await mapConcurrent(
    items,
    6,
    (item) => _entriesForItem(app, item, start: start, end: end),
  );

  final entries = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (final group in groups) {
    for (final entry in group) {
      final key = entry.s('media_type') == 'movie'
          ? 'movie:${entry.i('tmdb_id')}'
          : '${entry.i('show_tmdb_id') ?? entry.s('show_title')}:'
              '${entry.i('season_number')}:${entry.i('episode_number')}';
      if (seen.add(key)) entries.add(entry);
    }
  }
  return entries;
}

Future<List<Map<String, dynamic>>> _entriesForItem(
  AppState app,
  Map<String, dynamic> item, {
  required DateTime start,
  required DateTime end,
}) async {
  final entries = <Map<String, dynamic>>[];
  final seen = <String>{};

  void add(Map<String, dynamic> entry) {
    final date = DateTime.tryParse(entry.s('air_date') ?? '');
    if (date == null) return;
    final day = _dateOnly(date);
    if (day.isBefore(start) || day.isAfter(end)) return;
    if (entry.s('media_type') == 'movie') {
      final key = 'movie:${entry.i('tmdb_id')}';
      if (!seen.add(key)) return;
    } else {
      final key =
          '${entry.i('show_tmdb_id')}:${entry.i('season_number')}:${entry.i('episode_number')}';
      if (!seen.add(key)) return;
    }
    entries.add(entry);
  }

  final media = asMap(item['media']);
  final type = media.s('type');
  final tmdbId = media.i('tmdb_id');
  if (tmdbId == null) return entries;

  try {
    if (type == 'series') {
      final show = await _detail(app, '/shows/$tmdbId');
      if (show.isEmpty) return entries;
      final showTitle = show.s('title') ?? media.s('title') ?? '';
      final poster = show.s('poster_path') ?? media.s('poster_path');
      final seasonsMeta = show.maps('seasons_meta');
      final seasons = asMap(show['seasons']);

      void appendEpisodes(
        Iterable<Map<String, dynamic>> episodes,
        int? fallbackSeason,
      ) {
        for (final episode in episodes) {
          final airDate = episode.s('air_date');
          if (airDate == null) continue;
          add({
            'media_type': 'episode',
            'air_date': airDate,
            'show_tmdb_id': tmdbId,
            'show_title': showTitle,
            'poster_path': poster,
            'season_number': episode.i('season_number') ?? fallbackSeason,
            'episode_number': episode.i('episode_number'),
            'episode_name': episode.s('title') ?? episode.s('name') ?? '',
            'watched': episode.b('watched'),
            'collected': episode.b('collected'),
            'following': true,
          });
        }
      }

      for (final season in seasons.entries) {
        appendEpisodes(
          asMaps(season.value),
          int.tryParse(season.key.replaceFirst('season_', '')),
        );
      }

      // Show details for an uncollected show may only carry seasons_meta, not
      // the episode lists. Only fetch seasons that did not arrive above.
      final seasonNumbers = <int>{};
      int? latestStarted;
      DateTime? latestDate;
      for (final meta in seasonsMeta) {
        final number = meta.i('season_number');
        final date = DateTime.tryParse(meta.s('air_date') ?? '');
        if (number == null) continue;
        if (date != null) {
          if (!date.isAfter(end) &&
              (latestDate == null || date.isAfter(latestDate))) {
            latestStarted = number;
            latestDate = date;
          }
          if (!date.isBefore(start) && !date.isAfter(end)) {
            seasonNumbers.add(number);
          }
        }
      }
      if (latestStarted != null) seasonNumbers.add(latestStarted);

      for (final number in seasonNumbers) {
        if (asMaps(seasons['season_$number']).isNotEmpty) continue;
        try {
          final season = await _detail(app, '/shows/$tmdbId/season/$number');
          appendEpisodes(season.maps('episodes'), number);
        } catch (_) {
          // Skip a season that fails; the rest of the calendar still loads.
        }
      }
    } else if (type == 'movie') {
      final movie = await _detail(app, '/media/movie/$tmdbId');
      if (movie.isEmpty) return entries;
      final releaseDate = movie.s('release_date') ?? media.s('release_date');
      if (releaseDate == null) return entries;
      add({
        'media_type': 'movie',
        'air_date': releaseDate,
        'tmdb_id': tmdbId,
        'title': movie.s('title') ?? media.s('title') ?? '',
        'poster_path': movie.s('poster_path') ?? media.s('poster_path'),
        'following': true,
      });
    }
  } catch (_) {
    // A followed title may have been removed from TMDB, or the server may
    // not have a TMDB key. Skip it without breaking the rest of the calendar.
  }
  return entries;
}
