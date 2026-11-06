import 'package:flutter/foundation.dart';

/// One change on an [UndoCommandStack]: [command] reverts it, [label] names
/// it for the caller's message (« Undo: Cut sentence »).
@immutable
class UndoCommandEntry<T> {
  const UndoCommandEntry(this.command, {required this.label});

  /// What undoing the change does. The stack never runs it: the caller does.
  final T command;

  /// Names the change, for an « Undo » or « Undone: … » message.
  final String label;
}

/// A bounded stack of compensating commands, for an app that never rewrites
/// its history: each change is kept with the command that reverts it, so the
/// history keeps both events.
///
/// [push] records a change and drops the oldest beyond [limit]. [latest] and
/// [popLatest] serve Ctrl/⌘+Z; [remove] takes a specific entry, for an « Undo »
/// button on that change's own message. The stack only holds and orders the
/// entries: the caller runs the commands and decides whether a change can
/// still be undone (its element may have changed since).
///
/// Undo-only: a compensating command is a new event, so there is no redo
/// stack to keep (use [UndoRedoHistory] for snapshots that can be replayed).
class UndoCommandStack<T> extends ChangeNotifier {
  UndoCommandStack({this.limit = 20}) : assert(limit > 0);

  /// Maximum number of entries kept, the oldest dropped first.
  final int limit;

  final List<UndoCommandEntry<T>> _entries = [];

  /// Whether there is a change to undo.
  bool get canUndo => _entries.isNotEmpty;

  /// Number of entries kept.
  int get length => _entries.length;

  /// The most recent entry, the one Ctrl/⌘+Z undoes; null when empty.
  UndoCommandEntry<T>? get latest => _entries.isEmpty ? null : _entries.last;

  /// Whether [entry] is still in the stack (not undone, not dropped).
  bool contains(UndoCommandEntry<T> entry) => _entries.contains(entry);

  /// The entries kept, oldest first. Read-only.
  List<UndoCommandEntry<T>> get entries => List.unmodifiable(_entries);

  /// Records a change undone by [command], and returns its entry so the
  /// caller can hand it back to [remove].
  UndoCommandEntry<T> push(T command, {required String label}) {
    final entry = UndoCommandEntry<T>(command, label: label);
    _entries.add(entry);
    if (_entries.length > limit) _entries.removeAt(0);
    notifyListeners();
    return entry;
  }

  /// Takes the most recent entry off the stack. Returns null when empty.
  UndoCommandEntry<T>? popLatest() {
    if (_entries.isEmpty) return null;
    final entry = _entries.removeLast();
    notifyListeners();
    return entry;
  }

  /// Takes [entry] off the stack, wherever it is. Returns whether it was
  /// there (an entry already undone or dropped is not).
  bool remove(UndoCommandEntry<T> entry) {
    final removed = _entries.remove(entry);
    if (removed) notifyListeners();
    return removed;
  }

  /// Forgets every entry (the document was reloaded or replaced).
  void clear() {
    if (_entries.isEmpty) return;
    _entries.clear();
    notifyListeners();
  }
}
