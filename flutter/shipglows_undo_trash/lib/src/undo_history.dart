import 'package:flutter/foundation.dart';

/// One recorded step: the state an undo (or redo) goes back to.
@immutable
class UndoStep<T> {
  const UndoStep(this.state, {this.label});

  final T state;

  /// What the step did (« Cut sentence »), for an « Undo: … » tooltip.
  final String? label;
}

/// Undo/redo stacks of snapshots for an editor (timeline, canvas, form).
///
/// The caller records the state as it was *before* each change; [undo] and
/// [redo] take the current state and hand back the step to restore. Both
/// stacks keep at most [limit] steps, dropping the oldest. Snapshots must be
/// immutable (or copied by the caller): the history stores them as given.
class UndoHistory<T> extends ChangeNotifier {
  UndoHistory({this.limit = 50}) : assert(limit > 0);

  /// Maximum number of steps kept on each stack.
  final int limit;

  final List<UndoStep<T>> _undo = [];
  final List<UndoStep<T>> _redo = [];
  bool _grouping = false;

  bool get canUndo => _undo.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;
  int get undoCount => _undo.length;
  int get redoCount => _redo.length;

  /// Label of the step [undo] would revert, if it has one.
  String? get undoLabel => _undo.isEmpty ? null : _undo.last.label;

  /// Label of the step [redo] would replay, if it has one.
  String? get redoLabel => _redo.isEmpty ? null : _redo.last.label;

  /// Whether a [group] is running, so [record] calls are folded into it.
  bool get isGrouping => _grouping;

  /// Records [before] as the state an undo goes back to, and clears redo:
  /// a new change forks the timeline. Ignored inside a [group].
  void record(T before, {String? label}) {
    if (_grouping) return;
    _push(_undo, UndoStep<T>(before, label: label));
    _redo.clear();
    notifyListeners();
  }

  /// Runs [change] as one undo step, however many [record] calls it makes,
  /// restoring [before]. [changed] tells whether anything moved, so a no-op
  /// batch records nothing. Inside another group, [change] simply joins it.
  ///
  /// Returns whether a step was recorded.
  bool group(
    T before,
    void Function() change, {
    String? label,
    bool Function()? changed,
  }) {
    if (_grouping) {
      change();
      return false;
    }
    _grouping = true;
    try {
      change();
    } finally {
      _grouping = false;
    }
    if (changed != null && !changed()) return false;
    record(before, label: label);
    return true;
  }

  /// Pops the last step and keeps [current] for [redo]. Returns the step to
  /// restore, or null when there is nothing to undo.
  UndoStep<T>? undo(T current) {
    if (_undo.isEmpty) return null;
    final step = _undo.removeLast();
    _push(_redo, UndoStep<T>(current, label: step.label));
    notifyListeners();
    return step;
  }

  /// Replays the last undone step and keeps [current] for [undo]. Returns
  /// the step to restore, or null when there is nothing to redo.
  UndoStep<T>? redo(T current) {
    if (_redo.isEmpty) return null;
    final step = _redo.removeLast();
    _push(_undo, UndoStep<T>(current, label: step.label));
    notifyListeners();
    return step;
  }

  /// Pops the last step without keeping anything for redo, for an undo-only
  /// history.
  UndoStep<T>? pop() {
    if (_undo.isEmpty) return null;
    final step = _undo.removeLast();
    notifyListeners();
    return step;
  }

  /// Forgets every step (a reload, a discard, a save that resets the draft).
  void clear() {
    if (_undo.isEmpty && _redo.isEmpty) return;
    _undo.clear();
    _redo.clear();
    notifyListeners();
  }

  void _push(List<UndoStep<T>> stack, UndoStep<T> step) {
    stack.add(step);
    if (stack.length > limit) stack.removeAt(0);
  }
}
