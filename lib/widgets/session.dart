import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';

Future<void> startManualSession(
  BuildContext context,
  Map<String, dynamic> media,
) async {
  final app = ScrobScope.of(context);
  final type = media.s('type');
  if (type != 'movie' && type != 'episode') return;
  try {
    final result = asMap(await app.post('/history/session/start', {
      'media_type': type,
      if (media.i('id') != null) 'media_id': media.i('id'),
      if (media.i('tmdb_id') != null) 'tmdb_id': media.i('tmdb_id'),
      'title': media.s('title'),
      'runtime': media.i('runtime'),
      if (type == 'episode') 'show_tmdb_id': media.i('show_tmdb_id'),
      if (type == 'episode') 'season_number': media.i('season_number'),
      if (type == 'episode') 'episode_number': media.i('episode_number'),
    }));
    final key = result.s('session_key');
    if (key == null || key.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not start a session')),
        );
      }
      return;
    }
    final runtime = result.i('runtime') ?? media.i('runtime') ?? 0;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ManualSessionDialog(
        sessionKey: key,
        runtimeMinutes: runtime,
        title: media.s('title') ?? 'Session',
      ),
    );
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not start session: $e')),
      );
    }
  }
}

class ManualSessionDialog extends StatefulWidget {
  const ManualSessionDialog({
    super.key,
    required this.sessionKey,
    required this.runtimeMinutes,
    required this.title,
  });

  final String sessionKey;
  final int runtimeMinutes;
  final String title;

  @override
  State<ManualSessionDialog> createState() => _ManualSessionDialogState();
}

class _ManualSessionDialogState extends State<ManualSessionDialog> {
  Timer? _timer;
  int _elapsed = 0;
  bool _playing = true;
  bool _busy = false;

  int get _total => widget.runtimeMinutes * 60;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || !_playing) return;
      setState(() {
        _elapsed = _total > 0
            ? (_elapsed + 1).clamp(0, _total)
            : _elapsed + 1;
      });
      if (_elapsed % 15 == 0) _send();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _send() async {
    final app = ScrobScope.of(context);
    try {
      await app.patch('/history/session/${widget.sessionKey}', {
        'progress_seconds': _elapsed,
        'state': _playing ? 'playing' : 'paused',
      });
    } catch (_) {
      // heartbeats are best effort
    }
  }

  Future<void> _toggle() async {
    setState(() => _playing = !_playing);
    await _send();
  }

  Future<void> _complete() async {
    setState(() => _busy = true);
    try {
      await _send();
      await ScrobScope.of(context)
          .post('/history/session/${widget.sessionKey}/complete');
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not complete session: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _dismiss() async {
    try {
      await ScrobScope.of(context)
          .delete('/history/session/${widget.sessionKey}');
    } catch (_) {
      // session may already be gone
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final pct = _total > 0 ? (_elapsed / _total * 100).clamp(0, 100) : 0;
    return AlertDialog(
      title: const Text('Watching session'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _playing ? Icons.play_circle_fill : Icons.pause_circle_filled,
                color: _playing ? kGreen : kAmber,
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                _playing ? 'Playing' : 'Paused',
                style: const TextStyle(fontSize: 11, color: kMuted),
              ),
              const Spacer(),
              Text(
                _total > 0
                    ? '${_fmt(_elapsed)} / ${_fmt(_total)}'
                    : _fmt(_elapsed),
                style: const TextStyle(fontSize: 11, color: kMuted),
              ),
            ],
          ),
          Slider(
            value: _elapsed.toDouble(),
            max: _total > 0 ? _total.toDouble() : 100.0,
            onChanged: (value) => setState(() => _elapsed = value.round()),
            onChangeEnd: (_) => _send(),
          ),
          LinearProgressIndicator(
            value: pct / 100,
            minHeight: 4,
            backgroundColor: kCard,
          ),
          const SizedBox(height: 6),
          Text(
            '${pct.round()}% · progress syncs to Now Playing',
            style: const TextStyle(fontSize: 10, color: kMuted),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : _dismiss,
          child: const Text('Discard'),
        ),
        TextButton(
          onPressed: _busy ? null : _toggle,
          child: Text(_playing ? 'Pause' : 'Resume'),
        ),
        FilledButton(
          onPressed: _busy ? null : _complete,
          child: Text(_busy ? 'Saving…' : 'Mark watched'),
        ),
      ],
    );
  }

  static String _fmt(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}

