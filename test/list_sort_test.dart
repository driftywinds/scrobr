import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/list_sort.dart';

Map<String, dynamic> item(
  String title, {
  String? addedAt,
  double? tmdbRating,
  double? myRating,
  String? releaseDate,
}) =>
    {
      'added_at': addedAt,
      'media': {
        'title': title,
        'tmdb_rating': tmdbRating,
        'user_rating': myRating,
        'release_date': releaseDate,
      },
    };

void main() {
  test('restores known sort ids and falls back to list order', () {
    expect(listSortFromId('recent'), ListSort.recent);
    expect(listSortFromId('year'), ListSort.year);
    expect(listSortFromId('unknown'), ListSort.added);
    expect(listSortFromId(null), ListSort.added);
  });

  test('sorts list items by recent addition and title', () {
    final items = [
      item('Older', addedAt: '2026-01-01'),
      item('Newer', addedAt: '2026-06-01'),
    ];
    expect(
      sortListItems(items, sort: ListSort.recent)
          .map((row) => (row['media'] as Map)['title']),
      ['Newer', 'Older'],
    );
    expect(
      sortListItems(items, sort: ListSort.title)
          .map((row) => (row['media'] as Map)['title']),
      ['Newer', 'Older'],
    );
  });

  test('keeps unrated items last and sorts by year', () {
    final items = [
      item('Unrated', tmdbRating: null, releaseDate: '2020-01-01'),
      item('Rated', tmdbRating: 8.0, releaseDate: '2024-01-01'),
      item('Also rated', tmdbRating: 7.0, releaseDate: '2022-01-01'),
    ];
    expect(
      sortListItems(items, sort: ListSort.tmdbRating)
          .map((row) => (row['media'] as Map)['title']),
      ['Rated', 'Also rated', 'Unrated'],
    );
    expect(
      sortListItems(items, sort: ListSort.year)
          .map((row) => (row['media'] as Map)['title']),
      ['Rated', 'Also rated', 'Unrated'],
    );
  });
}
