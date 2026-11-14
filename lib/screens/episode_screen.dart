import 'package:material_ui/material_ui.dart';

import '../core/actions.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import '../widgets/comments.dart';
import '../widgets/session.dart';
import '../widgets/trakt_comments.dart';
import '../widgets/common.dart';

class EpisodeScreen extends StatefulWidget {
  const EpisodeScreen({
    super.key,
    required this.showTmdbId,
    required this.seasonNumber,
    required this.episodeNumber,
    this.showTitle,
    this.seasonTitle,
  });

  final int showTmdbId;
  final int seasonNumber;
  final int episodeNumber;
  final String? showTitle;
  final String? seasonTitle;

  @override
  State<EpisodeScreen> createState() => _EpisodeScreenState();
}

class _EpisodeScreenState extends State<EpisodeScreen> {
  Future<Map<String, dynamic>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<Map<String, dynamic>> _load() async => asMap(
        await ScrobScope.of(context).get(
          '/shows/${widget.showTmdbId}/season/${widget.seasonNumber}/${widget.episodeNumber}',
        ),
      );

  void _reload() => setState(() => _future = _load());

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<Map<String, dynamic>>(
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
          final detail = snapshot.data ?? const {};
          final show = asMap(detail['show']);
          final episode = <String, dynamic>{
            ...detail,
            'type': 'episode',
            'show_tmdb_id': widget.showTmdbId,
            'show_title': show.s('title') ?? widget.showTitle,
          };
          final app = ScrobScope.of(context);
          final still = app.imageUrl(detail.s('still_path'), size: 'w780');
          final showPoster = app.imageUrl(show.s('poster_path'), size: 'w185');
          final episodes = detail.maps('episodes');
          final cast = detail.maps('cast');
          final guestStars = detail.maps('guest_stars');
          final watched = detail.b('watched');
          final prev = episodes.where(
            (e) => (e.i('episode_number') ?? 0) < widget.episodeNumber,
          );
          final next = episodes.where(
            (e) => (e.i('episode_number') ?? 0) > widget.episodeNumber,
          );

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 240,
                backgroundColor: kBg,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedArtwork(
                        url: still,
                        fit: BoxFit.cover,
                        placeholder: Container(color: kCard),
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              kBg.withValues(alpha: 0.5),
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
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'S${widget.seasonNumber}E${widget.episodeNumber} · ${show.s('title') ?? widget.showTitle ?? ''}',
                        style: const TextStyle(
                          fontSize: 11,
                          color: kAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail.s('title') ?? 'Episode',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          if (detail.s('air_date') != null)
                            TagChip(label: fmtDate(detail.s('air_date'))),
                          if (detail.i('runtime') != null)
                            TagChip(label: fmtRuntime(detail.i('runtime'))),
                          if (detail.d('tmdb_rating') != null &&
                              detail.d('tmdb_rating')! > 0)
                            RatingChip(rating: detail.d('tmdb_rating')),
                          if (watched)
                            const TagChip(label: 'Watched'),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _EpisodeAction(
                        icon: watched
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        label: watched ? 'Watched' : 'Mark watched',
                        active: watched,
                        onTap: () async {
                          final changed =
                              await toggleWatched(context, episode);
                          if (changed) _reload();
                        },
                      ),
                      _EpisodeAction(
                        icon: Icons.star_outline_rounded,
                        label: detail.d('user_rating') != null &&
                                detail.d('user_rating')! > 0
                            ? 'Rated ${fmtRating(detail.d('user_rating'))}'
                            : 'Rate',
                        onTap: () async {
                          final changed =
                              await openRatingDialog(context, episode);
                          if (changed) _reload();
                        },
                      ),
                      _EpisodeAction(
                        icon: Icons.playlist_add_rounded,
                        label: 'Add show to list',
                        onTap: () => addToListDialog(context, episode),
                      ),
                      _EpisodeAction(
                        icon: Icons.timer_outlined,
                        label: 'Session',
                        onTap: () async {
                          await startManualSession(context, episode);
                          _reload();
                        },
                      ),
                      _EpisodeAction(
                        icon: Icons.open_in_new_rounded,
                        label: 'Open show',
                        onTap: () => openShow(context, widget.showTmdbId),
                      ),
                    ],
                  ),
                ),
              ),
              if (detail.s('overview') != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                    child: Text(
                      detail.s('overview')!,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.5,
                        color: Color(0xFFD4D4D8),
                      ),
                    ),
                  ),
                ),
              if (cast.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PeopleRow(
                    title: 'Cast',
                    people: cast,
                    showPoster: showPoster,
                  ),
                ),
              if (guestStars.isNotEmpty)
                SliverToBoxAdapter(
                  child: _PeopleRow(
                    title: 'Guest stars',
                    people: guestStars,
                    showPoster: showPoster,
                  ),
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Row(
                    children: [
                      if (prev.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final e = prev.last;
                              final number = e.i('episode_number');
                              if (number == null) return;
                              pushScreen(
                                context,
                                EpisodeScreen(
                                  showTmdbId: widget.showTmdbId,
                                  seasonNumber: widget.seasonNumber,
                                  episodeNumber: number,
                                  showTitle: widget.showTitle,
                                  seasonTitle: widget.seasonTitle,
                                ),
                              );
                            },
                            icon: const Icon(Icons.chevron_left_rounded),
                            label: const Text('Previous'),
                          ),
                        ),
                      if (prev.isNotEmpty && next.isNotEmpty)
                        const SizedBox(width: 8),
                      if (next.isNotEmpty)
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              final e = next.first;
                              final number = e.i('episode_number');
                              if (number == null) return;
                              pushScreen(
                                context,
                                EpisodeScreen(
                                  showTmdbId: widget.showTmdbId,
                                  seasonNumber: widget.seasonNumber,
                                  episodeNumber: number,
                                  showTitle: widget.showTitle,
                                  seasonTitle: widget.seasonTitle,
                                ),
                              );
                            },
                            icon: const Icon(Icons.chevron_right_rounded),
                            label: const Text('Next'),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: CommentsSection(
                  mediaType: 'episode',
                  tmdbId: detail.i('tmdb_id'),
                  seasonNumber: widget.seasonNumber,
                  episodeNumber: widget.episodeNumber,
                  title: 'Episode comments',
                ),
              ),
              SliverToBoxAdapter(
                child: TraktCommentsSection(
                  mediaType: 'episode',
                  tmdbId: detail.i('tmdb_id'),
                  seasonNumber: widget.seasonNumber,
                  episodeNumber: widget.episodeNumber,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 30)),
            ],
          );
        },
      ),
    );
  }
}

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({
    required this.title,
    required this.people,
    this.showPoster,
  });

  final String title;
  final List<Map<String, dynamic>> people;
  final String? showPoster;

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: -0.3),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 138,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: people.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final person = people[index];
                final id = person.i('tmdb_id');
                return SizedBox(
                  width: 80,
                  child: InkWell(
                    onTap: id == null ? null : () => openPerson(context, id),
                    child: Column(
                      children: [
                        UserAvatar(
                          url: app.imageUrl(
                            person.s('profile_path'),
                            size: 'w185',
                          ),
                          name: person.s('name'),
                          size: 70,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          person.s('name') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          person.s('character') ?? '',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 9, color: kMuted),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _EpisodeAction extends StatelessWidget {
  const _EpisodeAction({
    required this.icon,
    required this.label,
    this.active = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionPill(icon: icon, label: label, active: active, onTap: onTap);
  }
}

