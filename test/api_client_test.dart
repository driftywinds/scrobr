import 'dart:convert';
import 'dart:typed_data';

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

  test('binary downloads keep their bytes and gate headers', () async {
    late http.BaseRequest seen;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'jwt-token',
      client: MockClient((request) async {
        seen = request;
        return http.Response.bytes([80, 75, 3, 4], 200);
      }),
    );

    final bytes = await client.getBytes('/export/data');

    expect(bytes, [80, 75, 3, 4]);
    expect(seen.headers['Authorization'], 'Bearer jwt-token');
    expect(seen.headers['X-Api-Key'], ApiClient.proxyGateKey);
  });

  test('multipart uploads keep auth, gate header and fields', () async {
    late http.Request seen;
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      token: 'jwt-token',
      client: MockClient((request) async {
        seen = request;
        return http.Response('{}', 200);
      }),
    );

    await client.postMultipart(
      '/export/import',
      field: 'file',
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'export.zip',
      fields: const {'watched': 'true'},
      mimeType: 'image/png',
    );

    expect(seen.method, 'POST');
    expect(seen.url.path, '/api/proxy/export/import');
    expect(seen.headers['Authorization'], 'Bearer jwt-token');
    expect(seen.headers['X-Api-Key'], ApiClient.proxyGateKey);
    expect(seen.body, contains('name="watched"'));
    expect(seen.body, contains('export.zip'));
    expect(seen.body, contains('content-type: image/png'));
  });
}
