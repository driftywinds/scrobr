import 'dart:math' as math;

/// Runs [action] over [items] with at most [limit] in flight, preserving order.
Future<List<R>> mapConcurrent<T, R>(
  List<T> items,
  int limit,
  Future<R> Function(T item) action,
) async {
  if (items.isEmpty) return <R>[];
  final workerCount = math.min(limit, items.length);
  final results = List<R?>.filled(items.length, null);
  var next = 0;

  Future<void> worker() async {
    while (true) {
      final index = next++;
      if (index >= items.length) return;
      results[index] = await action(items[index]);
    }
  }

  await Future.wait([for (var i = 0; i < workerCount; i++) worker()]);
  return results.cast<R>();
}
