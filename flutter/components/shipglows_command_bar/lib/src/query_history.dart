/// Number of searches kept in the query history.
const int commandBarQueryHistoryLimit = 20;

/// Number of searches listed under an empty field.
const int commandBarQueryHistoryShown = 5;

/// Where the searches that led to a command are kept, most recent first. A
/// search keeps its filter prefix (`> notes`), so it comes back filtered.
///
/// [read] is called while building, so it must be synchronous and never
/// write. Apps usually back it with `SharedPreferences`.
abstract interface class CommandBarQueryHistoryStore {
  /// Past searches, most recent first.
  List<String> read();

  /// Saves [queries]. A failed save throws; the bar reports it and goes on.
  Future<void> write(List<String> queries);
}

/// Query history kept in memory for the life of the store.
class MemoryCommandBarQueryHistory implements CommandBarQueryHistoryStore {
  final List<String> _queries = <String>[];

  @override
  List<String> read() => List<String>.unmodifiable(_queries);

  @override
  Future<void> write(List<String> queries) async {
    _queries
      ..clear()
      ..addAll(queries);
  }
}

/// Query history read and written through callbacks, for an app that already
/// has its own storage.
class CallbackCommandBarQueryHistory implements CommandBarQueryHistoryStore {
  const CallbackCommandBarQueryHistory({
    required List<String> Function() read,
    required Future<void> Function(List<String> queries) write,
  }) : _read = read,
       _write = write;

  final List<String> Function() _read;
  final Future<void> Function(List<String> queries) _write;

  @override
  List<String> read() => _read();

  @override
  Future<void> write(List<String> queries) => _write(queries);
}

/// [current] with [query] moved to the front, capped at [limit] entries.
/// Searches differing only by case or surrounding spaces count as one.
List<String> nextCommandBarQueryHistory(
  List<String> current,
  String query, {
  int limit = commandBarQueryHistoryLimit,
}) {
  final key = query.trim().toLowerCase();
  return [
    query,
    for (final existing in current)
      if (existing.trim().toLowerCase() != key) existing,
  ].take(limit).toList(growable: false);
}
