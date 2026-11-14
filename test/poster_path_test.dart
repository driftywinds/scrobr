import 'package:flutter_test/flutter_test.dart';
import 'package:scrob/core/format.dart';

void main() {
  test('episodes use the show poster', () {
    expect(
      posterPathFor({
        'type': 'episode',
        'poster_path': 'still.jpg',
        'show_poster_path': 'show.jpg',
      }),
      'show.jpg',
    );
  });

  test('movies prefer their own poster and fall back to show poster', () {
    expect(
      posterPathFor({'type': 'movie', 'poster_path': 'movie.jpg'}),
      'movie.jpg',
    );
    expect(
      posterPathFor({'media_type': 'series', 'show_poster_path': 'show.jpg'}),
      'show.jpg',
    );
  });
}
