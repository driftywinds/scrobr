import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiException implements Exception {
  ApiException(this.status, this.message, [this.path = '']);

  final int status;
  final String message;
  final String path;

  bool get isUnauthorized => status == 401;

  /// No HTTP response at all: offline, DNS failure, TLS error or timeout.
  bool get isNetwork => status == 0;

  bool get isServerError => status >= 500;

  @override
  String toString() => 'HTTP $status: $message';
}

/// Turns any thrown object into a short sentence that is safe to show.
String describeError(Object error) {
  if (error is ApiException) {
    if (error.isNetwork) return error.message;
    if (error.isUnauthorized) return 'Your session has expired. Sign in again.';
    if (error.isServerError) {
      return 'The server had a problem (${error.status}). Try again shortly.';
    }
    return error.message;
  }
  if (error is TimeoutException) return 'The server took too long to respond.';
  return '$error';
}

class ApiClient {
  ApiClient({
    required String baseUrl,
    this.token,
    this.apiKey,
    http.Client? client,
    this.timeout = const Duration(seconds: 30),
    this.transferTimeout = const Duration(minutes: 3),
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

  /// Applies to ordinary JSON calls.
  final Duration timeout;

  /// Applies to uploads and downloads (exports, backups, avatars).
  final Duration transferTimeout;

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

  Future<Uint8List> getBytes(String path, [Map<String, dynamic>? query]) async {
    final request = http.Request('GET', _uri(path, query))
      ..headers.addAll(_headers);
    final response = await _perform(request, transferTimeout);
    if (_ok(response)) return response.bodyBytes;
    throw _failure(response, request.url.path);
  }

  Future<dynamic> postMultipart(
    String path, {
    required String field,
    required Uint8List bytes,
    required String filename,
    Map<String, String> fields = const {},
    String? mimeType,
  }) async {
    final request = http.MultipartRequest('POST', _uri(path))
      ..headers.addAll(_headers)
      ..fields.addAll(fields)
      ..files.add(
        http.MultipartFile.fromBytes(
          field,
          bytes,
          filename: filename,
          contentType: mimeType == null ? null : MediaType.parse(mimeType),
        ),
      );
    final response = await _perform(request, transferTimeout);
    if (_ok(response)) return _decode(response);
    throw _failure(response, request.url.path);
  }

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

    final response = await _perform(request, timeout);
    if (_ok(response)) return _decode(response);
    throw _failure(response, uri.path);
  }

  /// Sends [request] and buffers the response, mapping every transport-level
  /// failure (offline, DNS, TLS, timeout) to a network [ApiException].
  Future<http.Response> _perform(
    http.BaseRequest request,
    Duration limit,
  ) async {
    try {
      final streamed = await _http.send(request).timeout(limit);
      return await http.Response.fromStream(streamed).timeout(limit);
    } on TimeoutException {
      throw ApiException(
        0,
        'The server took too long to respond.',
        request.url.path,
      );
    } on SocketException {
      throw ApiException(
        0,
        'Can\'t reach the server. Check your connection.',
        request.url.path,
      );
    } on HandshakeException {
      throw ApiException(
        0,
        'Secure connection to the server failed.',
        request.url.path,
      );
    } on http.ClientException catch (e) {
      throw ApiException(0, 'Network error: ${e.message}', request.url.path);
    }
  }

  static bool _ok(http.Response response) =>
      response.statusCode >= 200 && response.statusCode < 300;

  static dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return null;
    try {
      return jsonDecode(response.body);
    } catch (_) {
      return response.body;
    }
  }

  /// Builds the exception for a non-2xx response. FastAPI reports either a
  /// string `detail` or a list of validation errors.
  static ApiException _failure(http.Response response, String path) {
    var detail = _decode(response);
    if (detail is Map && detail['detail'] != null) {
      detail = detail['detail'];
    }
    if (detail is List) {
      detail = detail
          .map((e) => e is Map ? (e['msg'] ?? e.toString()) : '$e')
          .join('\n');
    }
    final text = detail == null ? '' : '$detail';
    return ApiException(
      response.statusCode,
      text.isEmpty ? (response.reasonPhrase ?? 'Request failed') : text,
      path,
    );
  }
}
