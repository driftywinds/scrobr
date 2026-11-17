import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/home_sort.dart';

Map<String, dynamic> show(
  int id, {
  String title = 'Show',
  String? lastWatched,
  int? tmdbRating,
  int? myRating,
}) =>
    {
      'show_tmdb_id': id,
      'show_title': title,
      'last_watched_at': lastWatched,
      if (tmdbRating != null) 'tmdb_rating': tmdbRating,
      if (myRating != null) 'user_rating': myRating,
    };

Map<String, dynamic> movie(int id, {String title = 'Movie', String? addedAt}) =>
    {
      'added_at': addedAt,
      'media': {'tmdb_id': id, 'type': 'movie', 'title': title},
    };

void main() {
  test('shows sort by last watched and keep unrated ratings last', () {
    final items = [
      show(1, title: 'Older', lastWatched: '2026-01-01'),
      show(2, title: 'Newer', lastWatched: '2026-05-01'),
    ];
    expect(
      sortShows(items, sort: HomeSort.lastWatched)
          .map((item) => item['show_tmdb_id']),
      [2, 1],
    );

    final ratings = {
      1: {'tmdb_rating': 9.0},
      2: {'tmdb_rating': null},
    };
    expect(
      sortShows(items, sort: HomeSort.tmdbRating, ratings: ratings)
          .map((item) => item['show_tmdb_id']),
      [1, 2],
    );
  });

  test('recently added uses list dates for shows and movies', () {
    final shows = [
      show(1, title: 'A'),
      show(2, title: 'B'),
    ];
    expect(
      sortShows(
        shows,
        sort: HomeSort.recentlyAdded,
        addedAt: {1: '2026-01-01', 2: '2026-06-01'},
      ).map((item) => item['show_tmdb_id']),
      [2, 1],
    );

    final movies = [
      movie(1, title: 'A', addedAt: '2026-01-01'),
      movie(2, title: 'B', addedAt: '2026-06-01'),
    ];
    expect(
      sortMovies(movies, sort: HomeSort.recentlyAdded)
          .map((row) => (row['media'] as Map)['tmdb_id']),
      [2, 1],
    );
  });
}
