import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/backup_schedule.dart';

void main() {
  test('daily backup uses today when the time is still ahead', () {
    expect(
      nextBackupRun(
        DateTime(2026, 11, 16, 2, 0),
        frequency: backupFrequencyDaily,
        hour: 3,
        minute: 30,
      ),
      DateTime(2026, 11, 16, 3, 30),
    );
  });

  test('daily backup rolls to tomorrow after the time has passed', () {
    expect(
      nextBackupRun(
        DateTime(2026, 11, 16, 4, 0),
        frequency: backupFrequencyDaily,
        hour: 3,
        minute: 30,
      ),
      DateTime(2026, 11, 17, 3, 30),
    );
  });

  test('weekly backup rolls seven days forward', () {
    expect(
      nextBackupRun(
        DateTime(2026, 11, 16, 4, 0),
        frequency: backupFrequencyWeekly,
        hour: 3,
        minute: 30,
      ),
      DateTime(2026, 11, 23, 3, 30),
    );
  });

  test('monthly backup clamps to the last day of a short month', () {
    expect(
      nextBackupRun(
        DateTime(2026, 1, 31, 4, 0),
        frequency: backupFrequencyMonthly,
        hour: 3,
        minute: 30,
      ),
      DateTime(2026, 2, 28, 3, 30),
    );
  });

  test('monthly backup crosses the year boundary', () {
    expect(
      nextBackupRun(
        DateTime(2026, 12, 31, 4, 0),
        frequency: backupFrequencyMonthly,
        hour: 3,
        minute: 30,
      ),
      DateTime(2027, 1, 31, 3, 30),
    );
  });
}
