import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'format.dart';
import 'theme.dart';

void showSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
}

Future<bool> toggleWatched(
  BuildContext context,
  Map<String, dynamic> media, {
  bool? target,
  bool promptRating = true,
}) async {
  final app = ScrobScope.of(context);
  final type = media.s('type') ?? 'movie';
  final watched = target ?? !media.b('watched');
  try {
    if (watched) {
      final body = <String, dynamic>{
        'media_type': type,
        'completed': true,
      };
      if (type == 'episode') {
        body['tmdb_id'] = media.i('tmdb_id');
        body['series_tmdb_id'] = media.i('show_tmdb_id') ?? media.i('series_tmdb_id');
        body['season_number'] = media.i('season_number');
        body['episode_number'] = media.i('episode_number');
      } else {
        body['tmdb_id'] = media.i('tmdb_id');
      }
      await app.post('/history', body);
      if (type == 'movie') {
        final tmdb = media.i('tmdb_id');
        if (tmdb != null) app.noteMovieWatched(tmdb, true);
      }
      app.bumpHistory();
    } else {
      final id = media.i('id');
      final tmdb = media.i('tmdb_id');
      if (id == null && tmdb == null) return false;
      await app.delete('/history/item', {
        if (id != null) 'id': id,
        if (id == null && tmdb != null) 'tmdb_id': tmdb,
        'media_type': type,
      });
      if (type == 'movie') {
        final tmdb = media.i('tmdb_id');
        if (tmdb != null) app.noteMovieWatched(tmdb, false);
      }
      app.bumpHistory();
    }
    HapticFeedback.selectionClick();
    showSnack(context, watched ? 'Marked as watched' : 'Marked as unwatched');
    if (watched) {
      final promptKey = type == 'episode'
          ? 'rate_prompt_episodes'
          : type == 'movie'
              ? 'rate_prompt_movies'
              : null;
      if (promptRating &&
          promptKey != null &&
          (app.settings?.b(promptKey) ?? false) &&
          (media.d('user_rating') ?? 0) <= 0) {
        await openRatingDialog(context, media);
      }
    }
    return true;
  } catch (e) {
    showSnack(context, 'Could not update watch state: $e');
    return false;
  }
}

Future<bool> openRatingDialog(
  BuildContext context,
  Map<String, dynamic> media, {
  int? seasonNumber,
}) async {
  final app = ScrobScope.of(context);
  final type = seasonNumber != null ? 'series' : (media.s('type') ?? 'movie');
  final current = (media.d('user_rating') ?? 0).clamp(0, 10).toDouble();
  var value = current;
  final result = await showDialog<double?>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(
          seasonNumber != null
              ? 'Rate season $seasonNumber'
              : 'Rate ${media.s('title') ?? 'this title'}',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w900,
                color: kAmber,
              ),
            ),
            Slider(
              value: value,
              min: 0,
              max: 10,
              divisions: 20,
              label: value.toStringAsFixed(1),
              onChanged: (v) => setState(() => value = v),
            ),
            const Text(
              '0 removes the rating',
              style: TextStyle(fontSize: 11, color: kMuted),
            ),
          ],
        ),
        actions: [
          if (current > 0)
            TextButton(
              onPressed: () => Navigator.pop(context, -1.0),
              child: const Text('Remove'),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, value),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (result == null) return false;
  try {
    if (result < 0) {
      await app.delete('/ratings', {
        'media_type': type,
        'tmdb_id': media.i('tmdb_id'),
        if (seasonNumber != null) 'season_number': seasonNumber,
      });
      showSnack(context, 'Rating removed');
    } else if (result == 0) {
      await app.delete('/ratings', {
        'media_type': type,
        'tmdb_id': media.i('tmdb_id'),
        if (seasonNumber != null) 'season_number': seasonNumber,
      });
      showSnack(context, 'Rating removed');
    } else {
      await app.post('/ratings', {
        'media_type': type,
        if (seasonNumber == null) 'tmdb_id': media.i('tmdb_id'),
        if (seasonNumber != null) 'tmdb_id': media.i('tmdb_id'),
        if (seasonNumber != null) 'season_number': seasonNumber,
        if (media.i('id') != null && seasonNumber == null) 'media_id': media.i('id'),
        'rating': result,
        if (media.s('episode_order') != null) 'episode_order': media.s('episode_order'),
      });
      showSnack(context, 'Rated ${result.toStringAsFixed(1)} / 10');
    }
    return true;
  } catch (e) {
    showSnack(context, 'Could not save rating: $e');
    return false;
  }
}

