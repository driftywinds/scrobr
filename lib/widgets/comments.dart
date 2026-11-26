import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import 'common.dart';
import '../core/friendly_error.dart';

class CommentsSection extends StatefulWidget {
  const CommentsSection({
    super.key,
    required this.mediaType,
    this.tmdbId,
    this.tvdbId,
    this.seasonNumber,
    this.episodeNumber,
    this.title = 'Comments',
  });

  final String mediaType;
  final int? tmdbId;
  final int? tvdbId;
  final int? seasonNumber;
  final int? episodeNumber;
  final String title;

  @override
  State<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends State<CommentsSection> {
  Future<List<Map<String, dynamic>>>? _future;
  final Set<int> _revealed = {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final app = ScrobScope.of(context);
    final data = await app.get('/comments', {
      'media_type': widget.mediaType,
      if (widget.tmdbId != null) 'tmdb_id': widget.tmdbId,
      if (widget.tvdbId != null) 'tvdb_id': widget.tvdbId,
      if (widget.seasonNumber != null) 'season_number': widget.seasonNumber,
      if (widget.episodeNumber != null) 'episode_number': widget.episodeNumber,
    });
    return asMaps(data);
  }

  void _reload() {
    setState(() => _future = _load());
  }

  Future<void> _compose({Map<String, dynamic>? existing}) async {
    final app = ScrobScope.of(context);
    if (app.isApiKeyMode) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comments need a password login, not an API key.'),
        ),
      );
      return;
    }
    final controller =
        TextEditingController(text: existing?.s('content') ?? '');
    var spoiler = existing?.b('is_spoiler') ?? false;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(existing == null ? 'Add a comment' : 'Edit comment'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                autofocus: true,
                minLines: 2,
                maxLines: 6,
                decoration: const InputDecoration(
                  hintText: 'Share your thoughts…',
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: spoiler,
                onChanged: (v) => setState(() => spoiler = v ?? false),
                title: const Text(
                  'Contains spoilers',
                  style: TextStyle(fontSize: 12),
                ),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(existing == null ? 'Post' : 'Save'),
            ),
          ],
        ),
      ),
    );
    if (result != true) {
      controller.dispose();
      return;
    }
    try {
      if (existing == null) {
        await app.post('/comments', {
          'media_type': widget.mediaType,
          if (widget.tmdbId != null) 'tmdb_id': widget.tmdbId,
          if (widget.tvdbId != null) 'tvdb_id': widget.tvdbId,
          if (widget.seasonNumber != null) 'season_number': widget.seasonNumber,
          if (widget.episodeNumber != null)
            'episode_number': widget.episodeNumber,
          'content': controller.text,
          'is_spoiler': spoiler,
        });
      } else {
        await app.patch('/comments/${existing.i('id')}', {
          'content': controller.text,
          'is_spoiler': spoiler,
        });
      }
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save comment: ${friendlyError(e)}')),
        );
      }
    } finally {
      controller.dispose();
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete comment?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ScrobScope.of(context).delete('/comments/$id');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete comment: ${friendlyError(e)}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => _compose(),
                icon: const Icon(Icons.add_comment_outlined, size: 15),
                label: const Text('Comment', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.all(8),
                  child: LinearProgressIndicator(minHeight: 2),
                );
              }
              if (snapshot.hasError) {
                return Text(
                  'Comments unavailable: ${snapshot.error}',
                  style: const TextStyle(fontSize: 11, color: kMuted),
                );
              }
              final comments = snapshot.data ?? const [];
              if (comments.isEmpty) {
                return const Text(
                  'No comments yet.',
                  style: TextStyle(fontSize: 12, color: kMuted),
                );
              }
              return Column(
                children: comments.map((comment) {
                  final id = comment.i('id') ?? 0;
                  final own =
                      comment.i('user_id') == app.userId || app.isAdmin;
                  final spoiler = comment.b('is_spoiler');
                  final hidden = spoiler && !_revealed.contains(id);
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
                            UserAvatar(
                              url: app.imageUrl(comment.s('avatar_url')),
                              name: comment.s('display_name') ??
                                  comment.s('username'),
                              size: 28,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                comment.s('display_name') ??
                                    comment.s('username') ??
                                    '',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Text(
                              fmtDate(comment.s('created_at')),
                              style: const TextStyle(
                                fontSize: 9,
                                color: kMuted,
                              ),
                            ),
                            if (own)
                              PopupMenuButton<String>(
                                padding: EdgeInsets.zero,
                                iconSize: 16,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _compose(existing: comment);
                                  } else if (value == 'delete') {
                                    _delete(id);
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Text('Delete'),
                                  ),
                                ],
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (hidden)
                          TextButton(
                            onPressed: () =>
                                setState(() => _revealed.add(id)),
                            child: const Text(
                              'Spoiler — tap to reveal',
                              style: TextStyle(fontSize: 11),
                            ),
                          )
                        else
                          Text(
                            comment.s('content') ?? '',
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.4,
                              color: Color(0xFFD4D4D8),
                            ),
                          ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}
