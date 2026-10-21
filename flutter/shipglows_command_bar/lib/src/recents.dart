/// Number of recently run commands kept for the « Recent » section.
const int commandBarRecentLimit = 5;

/// Where the ids of the recently run commands are kept, most recent first.
///
/// [read] is called while building, so it must be synchronous and never
/// write. Apps usually back it with `SharedPreferences`.
abstract interface class CommandBarRecentsStore {
  /// Recent ids, most recent first.
  List<String> read();

  /// Saves [ids]. A failed save throws; the bar reports it and goes on.
  Future<void> write(List<String> ids);
}

/// Recents kept in memory for the life of the store.
class MemoryCommandBarRecents implements CommandBarRecentsStore {
  final List<String> _ids = <String>[];

  @override
  List<String> read() => List<String>.unmodifiable(_ids);

  @override
  Future<void> write(List<String> ids) async {
    _ids
      ..clear()
      ..addAll(ids);
  }
}

/// Recents read and written through callbacks, for an app that already has
/// its own storage.
class CallbackCommandBarRecents implements CommandBarRecentsStore {
  const CallbackCommandBarRecents({
    required List<String> Function() read,
    required Future<void> Function(List<String> ids) write,
  }) : _read = read,
       _write = write;

  final List<String> Function() _read;
  final Future<void> Function(List<String> ids) _write;

  @override
  List<String> read() => _read();

  @override
  Future<void> write(List<String> ids) => _write(ids);
}

/// [current] with [id] moved to the front, capped at [limit] entries.
List<String> nextCommandBarRecents(
  List<String> current,
  String id, {
  int limit = commandBarRecentLimit,
}) => [
  id,
  for (final existing in current)
    if (existing != id) existing,
].take(limit).toList(growable: false);
