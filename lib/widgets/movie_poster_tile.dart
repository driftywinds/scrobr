import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme.dart';
import 'common.dart';

/// Poster-only tile for the Movies tab. The watched check sits in the
/// bottom-right corner with a full-size tap target.
class MoviePosterTile extends StatefulWidget {
  const MoviePosterTile({
    super.key,
    required this.title,
    required this.posterUrl,
    this.onTap,
    this.onCheck,
    this.subtitle,
  });

  /// Optional second line, e.g. the release year.
  final String? subtitle;

  final String title;
  final String? posterUrl;
  final VoidCallback? onTap;
  final Future<void> Function()? onCheck;

  @override
  State<MoviePosterTile> createState() => _MoviePosterTileState();
}

class _MoviePosterTileState extends State<MoviePosterTile> {
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Open ${widget.title}',
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Poster(url: widget.posterUrl, title: widget.title, radius: 0),
                  Positioned.fill(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(onTap: widget.onTap),
                    ),
                  ),
                  if (widget.onCheck != null)
                    Positioned(
                      right: 2,
                      bottom: 2,
                      child: Semantics(
                        button: true,
                        label: 'Mark ${widget.title} watched',
                        child: Material(
                          color: Colors.black.withValues(alpha: 0.62),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _busy ? null : _check,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: _busy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : const Icon(
                                        Icons.check_rounded,
                                        size: 22,
                                        color: Colors.white,
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        // Reserve two lines so a long title cannot make its poster shorter
        // than the rest of the grid.
        SizedBox(
          height: widget.subtitle == null ? 30 : 42,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (widget.subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    widget.subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10.5, color: kMuted),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
