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
            titlePadding: const EdgeInsets.only(left: 16, right: 16, bottom: 14),
            title: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            background: Stack(
              fit: StackFit.expand,
              children: [
                if (backdrop != null)
                  Image.network(backdrop, fit: BoxFit.cover)
                else
                  Container(color: kCard),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        kBg.withValues(alpha: 0.4),
                        kBg,
                      ],
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
                  child: Poster(url: poster, title: title),
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
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ShowAction(
                  icon: Icons.done_all_rounded,
                  label: 'Mark all watched',
                  onTap: () => _act(
                    context,
                    () => markShowWatched(context, show.i('tmdb_id')!),
                  ),
                ),
                _ShowAction(
                  icon: Icons.remove_done_rounded,
                  label: 'Unwatch all',
                  onTap: () => _act(
                    context,
                    () => unmarkShowWatched(context, show.i('tmdb_id')!),
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
          final seasonPoster = app.imageUrl(season.s('poster_path'), size: 'w185');
          return SliverToBoxAdapter(
            child: InkWell(
              onTap: () => pushScreen(
                context,
                SeasonScreen(
                  showTmdbId: show.i('tmdb_id')!,
                  seasonNumber: number,
                  showTitle: title,
                ),
              ),
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
        '/shows/${data.detail.i('tmdb_id')}/episode-order',
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
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: active ? kAccent.withValues(alpha: 0.2) : kSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active ? kAccent.withValues(alpha: 0.6) : const Color(0xFF3F3F46),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: active ? kAccent : kMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: active ? Colors.white : const Color(0xFFD4D4D8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
