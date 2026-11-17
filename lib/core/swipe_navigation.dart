/// Returns the tab index selected by a horizontal fling.
///
/// A leftward swipe moves to the next tab; a rightward swipe moves back.
int swipeTargetIndex(
  int current,
  int length,
  double velocity, {
  double threshold = 150,
}) {
  if (length < 2) return current;
  if (velocity <= -threshold) return (current + 1).clamp(0, length - 1).toInt();
  if (velocity >= threshold) return (current - 1).clamp(0, length - 1).toInt();
  return current;
}
