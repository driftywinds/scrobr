import 'format.dart';

/// Merges the movie sources shown in Home's Movies tab.
///
/// Continue-watching rows come first so their playback progress wins over the
/// same title also being on the watchlist or Following list.
List<Map<String, dynamic>> buildMovieRows({
  required Iterable<Map<String, dynamic>> continueWatching,
  required Iterable<Map<String, dynamic>> watchlist,
  required Iterable<Map<String, dynamic>> following,
}) {
  final rows = <Map<String, dynamic>>[];
  final seen = <int>{};

  void add(Map<String, dynamic> entry) {
    final source = asMap(entry['media']);
    if (source.isEmpty) return;
    final media = Map<String, dynamic>.from(source);
    media['type'] ??= entry.s('media_type') ?? 'movie';
    media['tmdb_id'] ??= entry.i('tmdb_id');
    if (media.s('type') != 'movie') return;
    final id = media.i('tmdb_id');
    if (id == null || !seen.add(id)) return;

    final row = <String, dynamic>{'media': media};
    final progress =
        entry.d('progress_percent') ?? media.d('progress_percent');
    if (progress != null) row['progress_percent'] = progress;
    rows.add(row);
  }

  for (final entry in continueWatching) {
    add(entry);
  }
  for (final entry in watchlist) {
    add(entry);
  }
  for (final entry in following) {
    add(entry);
  }
  return rows;
}
