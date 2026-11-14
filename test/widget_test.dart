import 'package:flutter_test/flutter_test.dart';
import 'package:scrob/core/app_state.dart';

void main() {
  test('normalizes server origins', () {
    expect(
      AppState.normalizeOrigin('scrob.example.com'),
      'https://scrob.example.com',
    );
    expect(
      AppState.normalizeOrigin('https://scrob.example.com/api/proxy/'),
      'https://scrob.example.com',
    );
  });
}
