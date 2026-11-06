/// An immutable ordered journal whose active prefix can be undone and redone.
///
/// Entries describe edits to replay, rather than snapshots or compensating
/// commands. The caller interprets them and owns persistence and domain limits.
/// Entries themselves must be immutable. Returned lists cannot be modified.
class UndoJournal<T> {
  const UndoJournal() : entries = const [], cursor = 0;

  const UndoJournal._(this.entries, this.cursor);

  /// Copies [entries] and selects the active prefix, defaulting to all entries.
  factory UndoJournal.fromEntries(Iterable<T> entries, {int? cursor}) {
    final copy = List<T>.unmodifiable(entries);
    final position = cursor ?? copy.length;
    RangeError.checkValueInInterval(position, 0, copy.length, 'cursor');
    return UndoJournal._(copy, position);
  }

  /// Every entry, including the inactive redo suffix.
  final List<T> entries;

  /// Number of active entries.
  final int cursor;

  bool get canUndo => cursor > 0;
  bool get canRedo => cursor < entries.length;
  List<T> get activeEntries => List<T>.unmodifiable(entries.take(cursor));
  List<T> get redoEntries => List<T>.unmodifiable(entries.skip(cursor));

  /// Forks at [cursor], dropping redo. [replaceLast] compacts the last active
  /// entry when one exists; the caller decides when compaction is appropriate.
  UndoJournal<T> append(T entry, {bool replaceLast = false}) {
    // Typed explicitly: the const journal holds an empty List<Never>.
    final next = <T>[...entries.take(cursor)];
    if (replaceLast && next.isNotEmpty) {
      next[next.length - 1] = entry;
    } else {
      next.add(entry);
    }
    return UndoJournal._(List<T>.unmodifiable(next), next.length);
  }

  UndoJournal<T> undo() => canUndo ? UndoJournal._(entries, cursor - 1) : this;

  UndoJournal<T> redo() => canRedo ? UndoJournal._(entries, cursor + 1) : this;
}
