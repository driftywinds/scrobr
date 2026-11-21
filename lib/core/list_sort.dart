import 'dart:math';

import 'format.dart';

enum ListSort {
  added('list', 'List order'),
  recent('recent', 'Recently added'),
  title('title', 'Title'),
  tmdbRating('tmdb', 'TMDB rating'),
  myRating('my', 'My rating'),
  year('year', 'Release year'),
  random('random', 'Random');

  const ListSort(this.id, this.label);

  final String id;
  final String label;
}

const listSortOptions = [
  ListSort.added,
  ListSort.recent,
  ListSort.title,
  ListSort.tmdbRating,
  ListSort.myRating,
  ListSort.year,
  ListSort.random,
];

List<Map<String, dynamic>> sortListItems(
  List<Map<String, dynamic>> items, {
  required ListSort sort,
  int randomSeed = 0,
}) {
  final rows = List<Map<String, dynamic>>.from(items);
  if (sort == ListSort.added) return rows;
  if (sort == ListSort.random) {
    rows.shuffle(Random(randomSeed));
    return rows;
  }
  Map<String, dynamic> media(Map<String, dynamic> row) => asMap(row['media']);
  rows.sort((a, b) {
    final am = media(a);
    final bm = media(b);
    int cmp;
    switch (sort) {
      case ListSort.recent:
        cmp = _compareText(b.s('added_at'), a.s('added_at'));
        break;
      case ListSort.title:
        cmp = _compareText(am.s('title'), bm.s('title'));
        break;
      case ListSort.tmdbRating:
        cmp = _compareDesc(am.d('tmdb_rating'), bm.d('tmdb_rating'));
        break;
      case ListSort.myRating:
        cmp = _compareDesc(am.d('user_rating'), bm.d('user_rating'));
        break;
      case ListSort.year:
        cmp = _compareDesc(_year(am), _year(bm));
        break;
      case ListSort.added:
      case ListSort.random:
        cmp = 0;
        break;
    }
    return cmp != 0 ? cmp : _compareText(am.s('title'), bm.s('title'));
  });
  return rows;
}

int _year(Map<String, dynamic> media) {
  final date = media.s('release_date') ?? media.s('first_air_date');
  return int.tryParse(date?.split('-').first ?? '') ?? 0;
}

int _compareDesc(num? a, num? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

int _compareText(String? a, String? b) =>
    (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());
