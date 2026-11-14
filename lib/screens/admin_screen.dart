import 'package:material_ui/material_ui.dart';

import '../core/app_state.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../widgets/common.dart';
import 'requests_screen.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 3, vsync: this);
  Future<Map<String, dynamic>>? _settings;
  Future<List<Map<String, dynamic>>>? _users;
  Future<Map<String, dynamic>>? _cache;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _settings ??= _loadSettings();
    _users ??= _loadUsers();
    _cache ??= _loadCache();
  }

  Future<Map<String, dynamic>> _loadSettings() async =>
      asMap(await ScrobScope.of(context).get('/admin/settings'));

  Future<List<Map<String, dynamic>>> _loadUsers() async {
    final data = await ScrobScope.of(context).get('/admin/users');
    return asMaps(data);
  }

  Future<Map<String, dynamic>> _loadCache() async =>
      asMap(await ScrobScope.of(context).get('/admin/maintenance/cache-stats'));

  void _reload() {
    setState(() {
      _settings = _loadSettings();
      _users = _loadUsers();
      _cache = _loadCache();
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    if (!app.isAdmin) {
      return Scaffold(
        appBar: AppBar(title: const Text('Admin')),
        body: const EmptyState(
          title: 'Admin access required',
          body: 'Sign in with an admin account to use these tools.',
          icon: Icons.lock_outline_rounded,
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin'),
        actions: [
          IconButton(
            tooltip: 'Requests',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RequestsScreen()),
            ),
            icon: const Icon(Icons.inbox_outlined),
          ),
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'Settings'),
            Tab(text: 'Users'),
            Tab(text: 'Maintenance'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _settingsTab(),
          _usersTab(),
          _maintenanceTab(),
        ],
      ),
    );
  }

  Widget _settingsTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _settings,
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
        return _AdminSettingsForm(
          settings: snapshot.data ?? const {},
          onSaved: _reload,
        );
      },
    );
  }

  Widget _usersTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _users,
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
        final users = snapshot.data ?? const [];
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          itemCount: users.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final user = users[index];
            final id = user.i('id');
            return ListTile(
              leading: UserAvatar(
                url: ScrobScope.of(context).imageUrl(user.s('avatar_url')),
                name: user.s('username'),
                size: 38,
              ),
              title: Text(
                user.s('username') ?? '',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${user.s('email') ?? ''}${user.b('is_admin') ? ' · admin' : ''}',
                style: const TextStyle(fontSize: 10),
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (value) async {
                  if (id == null) return;
                  final app = ScrobScope.of(context);
                  try {
                    if (value == 'admin') {
                      await app.patch('/admin/users/$id/toggle-admin');
                    } else if (value == 'delete') {
                      final ok = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete user?'),
                          content: Text(user.s('username') ?? ''),
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
                      await app.delete('/admin/users/$id');
                    }
                    _reload();
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Action failed: $e')),
                      );
                    }
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'admin',
                    child: Text(
                      user.b('is_admin') ? 'Remove admin' : 'Make admin',
                    ),
                  ),
                  const PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _maintenanceTab() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _cache,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView();
        }
        final cache = snapshot.data ?? const {};
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Image cache',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${cache.i('count') ?? cache.i('entries') ?? 0} entries · ${cache.d('size_mb') ?? cache.d('size_gb') ?? 0}',
                    style: const TextStyle(fontSize: 12, color: kMuted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  await ScrobScope.of(context)
                      .post('/admin/maintenance/clear-cache');
                  _reload();
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not clear cache: $e')),
                    );
                  }
                }
              },
              child: const Text('Clear image cache'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () async {
                try {
                  final result = asMap(
                    await ScrobScope.of(context).post('/admin/maintenance/heal'),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(result.s('message') ?? 'Metadata heal started'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Could not heal metadata: $e')),
                    );
                  }
                }
              },
              child: const Text('Heal metadata'),
            ),
          ],
        );
      },
    );
  }
}

class _AdminSettingsForm extends StatefulWidget {
  const _AdminSettingsForm({required this.settings, required this.onSaved});

  final Map<String, dynamic> settings;
  final VoidCallback onSaved;

  @override
  State<_AdminSettingsForm> createState() => _AdminSettingsFormState();
}

class _AdminSettingsFormState extends State<_AdminSettingsForm> {
  late final _tmdb =
      TextEditingController(text: widget.settings.s('tmdb_api_key'));
  late final _tvdb =
      TextEditingController(text: widget.settings.s('tvdb_api_key'));
  late final _tvdbPin =
      TextEditingController(text: widget.settings.s('tvdb_subscriber_pin'));
  late final _mdblist =
      TextEditingController(text: widget.settings.s('mdblist_api_key'));
  late bool _loggedOut = widget.settings.b('enable_logged_out_navigation');
  late bool _disableComments = widget.settings.b('disable_comments');
  late bool _imageCache = widget.settings.b('image_cache_enabled');
  bool _saving = false;

  @override
  void dispose() {
    _tmdb.dispose();
    _tvdb.dispose();
    _tvdbPin.dispose();
    _mdblist.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ScrobScope.of(context).patch('/admin/settings', {
        'tmdb_api_key': _tmdb.text.trim().isEmpty ? null : _tmdb.text.trim(),
        'tvdb_api_key': _tvdb.text.trim().isEmpty ? null : _tvdb.text.trim(),
        'tvdb_subscriber_pin':
            _tvdbPin.text.trim().isEmpty ? null : _tvdbPin.text.trim(),
        'mdblist_api_key':
            _mdblist.text.trim().isEmpty ? null : _mdblist.text.trim(),
        'enable_logged_out_navigation': _loggedOut,
        'disable_comments': _disableComments,
        'image_cache_enabled': _imageCache,
      });
      widget.onSaved();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Server settings saved')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save settings: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _tmdb,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'TMDB API key'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tvdb,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'TheTVDB API key'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _tvdbPin,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'TheTVDB subscriber PIN'),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _mdblist,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'MDBList API key'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Allow browsing without an account'),
          value: _loggedOut,
          onChanged: (v) => setState(() => _loggedOut = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Disable comments'),
          value: _disableComments,
          onChanged: (v) => setState(() => _disableComments = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable image cache'),
          value: _imageCache,
          onChanged: (v) => setState(() => _imageCache = v),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save server settings'),
        ),
      ],
    );
  }
}
