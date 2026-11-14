import 'package:material_ui/material_ui.dart';

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
    _future ??= _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final data = await ScrobScope.of(context).get('/auth/connections');
    if (data is List) return asMaps(data);
    return asMaps(asMap(data)['connections']);
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _add() async {
    var type = 'jellyfin';
    final name = TextEditingController();
    final url = TextEditingController();
    final token = TextEditingController();
    final userId = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Add connection'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(
                      value: 'jellyfin',
                      child: Text('Jellyfin'),
                    ),
                    DropdownMenuItem(value: 'emby', child: Text('Emby')),
                    DropdownMenuItem(value: 'plex', child: Text('Plex')),
                    DropdownMenuItem(value: 'nuvio', child: Text('Nuvio')),
                    DropdownMenuItem(value: 'stremio', child: Text('Stremio')),
                    DropdownMenuItem(value: 'arvio', child: Text('Arvio')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'jellyfin'),
                  decoration: const InputDecoration(labelText: 'Type'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: url,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(labelText: 'Server URL'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API key / token',
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: userId,
                  decoration: const InputDecoration(
                    labelText: 'Server user id (optional)',
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
              child: const Text('Add'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ScrobScope.of(context).post('/auth/connections', {
          'type': type,
          'name': name.text.trim(),
          'url': url.text.trim(),
          'token': token.text.trim(),
          if (userId.text.trim().isNotEmpty)
            'server_user_id': userId.text.trim(),
        });
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not add connection: $e')),
          );
        }
      }
    }
    name.dispose();
    url.dispose();
    token.dispose();
    userId.dispose();
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connections'),
        actions: [
          IconButton(
            onPressed: _add,
            icon: const Icon(Icons.add_rounded),
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
            return const EmptyState(
              title: 'No media servers connected',
              body:
                  'Add Jellyfin, Emby, Plex, Nuvio, Stremio or Arvio to sync your library.',
              icon: Icons.dns_outlined,
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
                        const Icon(Icons.dns_rounded, color: kAccent),
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
                          label: 'Push watched',
                          value: connection.b('push_watched'),
                          onChanged: id == null
                              ? null
                              : (v) => _patch(id, {'push_watched': v}),
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
