import 'app_state.dart';
import 'format.dart';

class _CachedDetail {
  _CachedDetail(this.at, this.data);

  final DateTime at;
  final Map<String, dynamic> data;
}

final _detailCache = <String, _CachedDetail>{};

Future<Map<String, dynamic>> _detail(AppState app, String path) async {
  final key = '${app.server}|${app.userId}|$path';
  final cached = _detailCache[key];
  if (cached != null &&
      DateTime.now().difference(cached.at) < const Duration(hours: 8)) {
    return cached.data;
  }
  final data = asMap(await app.get(path));
  _detailCache[key] = _CachedDetail(DateTime.now(), data);
  return data;
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

  for (final item in items) {
    final media = asMap(item['media']);
    final type = media.s('type');
    final tmdbId = media.i('tmdb_id');
    if (tmdbId == null) continue;

    try {
      if (type == 'series') {
        final show = await _detail(app, '/shows/$tmdbId');
        if (show.isEmpty) continue;
        final showTitle = show.s('title') ?? media.s('title') ?? '';
        final poster = show.s('poster_path') ?? media.s('poster_path');
        final seasonsMeta = show.maps('seasons_meta');

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
              'season_number':
                  episode.i('season_number') ?? fallbackSeason,
              'episode_number': episode.i('episode_number'),
              'episode_name':
                  episode.s('title') ?? episode.s('name') ?? '',
              'watched': episode.b('watched'),
              'collected': episode.b('collected'),
              'following': true,
            });
          }
        }

        final seasons = asMap(show['seasons']);
        for (final season in seasons.entries) {
          appendEpisodes(
            asMaps(season.value),
            int.tryParse(season.key.replaceFirst('season_', '')),
          );
        }

        // Show details for an uncollected show may only carry seasons_meta,
        // not the episode lists. Fetch the current/relevant season(s) so
        // followed-only entries still appear.
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
          try {
            final season = await _detail(
              app,
              '/shows/$tmdbId/season/$number',
            );
            appendEpisodes(season.maps('episodes'), number);
          } catch (_) {
            // Skip a season that fails; the rest of the calendar still loads.
          }
        }
      } else if (type == 'movie') {
        final movie = await _detail(app, '/media/movie/$tmdbId');
        if (movie.isEmpty) continue;
        final releaseDate =
            movie.s('release_date') ?? media.s('release_date');
        if (releaseDate == null) continue;
        add({
          'media_type': 'movie',
          'air_date': releaseDate,
          'tmdb_id': tmdbId,
          'title': movie.s('title') ?? media.s('title') ?? '',
          'poster_path':
              movie.s('poster_path') ?? media.s('poster_path'),
          'following': true,
        });
      }
    } catch (_) {
      // A followed title may have been removed from TMDB, or the server may
      // not have a TMDB key. Skip it without breaking the rest of the calendar.
    }
  }

  return entries;
}
