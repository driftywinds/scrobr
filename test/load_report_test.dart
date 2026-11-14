import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:scrob/core/api.dart';
import 'package:scrob/core/app_state.dart';

AppState _stateWith(http.Client Function() make) {
  final state = AppState(initialServer: 'https://example.test')
    ..token = 'jwt';
  // Swap the lazily-created ApiClient for one backed by a mock transport.
  state.debugUseClient(
    ApiClient(
      baseUrl: state.proxyUrl,
      token: 'jwt',
      client: make(),
    ),
  );
  return state;
}

void main() {
  test('all requests failing is reported as allFailed', () async {
    final state = _stateWith(
      () => MockClient((_) async => throw http.ClientException('offline')),
    );
    final report = LoadReport();

    await Future.wait([
      state.getTracked(report, '/a'),
      state.getTracked(report, '/b'),
    ]);

    expect(report.allFailed, isTrue);
    expect(report.partial, isFalse);
    expect(report.message, isNotEmpty);
  });

  test('mixed results are partial; 4xx stays quiet', () async {
    final state = _stateWith(
      () => MockClient((request) async {
        switch (request.url.path) {
          case '/api/proxy/ok':
            return http.Response('{"results": []}', 200);
          case '/api/proxy/boom':
            return http.Response('err', 500);
          default:
            return http.Response('{"detail": "no_sources"}', 400);
        }
      }),
    );
    final report = LoadReport();

    final ok = await state.getTracked(report, '/ok');
    await state.getTracked(report, '/boom');
    await state.getTracked(report, '/optional');

    expect(ok, isA<Map>());
    expect(report.attempts, 3);
    expect(report.errors, hasLength(1));
    expect(report.partial, isTrue);
    expect(report.allFailed, isFalse);
  });

  test('only 4xx responses never raise the report', () async {
    final state = _stateWith(
      () => MockClient((_) async => http.Response('{"detail":"nope"}', 404)),
    );
    final report = LoadReport();

    await state.getTracked(report, '/x');

    expect(report.hasErrors, isFalse);
    expect(report.allFailed, isFalse);
  });
}
