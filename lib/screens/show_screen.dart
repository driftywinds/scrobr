import 'package:material_ui/material_ui.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/comments.dart';
import '../widgets/trakt_comments.dart';
import '../widgets/common.dart';
import 'season_screen.dart';

class ShowScreen extends StatefulWidget {
  const ShowScreen({super.key, required this.tmdbId});

  final int tmdbId;

  @override
  State<ShowScreen> createState() => _ShowScreenState();
}

class _ShowScreenState extends State<ShowScreen> {
  Future<_ShowData>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<_ShowData> _load() async {
    final app = ScrobScope.of(context);
    final results = await Future.wait([
      app.get('/shows/${widget.tmdbId}'),
      app.tryGet('/shows/${widget.tmdbId}/recommendations'),
      app.tryGet('/shows/${widget.tmdbId}/episode-orders'),
    ]);
    return _ShowData(
      detail: asMap(results[0]),
      recommendations: asMaps(asMap(results[1])['results']),
      orders: asMaps(asMap(results[2])['orders']),
      selectedOrder: asMap(results[2]).s('selected'),
    );
  }

  void _reload() {
    setState(() => _future = _load());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<_ShowData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorView(
                message: '${snapshot.error}',
                onRetry: _reload,
              ),
            );
          }
          return _ShowBody(data: snapshot.data!, reload: _reload);
        },
      ),
    );
  }
}

class _ShowData {
  const _ShowData({
    required this.detail,
    required this.recommendations,
    required this.orders,
    required this.selectedOrder,
  });

  final Map<String, dynamic> detail;
  final List<Map<String, dynamic>> recommendations;
  final List<Map<String, dynamic>> orders;
  final String? selectedOrder;
}

class _ShowBody extends StatelessWidget {
  const _ShowBody({required this.data, required this.reload});

  final _ShowData data;
  final VoidCallback reload;

  Future<void> _act(BuildContext context, Future<bool> Function() action) async {
    final changed = await action();
    if (changed) reload();
  }

