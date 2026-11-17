import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/swipe_navigation.dart';

void main() {
  test('swipe left advances and swipe right goes back', () {
    expect(swipeTargetIndex(0, 2, -300), 1);
    expect(swipeTargetIndex(1, 2, 300), 0);
    expect(swipeTargetIndex(1, 3, -300), 2);
    expect(swipeTargetIndex(1, 3, 300), 0);
  });

  test('swipes clamp at the ends and ignore weak gestures', () {
    expect(swipeTargetIndex(1, 2, -300), 1);
    expect(swipeTargetIndex(0, 2, 300), 0);
    expect(swipeTargetIndex(0, 2, -50), 0);
    expect(swipeTargetIndex(0, 1, -300), 0);
  });
}
