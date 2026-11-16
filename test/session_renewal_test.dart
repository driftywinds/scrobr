import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scrobr/core/api.dart';
import 'package:scrobr/core/session.dart';

void main() {
  test('session renewal returns the new access token', () async {
    late http.BaseRequest seen;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'old-token',
      client: MockClient((request) async {
        seen = request;
        return http.Response(
          jsonEncode({'access_token': 'new-token', 'expires_in': 3600}),
          200,
        );
      }),
    );

    expect(await renewSessionToken(client), 'new-token');
    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/proxy/auth/session/renew');
    expect(seen.headers['Authorization'], 'Bearer old-token');
  });

  test('session renewal returns null when the server declines', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'old-token',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({'access_token': null, 'expires_in': null}),
          200,
        ),
      ),
    );

    expect(await renewSessionToken(client), isNull);
  });

  test('session renewal returns null on an HTTP error', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'old-token',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'detail': 'expired'}), 401),
      ),
    );

    expect(await renewSessionToken(client), isNull);
  });
}
