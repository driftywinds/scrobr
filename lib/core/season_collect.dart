Map<String, dynamic> seasonCollectBody({
  required int seriesTmdbId,
  required int seasonNumber,
  String? episodeOrder,
}) =>
    {
      'series_tmdb_id': seriesTmdbId,
      'season_number': seasonNumber,
      if (episodeOrder != null && episodeOrder.isNotEmpty)
        'episode_order': episodeOrder,
    };

Map<String, dynamic> seasonUncollectQuery({
  required int seriesTmdbId,
  required int seasonNumber,
  String? episodeOrder,
}) =>
    {
      'series_tmdb_id': seriesTmdbId,
      'season_number': seasonNumber,
      if (episodeOrder != null && episodeOrder.isNotEmpty)
        'episode_order': episodeOrder,
    };
