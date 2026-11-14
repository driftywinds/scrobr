import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/api.dart';
import '../core/app_state.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/theme.dart';
import 'admin_screen.dart';
import 'connections_screen.dart';
import 'requests_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _showKey = false;

  Future<void> _set(String key, dynamic value) async {
    final app = ScrobScope.of(context);
    try {
      await app.updateSettings({key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save setting: $e')),
        );
      }
    }
  }

  Future<void> _changePassword() async {
    final app = ScrobScope.of(context);
    final current = TextEditingController();
    final next = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await app.post('/auth/change-password', {
          'current_password': current.text,
          'new_password': next.text,
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Password changed')),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
    current.dispose();
    next.dispose();
  }

  Future<void> _changeEmail() async {
    final app = ScrobScope.of(context);
    final email = TextEditingController();
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change email'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'New email'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
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
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        final result = asMap(await app.post('/auth/change-email', {
          'new_email': email.text.trim(),
          'current_password': password.text,
        }));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result.s('message') ?? 'Check your inbox to confirm the change.',
              ),
            ),
          );
        }
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.message)),
          );
        }
      }
    }
    email.dispose();
    password.dispose();
  }

  Future<void> _regenerateKey() async {
    final app = ScrobScope.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Regenerate API key?'),
        content: const Text(
          'Any script or integration using the old key will stop working.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Regenerate'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.post('/auth/api-key/regenerate');
      await app.refresh();
      if (mounted) {
        setState(() => _showKey = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('API key regenerated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not regenerate key: $e')),
        );
      }
    }
  }

  Future<void> _setup2fa() async {
    final app = ScrobScope.of(context);
    try {
      final setup = asMap(await app.post('/auth/2fa/setup'));
      final secret = setup.s('secret') ?? '';
      final code = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Set up 2FA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add this secret to your authenticator app, then enter the 6-digit code.',
                  style: TextStyle(fontSize: 12, color: kMuted),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  secret,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: code,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '6-digit code'),
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
              child: const Text('Enable'),
            ),
          ],
        ),
      );
      if (ok == true) {
        final result = asMap(await app.post('/auth/2fa/enable', {
          'secret': secret,
          'code': code.text.trim(),
        }));
        await app.refresh();
        final codes = result.maps('codes');
        if (mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('2FA enabled'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Save these backup codes somewhere safe.',
                      style: TextStyle(fontSize: 12, color: kMuted),
                    ),
                    const SizedBox(height: 8),
                    ...codes.map(
                      (c) => SelectableText(
                        c.s('code') ?? c.toString(),
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Done'),
                ),
              ],
            ),
          );
        }
      }
      code.dispose();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not set up 2FA: $e')),
        );
      }
    }
  }

  Future<void> _disable2fa() async {
    final app = ScrobScope.of(context);
    final code = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Disable 2FA'),
        content: TextField(
          controller: code,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
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
    if (ok == true) {
      try {
        await app.post('/auth/2fa/disable', {'code': code.text.trim()});
        await app.refresh();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('2FA disabled')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not disable 2FA: $e')),
          );
        }
      }
    }
    code.dispose();
  }

  Future<void> _deviceGrants() async {
    final app = ScrobScope.of(context);
    try {
      final grants = asMaps(await app.get('/auth/device/grants'));
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: grants.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No connected apps.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: grants.length,
                  itemBuilder: (context, index) {
                    final grant = grants[index];
                    final id = grant.i('id');
                    return ListTile(
                      leading: const Icon(Icons.phonelink_lock_outlined),
                      title: Text(grant.s('client_name') ?? ''),
                      subtitle: Text(
                        '${grant.s('scope') ?? ''} · approved ${fmtDate(grant.s('approved_at') ?? grant.s('created_at'))}',
                        style: const TextStyle(fontSize: 10),
                      ),
                      trailing: TextButton(
                        onPressed: id == null
                            ? null
                            : () async {
                                await app.delete('/auth/device/grants/$id');
                                if (context.mounted) Navigator.pop(context);
                              },
                        child: const Text('Revoke'),
                      ),
                    );
                  },
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load connected apps: $e')),
        );
      }
    }
  }

  Future<void> _openWebConnections() async {
    final app = ScrobScope.of(context);
    final uri = Uri.parse('${app.server}/connections');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the web settings')),
        );
      }
    }
  }

  Future<void> _openWebUi() async {
    final app = ScrobScope.of(context);
    final uri = Uri.parse(app.server);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the web UI')),
        );
      }
    }
  }

  Future<void> _syncStatus() async {
    try {
      final data = await ScrobScope.of(context).get('/sync/status');
      final jobs = asMaps(data);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (context) => SafeArea(
          child: jobs.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('No sync jobs yet.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: jobs.length,
                  itemBuilder: (context, index) {
                    final job = jobs[index];
                    final total = job.i('total_items') ?? 0;
                    final done = job.i('processed_items') ?? 0;
                    return ListTile(
                      leading: Icon(
                        job.s('status') == 'running'
                            ? Icons.sync_rounded
                            : job.s('status') == 'completed'
                                ? Icons.check_circle_outline_rounded
                                : Icons.error_outline_rounded,
                      ),
                      title: Text(
                        '${job.s('source') ?? ''} · ${job.s('status') ?? ''}',
                      ),
                      subtitle: Text(
                        total > 0 ? '$done / $total' : job.s('message') ?? '',
                        style: const TextStyle(fontSize: 10),
                      ),
                    );
                  },
                ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not load sync status: $e')),
        );
      }
    }
  }

  Future<void> _sync(String path) async {
    final app = ScrobScope.of(context);
    try {
      await app.post(path);
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

  @override
  Widget build(BuildContext context) {
    final app = ScrobScope.of(context);
    final settings = app.settings ?? const <String, dynamic>{};
    final me = app.me ?? const <String, dynamic>{};

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          if (app.isApiKeyMode)
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'API-key sessions cannot change account settings. Sign in with a password for this screen.',
                style: TextStyle(fontSize: 12, color: kMuted),
              ),
            ),
          if (!app.isApiKeyMode) ...[
            const _Section('Account'),
            ListTile(
              leading: const Icon(Icons.person_outline_rounded),
              title: Text(me.s('display_name') ?? me.s('username') ?? ''),
              subtitle: Text(me.s('email') ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.key_rounded),
              title: const Text('API key'),
              subtitle: Text(
                _showKey
                    ? (me.s('api_key') ?? '')
                    : '••••••••••••••••',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: () => setState(() => _showKey = !_showKey),
                    icon: Icon(
                      _showKey
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                  IconButton(
                    onPressed: _regenerateKey,
                    icon: const Icon(Icons.refresh_rounded),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.lock_outline_rounded),
              title: const Text('Change password'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _changePassword,
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline_rounded),
              title: const Text('Change email'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _changeEmail,
            ),
            ListTile(
              leading: const Icon(Icons.security_rounded),
              title: const Text('Two-factor authentication'),
              subtitle: Text(me.b('totp_enabled') ? 'Enabled' : 'Disabled'),
              trailing: Switch(
                value: me.b('totp_enabled'),
                onChanged: (value) {
                  if (value) {
                    _setup2fa();
                  } else {
                    _disable2fa();
                  }
                },
              ),
            ),
            ListTile(
              leading: const Icon(Icons.phonelink_lock_outlined),
              title: const Text('Connected apps'),
              subtitle: const Text('Device grants with access to your data'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: _deviceGrants,
            ),
            ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Sign out'),
              onTap: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Sign out?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                );
                if (ok == true) await app.logout();
              },
            ),
          ],
          if (!app.isApiKeyMode) ...[
            const _Section('Preferences'),
            SwitchListTile(
              title: const Text('Blur explicit artwork'),
              value: settings.b('blur_explicit'),
              onChanged: (v) => _set('blur_explicit', v),
            ),
            SwitchListTile(
              title: const Text('24-hour time'),
              value: settings.b('time_format_24h'),
              onChanged: (v) => _set('time_format_24h', v),
            ),
            SwitchListTile(
              title: const Text('Show play button'),
              value: settings.b('show_play_button'),
              onChanged: (v) => _set('show_play_button', v),
            ),
            SwitchListTile(
              title: const Text('Shuffle Next Up'),
              value: settings.b('shuffle_next_up'),
              onChanged: (v) => _set('shuffle_next_up', v),
            ),
            SwitchListTile(
              title: const Text('Minimalist Next Up'),
              value: settings.b('minimalist_next_up'),
              onChanged: (v) => _set('minimalist_next_up', v),
            ),
            SwitchListTile(
              title: const Text('Hide watched from Recently Added'),
              value: settings.b('hide_watched_from_recently_added'),
              onChanged: (v) => _set('hide_watched_from_recently_added', v),
            ),
            SwitchListTile(
              title: const Text('Condense history by show'),
              value: settings.b('condense_history_by_show'),
              onChanged: (v) => _set('condense_history_by_show', v),
            ),
          ],
          const _Section('Library'),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: const Text('Connections'),
            subtitle: const Text('Jellyfin, Plex, Emby, Nuvio, Stremio, Arvio'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => pushScreen(context, const ConnectionsScreen()),
          ),
          ListTile(
            leading: const Icon(Icons.sync_rounded),
            title: const Text('Sync status'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: _syncStatus,
          ),
          const _Section('Integrations'),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Trakt'),
            subtitle: Text(
              settings.b('trakt_connected') ? 'Connected' : 'Not connected',
            ),
            trailing: settings.b('trakt_connected')
                ? IconButton(
                    onPressed: () => _sync('/trakt/sync'),
                    icon: const Icon(Icons.sync_rounded),
                  )
                : TextButton(
                    onPressed: _openWebConnections,
                    child: const Text('Manage on web'),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('Simkl'),
            subtitle: Text(
              settings.b('simkl_connected') ? 'Connected' : 'Not connected',
            ),
            trailing: settings.b('simkl_connected')
                ? IconButton(
                    onPressed: () => _sync('/simkl/sync'),
                    icon: const Icon(Icons.sync_rounded),
                  )
                : TextButton(
                    onPressed: _openWebConnections,
                    child: const Text('Manage on web'),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.link_rounded),
            title: const Text('MDBList'),
            subtitle: Text(
              settings.b('mdblist_connected') ? 'Connected' : 'Not connected',
            ),
            trailing: TextButton(
              onPressed: _openWebConnections,
              child: Text(settings.b('mdblist_connected') ? 'Manage' : 'Connect'),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.webhook_rounded),
            title: const Text('Bingebase webhook'),
            trailing: TextButton(
              onPressed: _openWebConnections,
              child: const Text('Set'),
            ),
          ),
          if (app.isAdmin) ...[
            const _Section('Administration'),
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Admin panel'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushScreen(context, const AdminScreen()),
            ),
            ListTile(
              leading: const Icon(Icons.inbox_outlined),
              title: const Text('Requests'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => pushScreen(context, const RequestsScreen()),
            ),
          ],
          const _Section('About'),
          ListTile(
            leading: const Icon(Icons.public_rounded),
            title: const Text('Open Scrob web UI'),
            subtitle: Text(app.server),
            trailing: const Icon(Icons.open_in_new_rounded, size: 16),
            onTap: _openWebUi,
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded),
            title: const Text('Scrob for Android'),
            subtitle: Text(app.server),
          ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
          color: kMuted,
        ),
      ),
    );
  }
}


