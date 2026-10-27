/// Order picked in a list's sort control.
enum SortDirection { ascending, descending }

/// [items] sorted by [key] in [direction], stable (equal keys keep their
/// order). Items whose key is `null` always come last.
List<T> sortedBy<T, K extends Comparable<dynamic>>(
  Iterable<T> items,
  K? Function(T item) key, {
  SortDirection direction = SortDirection.ascending,
}) {
  final indexed = [
    for (final (index, item) in items.indexed) (index, item, key(item)),
  ];
  indexed.sort((a, b) {
    final ka = a.$3;
    final kb = b.$3;
    if (ka == null || kb == null) {
      if (ka == null && kb == null) {
        return a.$1.compareTo(b.$1);
      }
      return ka == null ? 1 : -1;
    }
    final byKey = direction == SortDirection.ascending
        ? ka.compareTo(kb)
        : kb.compareTo(ka);
    return byKey != 0 ? byKey : a.$1.compareTo(b.$1);
  });
  return [for (final entry in indexed) entry.$2];
}
