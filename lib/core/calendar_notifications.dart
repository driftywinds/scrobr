import 'package:flutter/services.dart';

/// Local calendar-release notifications and their daily WorkManager poll.
class CalendarNotifications {
  static const _channel = MethodChannel('com.dw.scrobr/notifications');

  static Future<bool> setEnabled(bool enabled) async {
    final granted = await _channel.invokeMethod<bool>(
      'setEnabled',
      {'enabled': enabled},
    );
    return granted ?? false;
  }

  static Future<bool> permission() async =>
      await _channel.invokeMethod<bool>('permission') ?? false;
}
