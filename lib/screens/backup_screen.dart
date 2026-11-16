import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/backup_schedule.dart';
import '../core/backup_service.dart';
import '../core/theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  SharedPreferences? _prefs;
  String? _uri;
  String? _directoryName;
  String _frequency = backupFrequencyOff;
  int _hour = 3;
  int _minute = 0;
  int _keep = 7;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _prefs = prefs;
      _uri = prefs.getString(backupUriKey);
      _directoryName = prefs.getString(backupDirectoryNameKey);
      _frequency = prefs.getString(backupFrequencyKey) ?? backupFrequencyOff;
      _hour = prefs.getInt(backupHourKey) ?? 3;
      _minute = prefs.getInt(backupMinuteKey) ?? 0;
      _keep = prefs.getInt(backupKeepKey) ?? 7;
    });
    if (_frequency != backupFrequencyOff && _uri != null) {
      try {
        await BackupService.schedule();
      } catch (_) {
        // A stale schedule can be fixed by changing any option.
      }
    }
  }

  Future<void> _persistAndSchedule() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(backupUriKey, _uri ?? '');
    await prefs.setString(backupDirectoryNameKey, _directoryName ?? '');
    await prefs.setString(backupFrequencyKey, _frequency);
    await prefs.setInt(backupHourKey, _hour);
    await prefs.setInt(backupMinuteKey, _minute);
    await prefs.setInt(backupKeepKey, _keep);
    try {
      await BackupService.schedule();
    } catch (e) {
      _snack('Could not schedule backups: ${_shortError(e)}');
    }
  }

  String _shortError(Object error) {
    final text = '$error'.split('\n').first.trim();
    return text.length > 180 ? '${text.substring(0, 180)}...' : text;
  }

  Future<void> _chooseFolder() async {
    setState(() => _busy = true);
    try {
      final uri = await BackupService.pickDirectory();
      if (uri == null || uri.isEmpty) return;
      final name = await BackupService.directoryName(uri);
      if (!mounted) return;
      setState(() {
        _uri = uri;
        _directoryName = name;
      });
      await _persistAndSchedule();
    } catch (e) {
      _snack('Could not use that folder: ${_shortError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setFrequency(String? value) async {
    if (value == null) return;
    if (value != backupFrequencyOff && _uri == null) {
      _snack('Choose a backup folder first');
      return;
    }
    setState(() => _frequency = value);
    await _persistAndSchedule();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;
    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    await _persistAndSchedule();
  }

  Future<void> _setKeep(int? value) async {
    if (value == null) return;
    setState(() => _keep = value);
    await _persistAndSchedule();
  }

  Future<void> _backupNow() async {
    if (_uri == null) {
      _snack('Choose a backup folder first');
      return;
    }
    setState(() => _busy = true);
    try {
      await BackupService.backupNow();
      _snack('Backup queued');
    } catch (e) {
      _snack('Could not start backup: ${_shortError(e)}');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final last = _prefs?.getString(backupLastKey);
    final lastError = _prefs?.getString(backupLastErrorKey);
    return Scaffold(
      appBar: AppBar(title: const Text('Automatic backups')),
      body: _prefs == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Scrobr can save a local .bak of your Scrob database on a '
                  'schedule. The app must remain signed in as an admin.',
                  style: TextStyle(fontSize: 12, height: 1.5, color: kMuted),
                ),
                const SizedBox(height: 16),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(
                    _directoryName == null || _directoryName!.isEmpty
                        ? 'Choose backup folder'
                        : _directoryName!,
                  ),
                  subtitle: Text(
                    _uri == null
                        ? 'No folder selected'
                        : 'Backups are written to this folder',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _busy ? null : _chooseFolder,
                ),
                const Divider(),
                DropdownButtonFormField<String>(
                  initialValue: _frequency,
                  decoration: const InputDecoration(labelText: 'Frequency'),
                  items: [
                    for (final entry in backupFrequencyLabels.entries)
                      DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                  ],
                  onChanged: _busy ? null : _setFrequency,
                ),
                if (_frequency != backupFrequencyOff) ...[
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Run at'),
                    subtitle: const Text(
                      'WorkManager may delay the run while the device sleeps',
                    ),
                    trailing: Text(
                      TimeOfDay(hour: _hour, minute: _minute).format(context),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: _busy ? null : _pickTime,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    initialValue: _keep,
                    decoration: const InputDecoration(
                      labelText: 'Backups to keep',
                    ),
                    items: [
                      for (final count in backupKeepOptions)
                        DropdownMenuItem(
                          value: count,
                          child: Text('$count'),
                        ),
                    ],
                    onChanged: _busy ? null : _setKeep,
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : _backupNow,
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Back up now'),
                ),
                if (last != null && last.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  Text(
                    'Last backup: $last',
                    style: const TextStyle(fontSize: 12, color: kMuted),
                  ),
                ],
                if (lastError != null && lastError.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Last error: $lastError',
                    style: const TextStyle(fontSize: 12, color: kDanger),
                  ),
                ],
              ],
            ),
    );
  }
}
