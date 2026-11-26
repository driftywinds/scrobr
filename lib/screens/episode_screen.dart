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
import '../core/friendly_error.dart';

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
            return Scaffold(
              appBar: AppBar(),
              body: const DetailSkeleton(),
            );
          }
          if (snapshot.hasError) {
            return Scaffold(
              appBar: AppBar(),
              body: ErrorView(
                message: friendlyError(snapshot.error),
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

          final hasStill = still != null && still.isNotEmpty;
          final showName = show.s('title') ?? widget.showTitle ?? '';

          // Previous / Next stay pinned to the bottom so you can step through
          // a season without scrolling past cast and comments first. They
          // replace the current page so Back still returns to the season.
          void goTo(Map<String, dynamic> target) {
            final number = target.i('episode_number');
            if (number == null) return;
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => EpisodeScreen(
                  showTmdbId: widget.showTmdbId,
                  seasonNumber: widget.seasonNumber,
                  episodeNumber: number,
                  showTitle: widget.showTitle,
                  seasonTitle: widget.seasonTitle,
                ),
              ),
            );
          }

          Widget? stepBar;
          if (prev.isNotEmpty || next.isNotEmpty) {
            stepBar = DecoratedBox(
              decoration: const BoxDecoration(
                color: kBg,
                border: Border(top: BorderSide(color: kBorder)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: prev.isEmpty
                            ? const SizedBox.shrink()
                            : OutlinedButton.icon(
                                onPressed: () => goTo(prev.last),
                                icon: const Icon(Icons.chevron_left_rounded),
                                label: Text(
                                  'E${prev.last.i('episode_number') ?? ''}',
                                ),
                              ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: next.isEmpty
                            ? const SizedBox.shrink()
                            : OutlinedButton(
                                onPressed: () => goTo(next.first),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        'Next · E${next.first.i('episode_number') ?? ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const Icon(Icons.chevron_right_rounded),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return Scaffold(
            bottomNavigationBar: stepBar,
            body: CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                // Without a still image the hero would just be a black block,
                // so collapse to a normal app bar that names the show.
                expandedHeight: hasStill ? 220 : null,
                backgroundColor: kBg,
                title: hasStill
                    ? null
                    : Text(
                        showName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 16),
                      ),
                flexibleSpace: !hasStill
                    ? null
                    : FlexibleSpaceBar(
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
                      InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => openShow(context, widget.showTmdbId),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  'S${widget.seasonNumber}E${widget.episodeNumber} · $showName',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: kAccentSoft,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: kAccentSoft,
                              ),
                            ],
                          ),
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
                  child: Column(
                    children: [
                      _EpisodeAction(
                        primary: !watched,
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
                      const SizedBox(height: 8),
                      ActionGrid(
                        children: [
                          _EpisodeAction(
                            icon: detail.d('user_rating') != null &&
                                    detail.d('user_rating')! > 0
                                ? Icons.star_rounded
                                : Icons.star_outline_rounded,
                            label: detail.d('user_rating') != null &&
                                    detail.d('user_rating')! > 0
                                ? 'Rated ${fmtRating(detail.d('user_rating'))}'
                                : 'Rate',
                            active: detail.d('user_rating') != null &&
                                detail.d('user_rating')! > 0,
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
                        ],
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
            ),
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
  Widget build(BuildContext context) =>
      PeopleRow(title: title, people: people);
}

class _EpisodeAction extends StatelessWidget {
  const _EpisodeAction({
    required this.icon,
    required this.label,
    this.active = false,
    this.primary = false,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionPill(
      icon: icon,
      label: label,
      active: active,
      primary: primary,
      onTap: onTap,
    );
  }
}

