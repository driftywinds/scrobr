import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';

class TraktCommentsSection extends StatefulWidget {
  const TraktCommentsSection({
    super.key,
    required this.mediaType,
    this.tmdbId,
    this.tvdbId,
    this.seasonNumber,
    this.episodeNumber,
  });

  final String mediaType;
  final int? tmdbId;
  final int? tvdbId;
  final int? seasonNumber;
  final int? episodeNumber;

  @override
  State<TraktCommentsSection> createState() => _TraktCommentsSectionState();
}

class _TraktCommentsSectionState extends State<TraktCommentsSection> {
  Future<Map<String, dynamic>?>? _future;
  final Set<int> _revealed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = ScrobScope.of(context);
    final enabled = (app.settings ?? const <String, dynamic>{}).b('trakt_show_comments');
    if (!enabled) {
      _future = null;
      return;
    }
    _future ??= _load();
  }

  Future<Map<String, dynamic>?> _load() async {
    final app = ScrobScope.of(context);
    try {
      final data = asMap(await app.get('/trakt/comments', {
        'media_type': widget.mediaType,
        if (widget.tmdbId != null) 'tmdb_id': widget.tmdbId,
        if (widget.tmdbId == null && widget.tvdbId != null)
          'tvdb_id': widget.tvdbId,
        if (widget.seasonNumber != null) 'season_number': widget.seasonNumber,
        if (widget.episodeNumber != null)
          'episode_number': widget.episodeNumber,
      }));
      return data;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _future,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null || data.b('enabled') == false) {
          return const SizedBox.shrink();
        }
        final comments = data.maps('comments');
        if (comments.isEmpty) return const SizedBox.shrink();
        final traktUrl = data.s('trakt_url');
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.forum_outlined, size: 17, color: kDanger),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Trakt comments (${comments.length})',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (traktUrl != null)
                    TextButton(
                      onPressed: () => launchUrl(
                        Uri.parse(traktUrl),
                        mode: LaunchMode.externalApplication,
                      ),
                      child: const Text(
                        'View on Trakt',
                        style: TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
              ...comments.map((comment) {
                final id = comment.i('id') ?? 0;
                final spoiler = comment.b('spoiler');
                final hidden = spoiler && !_revealed.contains(id);
                final user = asMap(comment['user']);
                return Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 13,
                            backgroundColor: kCard,
                            child: Text(
                              initials(user.s('name') ?? user.s('username')),
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              user.s('name') ??
                                  user.s('username') ??
                                  'Trakt user',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (comment.b('review'))
                            const TagChip(label: 'Review'),
                          const SizedBox(width: 4),
                          Text(
                            fmtDate(comment.s('created_at')),
                            style:
                                const TextStyle(fontSize: 9, color: kMuted),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (hidden)
                        TextButton(
                          onPressed: () => setState(() => _revealed.add(id)),
                          child: const Text(
                            'Spoiler — tap to reveal',
                            style: TextStyle(fontSize: 11),
                          ),
                        )
                      else
                        Text(
                          comment.s('comment') ?? '',
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.45,
                            color: Color(0xFFD4D4D8),
                          ),
                        ),
                      if ((comment.i('likes') ?? 0) > 0)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${comment.i('likes')} likes',
                            style:
                                const TextStyle(fontSize: 9, color: kMuted),
                          ),
                        ),
                    ],
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

