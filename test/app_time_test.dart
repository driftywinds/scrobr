import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/app_time.dart';
import 'package:scrobr/core/format.dart';

void main() {
  tearDown(() => AppTime.initialize(null));

  test('formats timestamps in the selected IANA zone', () {
    AppTime.initialize('Asia/Kolkata');
    expect(
      fmtDateTime('2026-01-01T00:00:00Z', use24h: true),
      '1 Jan 2026, 05:30',
    );

    AppTime.initialize('America/New_York');
    expect(
      fmtDateTime('2026-01-01T00:00:00Z', use24h: true),
      '31 Dec 2025, 19:00',
    );
  });

  test('does not shift date-only values through a zone', () {
    AppTime.initialize('Pacific/Kiritimati');
    expect(fmtDate('2020-01-01'), '1 Jan 2020');
  });

  test('falls back to the phone zone when no override is set', () {
    AppTime.initialize(null);
    expect(AppTime.label, 'Phone time zone');
    expect(AppTime.zoneId, isNull);
  });
}
