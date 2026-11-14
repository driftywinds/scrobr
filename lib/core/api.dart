import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.status, this.message, [this.path = '']);

  final int status;
  final String message;
  final String path;

  bool get isUnauthorized => status == 401;

  @override
  String toString() => 'HTTP $status: $message';
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    this.token,
    this.apiKey,
    http.Client? client,
  })  : baseUrl = baseUrl.replaceAll(RegExp(r'/+$'), ''),
        _http = client ?? http.Client();

  /// The web app's `/api/proxy` middleware only skips its cookie gate when an
  /// `X-Api-Key` header is present; the backend still enforces the real JWT or
  /// API key. Sending a non-secret marker lets native JWT requests reach it.
  static const proxyGateKey = 'scrob-native-client';

  final String baseUrl;
  final String? token;
  final String? apiKey;
  final http.Client _http;

  Map<String, String> get _headers => {
        'Accept': 'application/json',
        if (token != null && token!.isNotEmpty) 'Authorization': 'Bearer $token',
        'X-Api-Key': (apiKey != null && apiKey!.isNotEmpty)
            ? apiKey!
            : proxyGateKey,
      };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final clean = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$baseUrl$clean');
    if (query == null || query.isEmpty) return uri;
    final qp = <String, dynamic>{};
    query.forEach((key, value) {
      if (value == null) return;
      if (value is Iterable) {
        final values = value
            .where((e) => e != null && '$e'.isNotEmpty)
            .map((e) => '$e')
            .toList();
        if (values.isNotEmpty) qp[key] = values;
      } else if ('$value'.isNotEmpty) {
        qp[key] = value.toString();
      }
    });
    return uri.replace(queryParameters: qp.isEmpty ? null : qp);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? query]) =>
      _send('GET', _uri(path, query));

  Future<dynamic> post(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _send('POST', _uri(path, query), body: body);

  Future<dynamic> postForm(String path, Map<String, Object?> form) =>
      _send('POST', _uri(path), body: form, form: true);

  Future<dynamic> patch(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _send('PATCH', _uri(path, query), body: body);

  Future<dynamic> put(
    String path, [
    Object? body,
    Map<String, dynamic>? query,
  ]) =>
      _send('PUT', _uri(path, query), body: body);

  Future<dynamic> delete(String path, [Map<String, dynamic>? query]) =>
      _send('DELETE', _uri(path, query));

  Future<dynamic> _send(
    String method,
    Uri uri, {
    Object? body,
    bool form = false,
  }) async {
    final request = http.Request(method, uri)..headers.addAll(_headers);
    if (body != null) {
      if (form) {
        request.headers['Content-Type'] = 'application/x-www-form-urlencoded';
        request.body = (body as Map)
            .entries
            .map((e) =>
                '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
            .join('&');
      } else {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
    }

    http.Response response;
    try {
      final streamed = await _http.send(request);
      response = await http.Response.fromStream(streamed);
    } catch (e) {
      throw ApiException(0, 'Network error: $e', uri.path);
    }

    dynamic parsed;
    if (response.body.isNotEmpty) {
      try {
        parsed = jsonDecode(response.body);
      } catch (_) {
        parsed = response.body;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parsed;
    }

    var detail = parsed;
    if (parsed is Map && parsed['detail'] != null) {
      detail = parsed['detail'];
    }
    if (detail is List) {
      detail = detail
          .map((e) => e is Map ? (e['msg'] ?? e.toString()) : '$e')
          .join('\n');
    }
    throw ApiException(
      response.statusCode,
      detail == null || '$detail'.isEmpty ? response.reasonPhrase ?? 'Request failed' : '$detail',
      uri.path,
    );
  }
}
