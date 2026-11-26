import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'common.dart';

/// Poster-left row used by the Home Up Next list. Shows an episode code and
/// watched count for series, or a year/progress line for movies.
class UpNextTile extends StatefulWidget {
  const UpNextTile({
    super.key,
    required this.title,
    required this.posterUrl,
    this.episodeCode,
    this.subtitle,
    this.watched,
    this.total,
    this.progress,
    this.onTap,
    this.onCheck,
    this.loading = false,
  });

  /// True while the next episode is being looked up after a check. Shows a
  /// skeleton line instead of placeholder text and disables the check.
  final bool loading;

  final String title;
  final String? posterUrl;
  final String? episodeCode;
  final String? subtitle;
  final int? watched;
  final int? total;
  final double? progress;
  final VoidCallback? onTap;
  final Future<void> Function()? onCheck;

  @override
  State<UpNextTile> createState() => _UpNextTileState();
}

class _UpNextTileState extends State<UpNextTile> {
  bool _busy = false;

  Future<void> _check() async {
    final onCheck = widget.onCheck;
    if (onCheck == null || _busy) return;
    HapticFeedback.lightImpact();
    setState(() => _busy = true);
    try {
      await onCheck();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.total;
    final watched = widget.watched;
    final left = total != null && watched != null ? total - watched : null;
    final progress = widget.progress ??
        (total != null && total > 0 && watched != null
            ? (watched / total * 100).clamp(0.0, 100.0)
            : null);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 72,
                height: 108,
                child: Poster(
                  url: widget.posterUrl,
                  title: widget.title,
                  radius: 8,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                    if (widget.episodeCode != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              widget.episodeCode!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: kBody,
                              ),
                            ),
                          ),
                          if (widget.loading) ...[
                            const SizedBox(width: 8),
                            const SkeletonBox(width: 110, height: 12, radius: 4),
                          ] else if (widget.subtitle != null) ...[
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                widget.subtitle!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: kBody,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ] else if (widget.subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        widget.subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: kMuted),
                      ),
                    ],
                    const SizedBox(height: 10),
                    if (total != null && watched != null) ...[
                      Text(
                        left == null
                            ? '$watched / $total episodes'
                            : '$watched / $total episodes · $left left',
                        style: const TextStyle(fontSize: 11, color: kMuted),
                      ),
                      const SizedBox(height: 5),
                    ],
                    if (progress != null) ProgressBar(value: progress),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              if (widget.onCheck != null)
                Padding(
                  padding: const EdgeInsets.only(top: 30),
                  child: SizedBox(
                    width: 48,
                    height: 48,
                    child: Tooltip(
                      message: 'Mark watched',
                      child: OutlinedButton(
                      onPressed: (_busy || widget.loading) ? null : _check,
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.zero,
                        shape: const CircleBorder(),
                        side: BorderSide(
                          color: kAccentSolid.withValues(alpha: 0.8),
                        ),
                      ),
                      child: _busy
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check_rounded, size: 21),
                    ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
