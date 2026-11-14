import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/app_state.dart';
import 'package:scrobr/core/format.dart';

void main() {
  test('normalizes server origins', () {
    expect(AppState.normalizeOrigin(''), '');
    expect(
      AppState.normalizeOrigin('scrob.example.com'),
      'https://scrob.example.com',
    );
    expect(
      AppState.normalizeOrigin('https://scrob.example.com/api/proxy/'),
      'https://scrob.example.com',
    );
  });

  test('formats month-axis labels', () {
    expect(fmtMonthShort('2022-11'), 'Nov 22');
    expect(fmtMonthShort(''), '');
  });
}
