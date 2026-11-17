import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';

class ConnectionsScreen extends StatefulWidget {
  const ConnectionsScreen({super.key});

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!ScrobScope.of(context).isApiKeyMode) {
      _future ??= _load();
    }
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await ScrobScope.of(context).get('/auth/connections');
    if (data is List) return asMaps(data);
    return asMaps(asMap(data)['connections']);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _openWeb() async {
    final app = ScrobScope.of(context);
    final uri = Uri.parse('${app.server}/connections');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the web connections page')),
        );
      }
    }
  }

  Future<void> _patch(int id, Map<String, dynamic> patch) async {
    try {
      await ScrobScope.of(context).patch('/auth/connections/$id', patch);
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update connection: $e')),
        );
      }
    }
  }

  Future<void> _sync(int id, {bool full = false}) async {
    try {
      await ScrobScope.of(context).post(
        '/sync/connection/$id',
        null,
        full ? {'full': true} : null,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start sync: $e')),
        );
      }
    }
  }

  Future<void> _push(int id) async {
    try {
      await ScrobScope.of(context).post('/sync/connection/$id/push');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push started')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start push: $e')),
        );
      }
    }
  }

  Future<void> _schedule(Map<String, dynamic> connection) async {
    final id = connection.i('id');
    if (id == null) return;
    final sync = TextEditingController(
      text: connection.d('auto_sync_interval')?.toString() ?? '',
    );
    final push = TextEditingController(
      text: connection.d('auto_push_interval')?.toString() ?? '',
    );
    final scrobble = TextEditingController(
      text: connection.i('scrobble_percent')?.toString() ?? '',
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sync schedule'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: sync,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Auto sync interval',
                  hintText: 'minutes, empty = off',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: push,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Auto push interval',
                  hintText: 'minutes, empty = off',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: scrobble,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Scrobble at % watched',
                  hintText: '1–100',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      if (!mounted) return;
      await _patch(id, {
        'auto_sync_interval': double.tryParse(sync.text.trim()),
        'auto_push_interval': double.tryParse(push.text.trim()),
        'scrobble_percent': int.tryParse(scrobble.text.trim()),
      });
      _reload();
    }
    sync.dispose();
    push.dispose();
    scrobble.dispose();
  }

  Future<void> _libraries(int id) async {
    final app = ScrobScope.of(context);
    try {
      final data = asMap(await app.get('/sync/connection/$id/libraries'));
      final libraries = data.maps('libraries');
      final selected = <String>{
        for (final lib in libraries)
          if (lib.b('selected'))
            (lib.s('key') ?? lib.s('id') ?? ''),
      };
      final result = await showDialog<Set<String>>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Libraries'),
            content: SizedBox(
              width: 340,
              child: ListView(
                shrinkWrap: true,
                children: libraries.map((lib) {
                  final key = lib.s('key') ?? lib.s('id') ?? '';
                  return CheckboxListTile(
                    value: selected.contains(key),
                    title: Text(lib.s('name') ?? key),
                    subtitle: Text(lib.s('type') ?? ''),
                    onChanged: (on) => setState(() {
                      on == true ? selected.add(key) : selected.remove(key);
                    }),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, selected),
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      );
      if (result != null) {
        await app.put('/sync/connection/$id/libraries', {
          'library_keys': result.toList(),
        });
        _reload();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load libraries: $e')),
        );
      }
    }
  }

  Future<void> _delete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete connection?'),
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
      await ScrobScope.of(context).delete('/auth/connections/$id');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    if (app.isApiKeyMode) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connections')),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const EmptyState(
              title: 'Password login required',
              body:
                  'Connections use account-level credentials. Sign in with your password, or manage them on the Scrob web UI.',
              icon: Icons.lock_outline_rounded,
            ),
            FilledButton.tonalIcon(
              onPressed: _openWeb,
              icon: const Icon(Icons.open_in_new_rounded, size: 16),
              label: const Text('Open web connections'),
            ),
          ],
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            onPressed: _openWeb,
            icon: const Icon(Icons.open_in_new_rounded),
          ),
        ],
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingView();
          }
          if (snapshot.hasError) {
            return ErrorView(
              message: '${snapshot.error}',
              onRetry: _reload,
            );
          }
          final connections = snapshot.data ?? const [];
          if (connections.isEmpty) {
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const EmptyState(
                  title: 'No media servers connected',
                  body:
                      'Link Jellyfin, Emby, Plex, Nuvio, Stremio or Arvio on the Scrob web UI.',
                  icon: Icons.dns_outlined,
                ),
                FilledButton.tonalIcon(
                  onPressed: _openWeb,
                  icon: const Icon(Icons.open_in_new_rounded, size: 16),
                  label: const Text('Open web connections'),
                ),
              ],
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            itemCount: connections.length,
            itemBuilder: (context, index) {
              final connection = connections[index];
              final id = connection.i('id');
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.dns_rounded, color: kAccent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                connection.s('name') ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${connection.s('type')} · ${connection.s('url')}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: kMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          onSelected: (value) {
                            if (id == null) return;
                            if (value == 'sync') _sync(id);
                            if (value == 'full') _sync(id, full: true);
                            if (value == 'push') _push(id);
                            if (value == 'libraries') _libraries(id);
                            if (value == 'delete') _delete(id);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(value: 'sync', child: Text('Sync now')),
                            PopupMenuItem(
                              value: 'full',
                              child: Text('Full resync'),
                            ),
                            PopupMenuItem(
                              value: 'push',
                              child: Text('Push now'),
                            ),
                            PopupMenuItem(
                              value: 'libraries',
                              child: Text('Choose libraries'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete'),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const Divider(height: 20),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        _Toggle(
                          label: 'Collection',
                          value: connection.b('sync_collection'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'sync_collection': v}),
                        ),
                        _Toggle(
                          label: 'Watched',
                          value: connection.b('sync_watched'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'sync_watched': v}),
                        ),
                        _Toggle(
                          label: 'Ratings',
                          value: connection.b('sync_ratings'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'sync_ratings': v}),
                        ),
                        _Toggle(
                          label: 'Playback',
                          value: connection.b('sync_playback'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'sync_playback': v}),
                        ),
                        _Toggle(
                          label: 'Push watched',
                          value: connection.b('push_watched'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'push_watched': v}),
                        ),
                        _Toggle(
                          label: 'Push collection',
                          value: connection.b('push_collection'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'push_collection': v}),
                        ),
                        _Toggle(
                          label: 'Push playback',
                          value: connection.b('push_playback'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'push_playback': v}),
                        ),
                        _Toggle(
                          label: 'Push ratings',
                          value: connection.b('push_ratings'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'push_ratings': v}),
                        ),
                        _Toggle(
                          label: 'Watchlist → Radarr',
                          value: connection.b('watchlist_to_radarr'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'watchlist_to_radarr': v}),
                        ),
                        _Toggle(
                          label: 'Watchlist → Sonarr',
                          value: connection.b('watchlist_to_sonarr'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'watchlist_to_sonarr': v}),
                        ),
                        if (connection.s('type') == 'plex') ...[
                          _Toggle(
                            label: 'Plex sync watchlist',
                            value: connection.b('plex_sync_watchlist'),
                            onChanged: id == null
                                ? null
                                : (v) => _patch(
                                      id,
                                      {'plex_sync_watchlist': v},
                                    ),
                          ),
                          _Toggle(
                            label: 'Plex push watchlist',
                            value: connection.b('plex_push_watchlist'),
                            onChanged: id == null
                                ? null
                                : (v) => _patch(
                                      id,
                                      {'plex_push_watchlist': v},
                                    ),
                          ),
                        ],
                        if (id != null)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _schedule(connection),
                              icon: const Icon(Icons.schedule_rounded, size: 16),
                              label: const Text('Sync schedule'),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label, style: const TextStyle(fontSize: 10)),
      selected: value,
      onSelected: onChanged == null ? null : (v) => onChanged!(v),
    );
  }
}
