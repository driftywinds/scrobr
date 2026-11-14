import 'package:material_ui/material_ui.dart';

import '../screens/browse_screen.dart';
import '../screens/calendar_screen.dart';
import '../screens/episode_screen.dart';
import '../screens/explore_screen.dart';
import '../screens/history_screen.dart';
import '../screens/list_detail_screen.dart';
import '../screens/lists_screen.dart';
import '../screens/login_screen.dart';
import '../screens/movie_screen.dart';
import '../screens/person_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/search_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/show_screen.dart';
import '../screens/stats_screen.dart';
import '../screens/studio_screen.dart';
import 'format.dart';

Future<T?> pushScreen<T>(BuildContext context, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(builder: (_) => screen),
  );
}

void openMedia(BuildContext context, Map<String, dynamic> item) {
  final type = item.s('type') ?? item.s('media_type');
  final tmdb = item.i('tmdb_id');
  switch (type) {
    case 'movie':
      if (tmdb != null) pushScreen(context, MovieScreen(tmdbId: tmdb));
    case 'series':
    case 'show':
      if (tmdb != null) pushScreen(context, ShowScreen(tmdbId: tmdb));
    case 'episode':
      final show = item.i('show_tmdb_id');
      final season = item.i('season_number');
      final episode = item.i('episode_number');
      if (show != null && season != null && episode != null) {
        pushScreen(
          context,
          EpisodeScreen(
            showTmdbId: show,
            seasonNumber: season,
            episodeNumber: episode,
          ),
        );
      }
    case 'person':
      if (tmdb != null) pushScreen(context, PersonScreen(personId: tmdb));
    case 'collection':
      if (tmdb != null) {
        pushScreen(context, BrowseScreen.collection(tmdb));
      }
    default:
      if (tmdb != null) {
        pushScreen(context, MovieScreen(tmdbId: tmdb));
      }
  }
}

void openShow(BuildContext context, int tmdbId) =>
    pushScreen(context, ShowScreen(tmdbId: tmdbId));

void openMovie(BuildContext context, int tmdbId) =>
    pushScreen(context, MovieScreen(tmdbId: tmdbId));

void openPerson(BuildContext context, int personId) =>
    pushScreen(context, PersonScreen(personId: personId));

void openList(BuildContext context, int id) =>
    pushScreen(context, ListDetailScreen(listId: id));

void openLists(BuildContext context) => pushScreen(context, const ListsScreen());

void openProfile(BuildContext context, int userId) =>
    pushScreen(context, ProfileScreen(userId: userId));

void openStats(BuildContext context, int userId) =>
    pushScreen(context, StatsScreen(userId: userId));

void openHistory(BuildContext context) =>
    pushScreen(context, const HistoryScreen());

void openCalendar(BuildContext context) =>
    pushScreen(context, const CalendarScreen());

void openStudio(
  BuildContext context,
  int id, {
  required bool isNetwork,
}) =>
    pushScreen(
      context,
      StudioScreen(id: id, isNetwork: isNetwork),
    );

void openSearch(BuildContext context) =>
    pushScreen(context, const SearchScreen());

void openExplore(BuildContext context, {String type = 'movie'}) =>
    pushScreen(context, ExploreScreen(initialType: type));

void openSettings(BuildContext context) =>
    pushScreen(context, const SettingsScreen());

void openLogin(BuildContext context) {
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const LoginScreen()),
    (_) => false,
  );
}

