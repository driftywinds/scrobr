import 'package:flutter_test/flutter_test.dart';
import 'package:scrob/core/app_state.dart';

void main() {
  test('avatar headers carry the session but media artwork does not', () {
    final state = AppState(initialServer: 'https://example.test')
      ..token = 'jwt-token';

    final avatar = state.imageHeaders(
      'https://example.test/api/proxy/profile/avatar/1',
    );
    expect(avatar?['Authorization'], 'Bearer jwt-token');
    expect(avatar?['X-Api-Key'], isNotNull);

    expect(
      state.imageHeaders(
        'https://example.test/api/proxy/media/image/w500/poster.jpg',
      ),
      isNull,
    );
    expect(
      state.imageHeaders('https://image.tmdb.org/t/p/w500/poster.jpg'),
      isNull,
    );
  });
}
