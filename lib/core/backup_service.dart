import 'package:flutter/services.dart';

/// Bridge to the Android WorkManager backup worker. Configuration itself is
/// stored in Flutter's SharedPreferences so the worker can read it offline.
class BackupService {
  static const _channel = MethodChannel('com.dw.scrobr/backup');

  static Future<String?> pickDirectory() =>
      _channel.invokeMethod<String>('pickDirectory');

  static Future<String?> directoryName(String uri) =>
      _channel.invokeMethod<String>('directoryName', {'uri': uri});

  static Future<void> schedule() => _channel.invokeMethod<void>('schedule');

  static Future<void> backupNow() => _channel.invokeMethod<void>('backupNow');
}
