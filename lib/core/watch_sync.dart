import 'format.dart';

class QueuedWatch {
  const QueuedWatch({
    required this.key,
    required this.label,
    required this.body,
  });

  final String key;
  final String label;
  final Map<String, dynamic> body;
}

/// Turns a Home episode/movie into the payload the history endpoint expects.
Map<String, dynamic>? watchBodyFor(Map<String, dynamic> media) {
  final type = normalizedMediaType(media);
  if (type == null) return null;
  if (type == 'episode') {
    final show = media.i('show_tmdb_id') ?? media.i('series_tmdb_id');
    final tmdb = media.i('tmdb_id');
    if (show == null || tmdb == null) return null;
    return {
      'media_type': 'episode',
      'tmdb_id': tmdb,
      'series_tmdb_id': show,
      'season_number': media.i('season_number'),
      'episode_number': media.i('episode_number'),
      'completed': true,
    };
  }
  final tmdb = media.i('tmdb_id');
  if (tmdb == null) return null;
  return {
    'media_type': type,
    'tmdb_id': tmdb,
    'completed': true,
  };
}

String? watchKeyFor(Map<String, dynamic> media) {
  final type = normalizedMediaType(media);
  if (type == null) return null;
  if (type == 'episode') {
    final show = media.i('show_tmdb_id') ?? media.i('series_tmdb_id');
    final season = media.i('season_number');
    final episode = media.i('episode_number');
    if (show == null || season == null || episode == null) return null;
    return 'episode:$show:$season:$episode';
  }
  final tmdb = media.i('tmdb_id');
  return tmdb == null ? null : '$type:$tmdb';
}

String watchLabelFor(Map<String, dynamic> media) {
  final type = normalizedMediaType(media);
  if (type == 'episode') {
    final title = media.s('show_title') ?? media.s('title') ?? 'Episode';
    final season = media.i('season_number');
    final episode = media.i('episode_number');
    if (season == null || episode == null) return title;
    return '$title · S${season.toString().padLeft(2, '0')}'
        'E${episode.toString().padLeft(2, '0')}';
  }
  return media.s('title') ?? 'Untitled';
}
