import 'package:flutter_test/flutter_test.dart';
import 'package:scrobr/core/home_shortcuts.dart';

void main() {
  test('keeps saved order, drops unknown ids and appends new ones', () {
    expect(
      normalizeHomeShortcutOrder(['requests', 'bad', 'lists']),
      ['requests', 'lists', 'calendar', 'progress', 'dropped'],
    );
    expect(
      normalizeHomeShortcutOrder(null),
      defaultHomeShortcutIds,
    );
  });

  test('keeps only known hidden ids', () {
    expect(
      normalizeHiddenHomeShortcuts(['lists', 'bad', 'requests']),
      {'lists', 'requests'},
    );
    expect(normalizeHiddenHomeShortcuts(null), isEmpty);
  });
}
