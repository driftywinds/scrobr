import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  bool _backingUp = false;
  bool _restoring = false;

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
            tooltip: 'Create user',
            onPressed: _createUser,
            icon: const Icon(Icons.person_add_alt_1_rounded),
          ),
          IconButton(
            tooltip: 'Open web admin',
            onPressed: () async {
              final app = ScrobScope.of(context);
              await launchUrl(
                Uri.parse('${app.server}/admin'),
                mode: LaunchMode.externalApplication,
              );
            },
            icon: const Icon(Icons.public_rounded),
          ),
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

  Future<void> _backupDatabase() async {
    setState(() => _backingUp = true);
    try {
      final app = ScrobScope.of(context);
      final bytes = await app.client.getBytes('/admin/backup');
      final dir = await getTemporaryDirectory();
      final stamp = DateTime.now()
          .toIso8601String()
          .replaceAll(RegExp(r'[:.]'), '-');
      final file = File('${dir.path}/scrob_backup_$stamp.bak');
      await file.writeAsBytes(bytes, flush: true);
      if (!mounted) return;
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'application/octet-stream')],
          subject: 'Scrob database backup',
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not back up database: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _backingUp = false);
    }
  }

  Future<void> _restoreDatabase() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore database?'),
        content: const Text(
          'This replaces all server data with the selected .bak backup. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Choose file'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['bak'],
    );
    if (picked == null) return;
    setState(() => _restoring = true);
    try {
      final bytes = await picked.readAsBytes();
      final response = asMap(await ScrobScope.of(context).client.postMultipart(
        '/admin/restore',
        field: 'file',
        bytes: bytes,
        filename: picked.name.isEmpty ? 'scrob-backup.bak' : picked.name,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.s('status') == 'restored'
                ? 'Database restored'
                : (response.s('message') ?? 'Restore finished')),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not restore database: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _restoring = false);
    }
  }

  Future<void> _createUser() async {
    final username = TextEditingController();
    final email = TextEditingController();
    final password = TextEditingController();
    var isAdmin = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Create user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: username,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Administrator'),
                  value: isAdmin,
                  onChanged: (v) => setState(() => isAdmin = v),
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
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) {
      try {
        await ScrobScope.of(context).post('/admin/users', {
          'username': username.text.trim(),
          'email': email.text.trim(),
          'password': password.text,
          'is_admin': isAdmin,
        });
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not create user: $e')),
          );
        }
      }
    }
    username.dispose();
    email.dispose();
    password.dispose();
  }

  Future<void> _resetPassword(Map<String, dynamic> user) async {
    final id = user.i('id');
    if (id == null) return;
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Reset password for ${user.s('username') ?? ''}'),
        content: TextField(
          controller: password,
          obscureText: true,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'New password'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ScrobScope.of(context)
            .post('/admin/users/$id/reset-password', {'password': password.text});
        _reload();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not reset password: $e')),
          );
        }
      }
    }
    password.dispose();
  }

  Future<void> _disable2fa(Map<String, dynamic> user) async {
    final id = user.i('id');
    if (id == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA?'),
        content: Text(user.s('username') ?? ''),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Disable'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ScrobScope.of(context)
          .post('/admin/users/$id/disable-2fa');
      _reload();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not disable 2FA: $e')),
        );
      }
    }
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
                    } else if (value == 'reset') {
                      await _resetPassword(user);
                      return;
                    } else if (value == 'disable2fa') {
                      await _disable2fa(user);
                      return;
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
                  if (user.b('totp_enabled'))
                    const PopupMenuItem(
                      value: 'disable2fa',
                      child: Text('Disable 2FA'),
                    ),
                  const PopupMenuItem(
                    value: 'reset',
                    child: Text('Reset password'),
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
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _backingUp ? null : _backupDatabase,
              icon: _backingUp
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.download_rounded, size: 18),
              label: const Text('Download database backup'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonalIcon(
              onPressed: _restoring ? null : _restoreDatabase,
              icon: _restoring
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: const Text('Restore database backup'),
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
  late final _radarrUrl =
      TextEditingController(text: widget.settings.s('radarr_url'));
  late final _radarrToken =
      TextEditingController(text: widget.settings.s('radarr_token'));
  late final _sonarrUrl =
      TextEditingController(text: widget.settings.s('sonarr_url'));
  late final _sonarrToken =
      TextEditingController(text: widget.settings.s('sonarr_token'));
  late final _cacheLimit = TextEditingController(
    text: widget.settings.d('image_cache_limit_gb')?.toString() ?? '',
  );
  late final _defaultOrder =
      TextEditingController(text: widget.settings.s('default_episode_order'));
  late bool _loggedOut = widget.settings.b('enable_logged_out_navigation');
  late bool _disableComments = widget.settings.b('disable_comments');
  late bool _imageCache = widget.settings.b('image_cache_enabled');
  late bool _radarrApproval = widget.settings.b('radarr_require_approval');
  late bool _sonarrApproval = widget.settings.b('sonarr_require_approval');
  bool _saving = false;

  @override
  void dispose() {
    _tmdb.dispose();
    _tvdb.dispose();
    _tvdbPin.dispose();
    _mdblist.dispose();
    _radarrUrl.dispose();
    _radarrToken.dispose();
    _sonarrUrl.dispose();
    _sonarrToken.dispose();
    _cacheLimit.dispose();
    _defaultOrder.dispose();
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
        'radarr_url': _radarrUrl.text.trim().isEmpty ? null : _radarrUrl.text.trim(),
        'radarr_token':
            _radarrToken.text.trim().isEmpty ? null : _radarrToken.text.trim(),
        'sonarr_url': _sonarrUrl.text.trim().isEmpty ? null : _sonarrUrl.text.trim(),
        'sonarr_token':
            _sonarrToken.text.trim().isEmpty ? null : _sonarrToken.text.trim(),
        'radarr_require_approval': _radarrApproval,
        'sonarr_require_approval': _sonarrApproval,
        'image_cache_limit_gb':
            double.tryParse(_cacheLimit.text.trim()),
        'default_episode_order': _defaultOrder.text.trim().isEmpty
            ? null
            : _defaultOrder.text.trim(),
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
        const SizedBox(height: 16),
        const Text(
          'Radarr / Sonarr requests',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _radarrUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Radarr URL'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _radarrToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Radarr API key'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sonarrUrl,
          keyboardType: TextInputType.url,
          decoration: const InputDecoration(labelText: 'Sonarr URL'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _sonarrToken,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Sonarr API key'),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require approval for Radarr requests'),
          value: _radarrApproval,
          onChanged: (v) => setState(() => _radarrApproval = v),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Require approval for Sonarr requests'),
          value: _sonarrApproval,
          onChanged: (v) => setState(() => _sonarrApproval = v),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _defaultOrder,
          decoration: const InputDecoration(
            labelText: 'Default episode order',
            hintText: 'e.g. tmdb:aired',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _cacheLimit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Image cache limit (GB)',
            hintText: 'empty = unlimited/default',
          ),
        ),
        const SizedBox(height: 12),
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
