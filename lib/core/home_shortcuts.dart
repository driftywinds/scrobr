const defaultHomeShortcutIds = [
  'lists',
  'calendar',
  'progress',
  'dropped',
  'requests',
];

const homeShortcutLabels = {
  'lists': 'Lists',
  'calendar': 'Calendar',
  'progress': 'Progress',
  'dropped': 'Dropped',
  'requests': 'Requests',
};

String homeShortcutLabel(String id) => homeShortcutLabels[id] ?? id;

/// Keeps known ids in the saved order, then appends any newly added ones.
List<String> normalizeHomeShortcutOrder(Object? raw) {
  final candidate = raw is Iterable ? raw.whereType<String>() : const <String>[];
  final seen = <String>{};
  final order = <String>[];
  for (final id in [...candidate, ...defaultHomeShortcutIds]) {
    if (homeShortcutLabels.containsKey(id) && seen.add(id)) order.add(id);
  }
  return order;
}

Set<String> normalizeHiddenHomeShortcuts(Object? raw) {
  if (raw is! Iterable) return <String>{};
  return raw
      .whereType<String>()
      .where(homeShortcutLabels.containsKey)
      .toSet();
}
