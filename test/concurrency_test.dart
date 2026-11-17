import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/concurrency.dart';

void main() {
  test('mapConcurrent preserves order and limits concurrency', () async {
    var active = 0;
    var peak = 0;
    final result = await mapConcurrent(
      List.generate(12, (index) => index),
      3,
      (value) async {
        active++;
        if (active > peak) peak = active;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        active--;
        return value * 2;
      },
    );

    expect(result, [for (var i = 0; i < 12; i++) i * 2]);
    expect(peak, lessThanOrEqualTo(3));
    expect(peak, greaterThan(1));
  });

  test('mapConcurrent handles an empty list', () async {
    expect(
      await mapConcurrent<int, int>([], 4, (value) async => value),
      isEmpty,
    );
  });
}
