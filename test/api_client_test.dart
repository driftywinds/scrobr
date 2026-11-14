import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scrob/core/api.dart';

void main() {
  test('native requests carry the proxy gate header', () async {
    late http.BaseRequest seen;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      client: MockClient((request) async {
        seen = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      }),
    );

    await client.get('/history');

    expect(seen.headers['X-Api-Key'], ApiClient.proxyGateKey);
    expect(seen.headers.containsKey('Authorization'), isFalse);
  });

  test('JWT requests carry both the bearer token and gate header', () async {
    late http.BaseRequest seen;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'jwt-token',
      client: MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      }),
    );

    await client.get('/auth/me');

    expect(seen.headers['Authorization'], 'Bearer jwt-token');
    expect(seen.headers['X-Api-Key'], ApiClient.proxyGateKey);
  });
}
