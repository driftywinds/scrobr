const backupFrequencyOff = 'off';
const backupFrequencyDaily = 'daily';
const backupFrequencyWeekly = 'weekly';
const backupFrequencyMonthly = 'monthly';

const backupFrequencyLabels = <String, String>{
  backupFrequencyOff: 'Off',
  backupFrequencyDaily: 'Daily',
  backupFrequencyWeekly: 'Weekly',
  backupFrequencyMonthly: 'Monthly',
};

const backupKeepOptions = [3, 5, 7, 10, 14, 30];

const backupUriKey = 'scrobr_backup_uri';
const backupDirectoryNameKey = 'scrobr_backup_directory_name';
const backupFrequencyKey = 'scrobr_backup_frequency';
const backupHourKey = 'scrobr_backup_hour';
const backupMinuteKey = 'scrobr_backup_minute';
const backupKeepKey = 'scrobr_backup_keep';
const backupLastKey = 'scrobr_backup_last';
const backupLastErrorKey = 'scrobr_backup_last_error';

/// Next local run at [hour]:[minute], or the following period when today's
/// slot has already passed. Monthly runs clamp to the last day of short months.
DateTime nextBackupRun(
  DateTime now, {
  required String frequency,
  required int hour,
  required int minute,
}) {
  var next = DateTime(now.year, now.month, now.day, hour, minute);
  if (next.isAfter(now)) return next;
  switch (frequency) {
    case backupFrequencyWeekly:
      return next.add(const Duration(days: 7));
    case backupFrequencyMonthly:
      return _addMonthClamped(next);
    default:
      return next.add(const Duration(days: 1));
  }
}

DateTime _addMonthClamped(DateTime value) {
  final monthIndex = value.month; // 1-12, adding one month
  final year = value.year + (monthIndex ~/ 12);
  final month = monthIndex % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  final day = value.day > lastDay ? lastDay : value.day;
  return DateTime(year, month, day, value.hour, value.minute);
}
