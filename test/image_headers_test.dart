import 'package:flutter_test/flutter_test.dart';
import 'package:scrob/core/app_state.dart';

void main() {
  test('session headers cover own proxy images but not external URLs', () {
    final state = AppState(initialServer: 'https://example.test')
      ..token = 'jwt-token';

    final avatar = state.imageHeaders(
      'https://example.test/api/proxy/profile/avatar/1',
    );
    expect(avatar?['Authorization'], 'Bearer jwt-token');
    expect(avatar?['X-Api-Key'], isNotNull);

    final poster = state.imageHeaders(
      'https://example.test/api/proxy/media/image/w500/poster.jpg',
    );
    expect(poster?['Authorization'], 'Bearer jwt-token');

    expect(
      state.imageHeaders('https://image.tmdb.org/t/p/w500/poster.jpg'),
      isNull,
    );
  });

  test('TMDB posters are proxied and carry the session', () {
    final state = AppState(initialServer: 'https://example.test')
      ..token = 'jwt-token';

    final url = state.imageUrl(
      'https://image.tmdb.org/t/p/w500/poster.jpg',
      size: 'w342',
    );

    expect(
      url,
      'https://example.test/api/proxy/media/image/w342/poster.jpg',
    );
    expect(state.imageHeaders(url)?['Authorization'], 'Bearer jwt-token');
  });

  test('API-key mode uses public TMDB artwork directly', () {
    final state = AppState(initialServer: 'https://example.test')
      ..apiKey = 'key';

    const tmdb = 'https://image.tmdb.org/t/p/w500/poster.jpg';
    expect(state.imageUrl(tmdb, size: 'w342'), tmdb);
    expect(state.imageHeaders(tmdb), isNull);
  });
}
