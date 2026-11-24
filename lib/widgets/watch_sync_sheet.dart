import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../core/watch_sync.dart';

Future<void> showWatchSyncSheet(BuildContext context) {
  final app = ScrobScope.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => WatchSyncSheet(app: app),
  );
}

class WatchSyncSheet extends StatefulWidget {
  const WatchSyncSheet({super.key, required this.app});

  final AppState app;

  @override
  State<WatchSyncSheet> createState() => _WatchSyncSheetState();
}

class _WatchSyncSheetState extends State<WatchSyncSheet> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted &&
          (widget.app.watchFlushAt != null || widget.app.watchSyncing)) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String _status(AppState app) {
    if (app.watchSyncing) {
      return 'Sending ${app.watchSending.length} action'
          '${app.watchSending.length == 1 ? '' : 's'}…';
    }
    if (app.watchPendingCount > 0) {
      final at = app.watchFlushAt;
      if (at == null) return 'Waiting to send';
      final seconds = at.difference(DateTime.now()).inSeconds.clamp(0, 5);
      return 'Waiting ${seconds}s for more changes';
    }
    if (app.watchSyncError != null) return 'Last sync failed';
    return 'Up to date';
  }

  IconData _statusIcon(AppState app) {
    if (app.watchSyncing) return Icons.sync_rounded;
    if (app.watchPendingCount > 0) return Icons.schedule_rounded;
    if (app.watchSyncError != null) return Icons.cloud_off_rounded;
    return Icons.cloud_done_outlined;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final waiting = [...app.watchQueue];
        final sending = [...app.watchSending];
        final active = [...waiting, ...sending];
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.78,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 2, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Sync status',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Icon(
                      _statusIcon(app),
                      size: 18,
                      color: app.watchSyncError != null
                          ? kDanger
                          : app.watchPendingCount > 0
                              ? kAccentSolid
                              : kGreen,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _status(app),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (active.isNotEmpty && !app.watchSyncing)
                      TextButton(
                        onPressed: app.flushWatchQueue,
                        child: Text(
                          app.watchSyncError == null ? 'Send now' : 'Retry',
                        ),
                      ),
                  ],
                ),
              ),
              if (app.watchSyncError != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      app.watchSyncError!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: kDanger,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                  children: [
                    if (sending.isNotEmpty) ...[
                      const _SyncSection('Sending'),
                      for (final action in sending)
                        _ActionRow(action: action, icon: Icons.sync_rounded),
                    ],
                    if (waiting.isNotEmpty) ...[
                      const _SyncSection('Waiting in queue'),
                      for (final action in waiting)
                        _ActionRow(
                          action: action,
                          icon: Icons.schedule_rounded,
                        ),
                    ],
                    if (active.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(bottom: 14),
                        child: Text(
                          'No actions queued.',
                          style: TextStyle(fontSize: 12, color: kMuted),
                        ),
                      ),
                    if (app.lastWatchBatch.isNotEmpty) ...[
                      _SyncSection(
                        'Last batch · ${app.lastWatchSyncAt == null ? '—' : fmtDateTime(app.lastWatchSyncAt!.toIso8601String(), use24h: true)}',
                      ),
                      for (final action in app.lastWatchBatch)
                        _ActionRow(
                          action: action,
                          icon: app.watchSyncError == null
                              ? Icons.check_circle_rounded
                              : Icons.error_outline_rounded,
                          color: app.watchSyncError == null ? kGreen : kDanger,
                        ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SyncSection extends StatelessWidget {
  const _SyncSection(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 6),
        child: Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: kMuted,
          ),
        ),
      );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.action,
    required this.icon,
    this.color,
  });

  final QueuedWatch action;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color ?? kAccentSoft),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                action.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5),
              ),
            ),
            const Text(
              'Watched',
              style: TextStyle(fontSize: 10, color: kMuted),
            ),
          ],
        ),
      );
}
