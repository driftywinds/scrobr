import 'dart:math';

import 'format.dart';

enum HomeSort {
  lastWatched('last_watched', 'Last watched'),
  recentlyAdded('recently_added', 'Recently added'),
  title('title', 'Title'),
  tmdbRating('tmdb_rating', 'TMDB rating'),
  myRating('my_rating', 'My rating'),
  random('random', 'Random');

  const HomeSort(this.id, this.label);

  final String id;
  final String label;
}

HomeSort homeSortFromId(String? id, HomeSort fallback) {
  for (final sort in HomeSort.values) {
    if (sort.id == id) return sort;
  }
  return fallback;
}

const showSortOptions = [
  HomeSort.lastWatched,
  HomeSort.recentlyAdded,
  HomeSort.title,
  HomeSort.tmdbRating,
  HomeSort.myRating,
  HomeSort.random,
];

const movieSortOptions = [
  HomeSort.recentlyAdded,
  HomeSort.title,
  HomeSort.tmdbRating,
  HomeSort.myRating,
  HomeSort.random,
];

int _showTmdb(Map<String, dynamic> item) =>
    item.i('show_tmdb_id') ?? item.i('tmdb_id') ?? 0;

String _showTitle(Map<String, dynamic> item) =>
    item.s('show_title') ?? item.s('title') ?? '';

String? _lastWatched(Map<String, dynamic> item, Map<int, Map<String, dynamic>> progress) {
  return item.s('last_watched_at') ??
      progress[_showTmdb(item)]?.s('last_watched_at');
}

int _compareDesc(num? a, num? b) {
  if (a == null && b == null) return 0;
  if (a == null) return 1;
  if (b == null) return -1;
  return b.compareTo(a);
}

int _compareText(String? a, String? b) =>
    (a ?? '').toLowerCase().compareTo((b ?? '').toLowerCase());

/// Local-only sort for the Home Shows tab.
List<Map<String, dynamic>> sortShows(
  List<Map<String, dynamic>> items, {
  required HomeSort sort,
  Map<int, Map<String, dynamic>> progress = const {},
  Map<int, Map<String, dynamic>> ratings = const {},
  Map<int, String> addedAt = const {},
  int randomSeed = 0,
}) {
  final rows = List<Map<String, dynamic>>.from(items);
  if (sort == HomeSort.random) {
    rows.shuffle(Random(randomSeed));
    return rows;
  }
  rows.sort((a, b) {
    int cmp;
    switch (sort) {
      case HomeSort.lastWatched:
        cmp = _compareText(_lastWatched(b, progress), _lastWatched(a, progress));
        break;
      case HomeSort.recentlyAdded:
        final aDate = addedAt[_showTmdb(a)] ?? _lastWatched(a, progress);
        final bDate = addedAt[_showTmdb(b)] ?? _lastWatched(b, progress);
        cmp = _compareText(bDate, aDate);
        break;
      case HomeSort.tmdbRating:
        cmp = _compareDesc(
          ratings[_showTmdb(a)]?.d('tmdb_rating'),
          ratings[_showTmdb(b)]?.d('tmdb_rating'),
        );
        break;
      case HomeSort.myRating:
        cmp = _compareDesc(
          ratings[_showTmdb(a)]?.d('user_rating'),
          ratings[_showTmdb(b)]?.d('user_rating'),
        );
        break;
      case HomeSort.title:
        cmp = _compareText(_showTitle(a), _showTitle(b));
        break;
      case HomeSort.random:
        cmp = 0;
        break;
    }
    return cmp != 0 ? cmp : _compareText(_showTitle(a), _showTitle(b));
  });
  return rows;
}

/// Local-only sort for the Home Movies poster grid.
List<Map<String, dynamic>> sortMovies(
  List<Map<String, dynamic>> rows, {
  required HomeSort sort,
  int randomSeed = 0,
}) {
  final result = List<Map<String, dynamic>>.from(rows);
  if (sort == HomeSort.random) {
    result.shuffle(Random(randomSeed));
    return result;
  }
  Map<String, dynamic> media(Map<String, dynamic> row) => asMap(row['media']);
  result.sort((a, b) {
    final am = media(a);
    final bm = media(b);
    int cmp;
    switch (sort) {
      case HomeSort.recentlyAdded:
        cmp = _compareText(b.s('added_at'), a.s('added_at'));
        break;
      case HomeSort.title:
        cmp = _compareText(am.s('title'), bm.s('title'));
        break;
      case HomeSort.tmdbRating:
        cmp = _compareDesc(am.d('tmdb_rating'), bm.d('tmdb_rating'));
        break;
      case HomeSort.myRating:
        cmp = _compareDesc(am.d('user_rating'), bm.d('user_rating'));
        break;
      case HomeSort.lastWatched:
      case HomeSort.random:
        cmp = 0;
        break;
    }
    return cmp != 0 ? cmp : _compareText(am.s('title'), bm.s('title'));
  });
  return result;
}
