import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/movie_shelf.dart';

Map<String, dynamic> media({
  required int id,
  required String type,
  String title = 'Movie',
}) =>
    {'tmdb_id': id, 'type': type, 'title': title};

void main() {
  test('merges watchlist and following movies without duplicates', () {
    final rows = buildMovieRows(
      continueWatching: [
        {
          'media': media(id: 1, type: 'movie', title: 'In progress'),
          'progress_percent': 40,
        },
      ],
      watchlist: [
        {'media': media(id: 1, type: 'movie', title: 'Duplicate')},
        {'media': media(id: 2, type: 'movie', title: 'Watchlist')},
        {'media': media(id: 3, type: 'series', title: 'A show')},
      ],
      following: [
        {'media': media(id: 2, type: 'movie', title: 'Duplicate')},
        {'media': media(id: 4, type: 'movie', title: 'Following')},
      ],
    );

    final ids = rows.map((row) => (row['media'] as Map)['tmdb_id']);
    expect(ids, [1, 2, 4]);
    expect(rows.first['progress_percent'], 40);
    expect(rows[1]['media']['title'], 'Watchlist');
  });
}