Future<bool> addToListDialog(
  BuildContext context,
  Map<String, dynamic> media,
) async {
  final app = ScrobScope.of(context);
  try {
    final type = normalizedMediaType(media);
    final isEpisode = type == 'episode';
    final tmdbId = isEpisode
        ? (media.i('show_tmdb_id') ?? media.i('tmdb_id'))
        : media.i('tmdb_id');
    if (type == null || tmdbId == null) {
      showSnack(context, 'Could not add to list: unknown media type');
      return false;
    }
    var memberships = _intSet(media['in_lists']);
    if (isEpisode) {
      // Episodes are added as their series, so check the series' lists.
      final show = asMap(await app.tryGet('/shows/$tmdbId'));
      memberships = _intSet(show['in_lists']);
    }
    final data = asMap(await app.get('/lists'));
    final lists = data.maps('lists');
    final choice = await showModalBottomSheet<({int listId, bool remove})>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (context) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: Text(
                'Add to list',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            if (lists.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No lists yet. Create one from the Lists screen.',
                  style: TextStyle(color: kMuted),
                ),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: lists.length,
                  itemBuilder: (context, index) {
                    final list = lists[index];
                    final already = memberships.contains(list.i('id'));
                    final listId = list.i('id');
                    return ListTile(
                      leading: Icon(
                        list.b('is_watchlist')
                            ? Icons.bookmark_rounded
                            : Icons.list_alt_rounded,
                      ),
                      title: Text(list.s('name') ?? ''),
                      subtitle: Text(
                        already
                            ? '${list.i('item_count') ?? 0} items · Already in list · Tap to remove'
                            : '${list.i('item_count') ?? 0} items',
                        style: const TextStyle(fontSize: 11),
                      ),
                      trailing: already
                          ? const Icon(
                              Icons.check_circle_rounded,
                              color: kGreen,
                            )
                          : null,
                      onTap: listId == null
                          ? null
                          : () => Navigator.pop(
                                context,
                                (listId: listId, remove: already),
                              ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (choice == null) return false;
    final targetType = isEpisode ? 'series' : type!;
    final targetId = tmdbId!;
    if (choice.remove) {
      await _removeFromList(app, choice.listId, targetType, targetId);
      app.bumpLists();
      showSnack(context, 'Removed from list');
      return true;
    }
    await app.post('/lists/${choice.listId}/items', {
      'tmdb_id': targetId,
      'media_type': targetType,
    });
    app.bumpLists();
    showSnack(context, 'Added to list');
    return true;
  } catch (e) {
    showSnack(context, 'Could not add to list: $e');
    return false;
  }
}

Future<void> openTrailer(BuildContext context, Map<String, dynamic> media) async {
  final app = ScrobScope.of(context);
  try {
    final type = media.s('type') == 'series' ? 'series' : 'movie';
    final data = asMap(
      await app.get('/media/$type/${media.i('tmdb_id')}/trailer'),
    );
    final key = data.s('key');
    if (key == null || key.isEmpty) {
      showSnack(context, 'No trailer available');
      return;
    }
    final uri = Uri.parse('https://www.youtube.com/watch?v=$key');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      showSnack(context, 'Could not open trailer');
    }
  } catch (e) {
    showSnack(context, 'Could not load trailer: $e');
  }
}

Future<bool> toggleCollect(
  BuildContext context,
  Map<String, dynamic> media,
) async {
  final app = ScrobScope.of(context);
  final type = media.s('type') == 'series' ? 'series' : 'movie';
  final inLibrary = media.b('in_library');
  try {
    if (type == 'series') {
      if (inLibrary) {
        await app.delete('/media/collect-show', {
          'tmdb_id': media.i('tmdb_id'),
        });
      } else {
        await app.post('/media/collect-show', {
          'tmdb_id': media.i('tmdb_id'),
        });
      }
      // The calendar's candidate list is collection-driven; force a recompute
      // so a newly collected show appears without waiting for the daily cache.
      try {
        await app.post('/calendar/refresh');
      } catch (_) {
        // Collection succeeded; the calendar can still be refreshed manually.
      }
      showSnack(
        context,
        inLibrary ? 'Removed from library' : 'Added to library',
      );
    } else if (inLibrary) {
      await app.delete('/media/collect', {
        'tmdb_id': media.i('tmdb_id'),
        'media_type': type,
      });
      showSnack(context, 'Removed from library');
    } else {
      await app.post('/media/collect', {
        'tmdb_id': media.i('tmdb_id'),
        'media_type': type,
      });
      showSnack(context, 'Added to library');
    }
    return true;
  } catch (e) {
    showSnack(context, 'Could not update library: $e');
    return false;
  }
}

Future<bool> markSeasonWatched(
  BuildContext context,
  int showTmdbId,
  int seasonNumber,
) async {
  try {
    await ScrobScope.of(context).post('/history/season', {
      'series_tmdb_id': showTmdbId,
      'season_number': seasonNumber,
    });
    ScrobScope.of(context).bumpHistory();
    showSnack(context, 'Season marked watched');
    return true;
  } catch (e) {
    showSnack(context, 'Could not mark season: $e');
    return false;
  }
}

Future<bool> unmarkSeasonWatched(
  BuildContext context,
  int showTmdbId,
  int seasonNumber,
) async {
  try {
    await ScrobScope.of(context).delete('/history/season', {
      'series_tmdb_id': showTmdbId,
      'season_number': seasonNumber,
    });
    ScrobScope.of(context).bumpHistory();
    showSnack(context, 'Season marked unwatched');
    return true;
  } catch (e) {
    showSnack(context, 'Could not update season: $e');
    return false;
  }
}

Future<bool> markShowWatched(BuildContext context, int showTmdbId) async {
  try {
    await ScrobScope.of(context).post('/history/show-all', {
      'series_tmdb_id': showTmdbId,
    });
    ScrobScope.of(context).bumpHistory();
    showSnack(context, 'Show marked watched');
    return true;
  } catch (e) {
    showSnack(context, 'Could not mark show: $e');
    return false;
  }
}

Future<bool> unmarkShowWatched(BuildContext context, int showTmdbId) async {
  try {
    await ScrobScope.of(context)
        .delete('/history/show-all', {'series_tmdb_id': showTmdbId});
    ScrobScope.of(context).bumpHistory();
    showSnack(context, 'Show marked unwatched');
    return true;
  } catch (e) {
    showSnack(context, 'Could not update show: $e');
    return false;
  }
}

Future<bool> toggleRewatch(
  BuildContext context,
  int showTmdbId, {
  required bool running,
}) async {
  final app = ScrobScope.of(context);
  try {
    if (running) {
      await app.delete('/history/rewatch', {'series_tmdb_id': showTmdbId});
      showSnack(context, 'Rewatch cancelled');
    } else {
      await app.post(
        '/history/rewatch',
        null,
        {'series_tmdb_id': showTmdbId},
      );
      showSnack(context, 'Rewatch started');
    }
    return true;
  } catch (e) {
    showSnack(context, 'Could not update rewatch: $e');
    return false;
  }
}

Future<bool> toggleDrop(
  BuildContext context,
  Map<String, dynamic> media,
) async {
  final app = ScrobScope.of(context);
  final type = media.s('type') == 'series' ? 'show' : 'movie';
  final dropped = media.b('dropped');
  try {
    if (dropped) {
      await app.delete(
        '/history/drop/$type',
        type == 'show'
            ? {'show_id': media.i('id')}
            : {'media_id': media.i('id')},
      );
      showSnack(context, 'Removed from dropped');
    } else {
      if (type == 'show') {
        await app.post('/history/drop/show', {'show_id': media.i('id')});
      } else {
        await app.post('/history/drop/movie', {'media_id': media.i('id')});
      }
      showSnack(context, 'Dropped');
    }
    return true;
  } catch (e) {
    showSnack(context, 'Could not update dropped: $e');
    return false;
  }
}

Future<bool> requestMedia(
  BuildContext context,
  Map<String, dynamic> media,
) async {
  final app = ScrobScope.of(context);
  try {
    final type = media.s('type') == 'series' ? 'series' : 'movie';
    final result = asMap(
      await app.post('/media/$type/${media.i('tmdb_id')}/request'),
    );
    showSnack(context, result.s('message') ?? 'Request sent');
    return true;
  } catch (e) {
    showSnack(context, 'Could not send request: $e');
    return false;
  }
}



Future<void> _removeFromList(
  AppState app,
  int listId,
  String mediaType,
  int tmdbId,
) async {
  final detail = asMap(await app.get('/lists/$listId'));
  int? itemId;
  for (final item in asMaps(detail['items'])) {
    final media = asMap(item['media']);
    if (media.s('type') == mediaType && media.i('tmdb_id') == tmdbId) {
      itemId = item.i('id');
      break;
    }
  }
  if (itemId == null) {
    throw Exception('Item not found in list');
  }
  await app.delete('/lists/$listId/items/$itemId');
}

Set<int> _intSet(dynamic value) {
  if (value is! Iterable) return <int>{};
  return {
    for (final item in value)
      if (asInt(item) != null) asInt(item)!,
  };
}
