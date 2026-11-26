import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'api.dart';

/// Turns any thrown object into a short, human sentence.
///
/// Raw exception text ("HTTP 502: <html>…", "SocketException: Failed host
/// lookup…") is useless to the person using the app. Server-supplied messages
/// for client errors (wrong password, validation) are kept because they are
/// usually the most helpful thing we can say.
String friendlyError(Object? error, {String? fallback}) {
  const generic = 'Something went wrong. Please try again.';
  final other = fallback ?? generic;
  if (error == null) return other;

  if (error is TimeoutException) {
    return 'The server took too long to respond. Check your connection and try again.';
  }
  if (error is SocketException || error is http.ClientException) {
    return "Can't reach your server. Check your connection and try again.";
  }
  if (error is FormatException) {
    return 'The server sent a reply the app could not read.';
  }
  if (error is ApiException) return _fromApi(error, other);

  var text = '$error'.trim();
  for (final prefix in const ['Exception: ', 'Error: ']) {
    if (text.startsWith(prefix)) text = text.substring(prefix.length);
  }
  final lower = text.toLowerCase();
  if (lower.contains('socketexception') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection refused') ||
      lower.contains('network is unreachable') ||
      lower.contains('clientexception')) {
    return "Can't reach your server. Check your connection and try again.";
  }
  if (lower.contains('timed out') || lower.contains('timeout')) {
    return 'The server took too long to respond. Check your connection and try again.';
  }
  if (_looksTechnical(text)) return other;
  return text.isEmpty ? other : text;
}

String _fromApi(ApiException e, String other) {
  final status = e.status;
  final message = e.message.trim();
  final lower = message.toLowerCase();

  if (status == 0) {
    if (lower.contains('timed out')) {
      return 'The server took too long to respond. Check your connection and try again.';
    }
    return "Can't reach your server. Check your connection and try again.";
  }
  if (status >= 500) {
    return 'The server had a problem (error $status). Try again in a moment.';
  }
  if (status == 401 &&
      (message.isEmpty ||
          lower == 'unauthorized' ||
          lower.contains('not authenticated') ||
          lower.contains('token'))) {
    return 'Your session has expired. Please sign in again.';
  }
  if (status == 403 && (message.isEmpty || lower == 'forbidden')) {
    return "You don't have permission to do that.";
  }
  if (status == 404 && (message.isEmpty || lower.contains('not found'))) {
    return 'That could not be found. It may have been removed.';
  }
  if (status == 429) {
    return 'Too many requests. Wait a moment and try again.';
  }
  if (message.isNotEmpty && !_looksTechnical(message)) return message;
  return other;
}

bool _looksTechnical(String text) {
  if (text.length > 160) return true;
  final t = text.trimLeft();
  return t.startsWith('<') ||
      t.startsWith('{') ||
      t.startsWith('[') ||
      t.contains('Instance of') ||
      t.contains('#0 ');
}
