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

  test('transport failures become network ApiExceptions', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      client: MockClient((_) async => throw http.ClientException('boom')),
    );

    await expectLater(
      client.get('/history'),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
    );
    await expectLater(
      client.getBytes('/export/data'),
      throwsA(isA<ApiException>().having((e) => e.isNetwork, 'isNetwork', true)),
    );
  });

  test('requests time out instead of hanging', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      timeout: const Duration(milliseconds: 30),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      client.get('/slow'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.isNetwork, 'isNetwork', true)
            .having((e) => e.message, 'message', contains('too long')),
      ),
    );
  });

  test('FastAPI validation errors are flattened', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      client: MockClient((_) async => http.Response(
            jsonEncode({
              'detail': [
                {'msg': 'field required'},
                {'msg': 'too short'},
              ],
            }),
            422,
          )),
    );

    await expectLater(
      client.post('/x', {}),
      throwsA(
        isA<ApiException>()
            .having((e) => e.status, 'status', 422)
            .having((e) => e.message, 'message', 'field required\ntoo short'),
      ),
    );
  });

  test('string detail and plain-text bodies are surfaced', () async {
    final withDetail = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      client: MockClient(
        (_) async => http.Response(jsonEncode({'detail': 'no_sources'}), 400),
      ),
    );
    await expectLater(
      withDetail.get('/media/for-you'),
      throwsA(isA<ApiException>().having((e) => e.message, 'm', 'no_sources')),
    );

    final plain = ApiClient(
      baseUrl: 'https://example.test/api/proxy',
      client: MockClient((_) async => http.Response('bad gateway', 502)),
    );
    await expectLater(
      plain.get('/x'),
      throwsA(isA<ApiException>().having((e) => e.isServerError, 'srv', true)),
    );
  });

  test('describeError gives friendly text', () {
    expect(
      describeError(ApiException(401, 'x')),
      contains('session has expired'),
    );
    expect(describeError(ApiException(503, 'x')), contains('503'));
    expect(describeError(ApiException(0, 'Offline')), 'Offline');
    expect(describeError(ApiException(404, 'Not found')), 'Not found');
  });
}
