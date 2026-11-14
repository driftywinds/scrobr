import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/image_cache.dart';
import 'skeleton.dart';

/// Network image backed by [DiskImageCache]: authenticated with the session
/// headers where needed, persisted across launches, de-duplicated across
/// widgets, falling back to public artwork, and faded in on first paint.
class NetImage extends StatefulWidget {
  const NetImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.loading,
    this.error,
    this.semanticLabel,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// Shown while loading. Defaults to a [SkeletonBox].
  final Widget? loading;

  /// Shown when the image can't be loaded or decoded. Defaults to [loading]'s
  /// static equivalent (an empty surface).
  final Widget? error;

  final String? semanticLabel;

  @override
  State<NetImage> createState() => _NetImageState();
}

class _NetImageState extends State<NetImage> {
  bool _started = false;
  String? _loadedUrl;
  Uint8List? _bytes;
  bool _failed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _maybeLoad();
  }

  @override
  void didUpdateWidget(NetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _maybeLoad();
  }

  void _maybeLoad() {
    final url = widget.url;
    // Same URL already loaded, loading or failed: nothing to do. This also
    // keeps ScrobScope notifications from re-triggering the request.
    if (_started && url == _loadedUrl) return;
    _started = true;
    _loadedUrl = url;
    _bytes = null;
    _failed = false;
    if (url == null || url.isEmpty) {
      _failed = true;
      return;
    }

    final cache = DiskImageCache.instance;
    final cached = cache.peek(url);
    if (cached != null) {
      _bytes = cached;
      return;
    }

    final app = ScrobScope.of(context);
    cache
        .load(
          url,
          headers: app.imageHeaders(url),
          fallbackUrl: app.directImageUrl(url),
        )
        .then(
          (bytes) {
            if (!mounted || _loadedUrl != url) return;
            setState(() => _bytes = bytes);
          },
          onError: (Object _) {
            if (!mounted || _loadedUrl != url) return;
            setState(() => _failed = true);
          },
        );
  }

  Widget _loading() =>
      widget.loading ??
      SkeletonBox(width: widget.width, height: widget.height, radius: 0);

  Widget _error() =>
      widget.error ?? SizedBox(width: widget.width, height: widget.height);

  @override
  Widget build(BuildContext context) {
    final bytes = _bytes;
    if (bytes != null) {
      return Image.memory(
        bytes,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        gaplessPlayback: true,
        semanticLabel: widget.semanticLabel,
        excludeFromSemantics: widget.semanticLabel == null,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (_, __, ___) => _error(),
      );
    }
    if (_failed) return _error();
    return _loading();
  }
}
