import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/watch_sync.dart';

void main() {
  test('builds the watched episode payload and stable key', () {
    final media = {
      'type': 'episode',
      'tmdb_id': 42,
      'show_tmdb_id': 7,
      'season_number': 2,
      'episode_number': 3,
      'show_title': 'Example',
    };
    expect(watchKeyFor(media), 'episode:7:2:3');
    expect(watchLabelFor(media), 'Example · S02E03');
    expect(watchBodyFor(media), {
      'media_type': 'episode',
      'tmdb_id': 42,
      'series_tmdb_id': 7,
      'season_number': 2,
      'episode_number': 3,
      'completed': true,
    });
  });

  test('builds movie payloads and ignores incomplete items', () {
    expect(
      watchBodyFor({'type': 'movie', 'tmdb_id': 9}),
      {'media_type': 'movie', 'tmdb_id': 9, 'completed': true},
    );
    expect(watchBodyFor({'type': 'episode', 'tmdb_id': 9}), isNull);
    expect(watchKeyFor({'type': 'movie'}), isNull);
  });
}
