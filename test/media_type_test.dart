import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/format.dart';

void main() {
  test('normalizes show aliases to the lists API value', () {
    expect(normalizedMediaType({'type': 'show'}), 'series');
    expect(normalizedMediaType({'type': 'tv'}), 'series');
    expect(normalizedMediaType({'media_type': 'Series'}), 'series');
  });

  test('keeps valid types and infers missing ones', () {
    expect(normalizedMediaType({'type': 'movie'}), 'movie');
    expect(normalizedMediaType({'type': 'episode'}), 'episode');
    expect(normalizedMediaType({'type': 'person'}), 'person');
    expect(normalizedMediaType({'first_air_date': '2020-01-01'}), 'series');
    expect(normalizedMediaType({'release_date': '2020-01-01'}), 'movie');
    expect(normalizedMediaType({}), isNull);
  });
}