  Future<void> _bulkSeasons(
    BuildContext context,
    List<Map<String, dynamic>> seasons,
    int showId,
    int initial,
  ) async {
    final numbers = seasons
        .map((season) => season.i('season_number'))
        .whereType<int>()
        .toList();
    if (numbers.isEmpty) return;
    final selected = <int>{initial};

    final result = await showModalBottomSheet<Map<String, Object>>(
      context: context,
      isScrollControlled: true,
      builder: (context) => StatefulBuilder(
        builder: (context, setSheet) {
          final allSelected = selected.length == numbers.length;
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.82,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 0),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Select seasons',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setSheet(() {
                            if (allSelected) {
                              selected.clear();
                            } else {
                              selected.addAll(numbers);
                            }
                          }),
                          child: Text(allSelected ? 'Clear all' : 'Select all'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: [
                        for (final season in seasons.where(
                          (season) => season.i('season_number') != null,
                        ))
                          CheckboxListTile(
                            value:
                                selected.contains(season.i('season_number')),
                            title: Text(
                              season.s('name') ??
                                  'Season ${season.i('season_number')}',
                            ),
                            subtitle: Text(
                              '${season.i('episode_count') ?? 0} episodes',
                              style: const TextStyle(fontSize: 11),
                            ),
                            onChanged: (on) => setSheet(() {
                              final number = season.i('season_number');
                              if (number == null) return;
                              if (on == true) {
                                selected.add(number);
                              } else {
                                selected.remove(number);
                              }
                            }),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(context, {
                                      'watched': true,
                                      'seasons': selected.toList(),
                                    }),
                            child: const Text('Mark watched'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: FilledButton.tonal(
                            onPressed: selected.isEmpty
                                ? null
                                : () => Navigator.pop(context, {
                                      'watched': false,
                                      'seasons': selected.toList(),
                                    }),
                            child: const Text('Unwatch'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (result == null || !context.mounted) return;

    final app = ScrobScope.of(context);
    final ids = (result['seasons'] as List).cast<int>();
    final watched = result['watched'] == true;
    try {
      for (final seasonNumber in ids) {
        if (watched) {
          await app.post('/history/season', {
            'series_tmdb_id': showId,
            'season_number': seasonNumber,
          });
        } else {
          await app.delete('/history/season', {
            'series_tmdb_id': showId,
            'season_number': seasonNumber,
          });
        }
      }
      app.bumpHistory();
      reload();
      showSnack(
        context,
        '${watched ? 'Marked' : 'Unmarked'} ${ids.length} season(s)',
      );
    } catch (e) {
      showSnack(context, 'Could not update seasons: $e');
    }
  }


  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final show = data.detail;
    final title = show.s('title') ?? 'Show';
    final backdrop = app.imageUrl(show.s('backdrop_path'), size: 'w780');
    final poster = app.imageUrl(show.s('poster_path'), size: 'w342');
    final seasons = show.maps('seasons_meta');
    final states = asMap(show['season_states']);
    final rewatch = asMap(show['rewatch']);
    final inRewatch = rewatch.isNotEmpty;
    final watchPct = show.d('watch_pct') ?? 0;
    final networks = show.maps('networks');
    final showId = show.i('tmdb_id');

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          pinned: true,
          expandedHeight: 280,
          backgroundColor: kBg,
          actions: [
            PopupMenuButton<String>(
              onSelected: (value) => _menu(context, value, show),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'order',
                  child: Text(
                    'Episode order${show.s('episode_order_label') != null ? ' · ${show.s('episode_order_label')}' : ''}',
                  ),
                ),
                PopupMenuItem(
                  value: 'rewatch',
                  child: Text(inRewatch ? 'Cancel rewatch' : 'Start rewatch'),
                ),
                PopupMenuItem(
                  value: 'drop',
                  child: Text(show.b('dropped') ? 'Undrop show' : 'Drop show'),
                ),
              ],
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            titlePadding: const EdgeInsets.only(left: 72, right: 16, bottom: 14),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedArtwork(
                  url: backdrop,
                  fit: BoxFit.cover,
                  placeholder: Container(color: kCard),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                        kBg.withValues(alpha: 0.55),
                        kBg,
                      ],
                      stops: const [0, 0.3, 0.75, 1],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 108,
                  height: 162,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Poster(url: poster, title: title),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (show.s('tagline') != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            show.s('tagline')!,
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              color: kMuted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (show.d('tmdb_rating') != null)
                            RatingChip(rating: show.d('tmdb_rating')),
                          if (yearOf(show.s('first_air_date')).isNotEmpty)
                            TagChip(label: yearOf(show.s('first_air_date'))),
                          if (show.s('status') != null)
                            TagChip(label: show.s('status')!),
                          if (show.s('age_rating') != null)
                            TagChip(label: show.s('age_rating')!),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children:
                            show.strings('genres').map((g) => TagChip(label: g)).toList(),
                      ),
                      if (networks.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: networks.map((network) {
                            final id = network.i('id');
                            return ActionChip(
                              label: Text(
                                network.s('name') ?? '',
                                style: const TextStyle(fontSize: 10),
                              ),
                              onPressed: id == null
                                  ? null
                                  : () => openStudio(
                                        context,
                                        id,
                                        isNetwork: true,
                                      ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Watch progress',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                    const Spacer(),
                    Text(
                      '${watchPct.round()}%',
                      style: const TextStyle(fontSize: 12, color: kMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                ProgressBar(value: watchPct),
                if (inRewatch) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Rewatch in progress',
                    style: TextStyle(
                      fontSize: 11,
                      color: kAmber.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: ActionGrid(
              children: [
                _ShowAction(
                  icon: Icons.done_all_rounded,
                  label: 'Mark all watched',
                  onTap: showId == null
                      ? null
                      : () => _act(
                            context,
                            () => markShowWatched(context, showId),
                          ),
                ),
                _ShowAction(
                  icon: Icons.remove_done_rounded,
                  label: 'Unwatch all',
                  onTap: showId == null
                      ? null
                      : () => _act(
                            context,
                            () => unmarkShowWatched(context, showId),
                          ),
                ),
                _ShowAction(
                  icon: Icons.star_outline_rounded,
                  label: show.d('user_rating') != null &&
                          show.d('user_rating')! > 0
                      ? 'Rated ${fmtRating(show.d('user_rating'))}'
                      : 'Rate',
                  onTap: () => _act(
                    context,
                    () => openRatingDialog(context, show),
                  ),
                ),
                _ShowAction(
                  icon: Icons.playlist_add_rounded,
                  label: 'Add to list',
                  onTap: () => _act(
                    context,
                    () => addToListDialog(context, show),
                  ),
                ),
                _ShowAction(
                  icon: show.b('in_library')
                      ? Icons.library_add_check_rounded
                      : Icons.library_add_outlined,
                  label: show.b('in_library') ? 'In library' : 'Collect',
                  active: show.b('in_library'),
                  onTap: () => _act(
                    context,
                    () => toggleCollect(context, show),
                  ),
                ),
                _ShowAction(
                  icon: Icons.movie_outlined,
                  label: 'Trailer',
                  onTap: () => openTrailer(context, show),
                ),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              show.s('overview') ?? 'No overview available.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.5,
                color: Color(0xFFD4D4D8),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Seasons',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
                if (data.orders.length > 1)
                  TextButton.icon(
                    onPressed: () => _chooseOrder(context, data),
                    icon: const Icon(Icons.swap_vert_rounded, size: 16),
                    label: Text(
                      show.s('episode_order_label') ?? 'Episode order',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
              ],
            ),
          ),
        ),
        ...seasons.map((season) {
          final number = season.i('season_number') ?? 0;
          final state = asMap(states['$number']);
          final pct = state.d('watch_pct') ?? 0;
          final seasonPoster = app.imageUrl(
            season.s('poster_path') ?? show.s('poster_path'),
            size: 'w185',
          );
          return SliverToBoxAdapter(
            child: InkWell(
              onTap: showId == null
                  ? null
                  : () async {
                      await pushScreen(
                        context,
                        SeasonScreen(
                          showTmdbId: showId,
                          seasonNumber: number,
                          showTitle: title,
                        ),
                      );
                      reload();
                    },
              onLongPress: showId == null
                  ? null
                  : () => _bulkSeasons(context, seasons, showId, number),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                child: Row(
                  children: [
                    SizedBox(
                      width: 54,
                      height: 81,
                      child: Poster(
                        url: seasonPoster,
                        title: season.s('name'),
                        radius: 7,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  season.s('name') ??
                                      (number == 0 ? 'Specials' : 'Season $number'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                              if (state.b('watched'))
                                const Icon(
                                  Icons.check_circle,
                                  size: 15,
                                  color: kGreen,
                                ),
                            ],
                          ),
                          Text(
                            '${season.i('episode_count') ?? 0} episodes${season.s('air_date') != null ? ' · ${yearOf(season.s('air_date'))}' : ''}',
                            style: const TextStyle(fontSize: 10, color: kMuted),
                          ),
                          const SizedBox(height: 6),
                          ProgressBar(value: pct, height: 4),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, color: kMuted),
                  ],
                ),
              ),
            ),
          );
        }),
        if (data.recommendations.isNotEmpty)
          SliverToBoxAdapter(
            child: MediaRow(
              title: 'More like this',
              items: data.recommendations,
            ),
          ),
        SliverToBoxAdapter(
          child: CommentsSection(
            mediaType: 'series',
            tmdbId: show.i('tmdb_id'),
            title: 'Comments',
          ),
        ),
        SliverToBoxAdapter(
          child: TraktCommentsSection(
            mediaType: 'series',
            tmdbId: show.i('tmdb_id'),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 30)),
      ],
    );
  }

  Future<void> _menu(
    BuildContext context,
    String value,
    Map<String, dynamic> show,
  ) async {
    final id = show.i('tmdb_id');
    if (id == null) return;
    if (value == 'order') {
      await _chooseOrder(context, data);
    } else if (value == 'rewatch') {
      final changed = await toggleRewatch(
        context,
        id,
        running: asMap(show['rewatch']).isNotEmpty,
      );
      if (changed) reload();
    } else if (value == 'drop') {
      final changed = await toggleDrop(context, show);
      if (changed) reload();
    }
  }

  Future<void> _chooseOrder(BuildContext context, _ShowData data) async {
    final app = ScrobScope.of(context);
    final showId = data.detail.i('tmdb_id');
    if (showId == null) return;
    final order = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Episode order',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
            ...data.orders.map(
              (o) => ListTile(
                title: Text(o.s('label') ?? o.s('key') ?? ''),
                trailing: data.selectedOrder == o.s('key')
                    ? const Icon(Icons.check, color: kAccent)
                    : null,
                onTap: () => Navigator.pop(context, o),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (order == null) return;
    final key = order.s('key');
    if (key == null || key == data.selectedOrder) return;
    try {
      await app.post(
        '/shows/$showId/episode-order',
        {
          'episode_order': key,
          'order_label': order.s('label'),
          'force_refresh': true,
        },
      );
      showSnack(context, 'Episode order updated');
      reload();
    } catch (e) {
      showSnack(context, 'Could not change episode order: $e');
    }
  }
}

class _ShowAction extends StatelessWidget {
  const _ShowAction({
    required this.icon,
    required this.label,
    this.active = false,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ActionPill(icon: icon, label: label, active: active, onTap: onTap);
  }
}
