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
class UndoRedoHistory<T> extends ChangeNotifier {
  UndoRedoHistory({
    this.limit = 50,
    this.coalesceWindow = Duration.zero,
    Duration Function()? clock,
  }) : assert(limit > 0),
       _clock = clock ?? _stopwatchClock();

  /// Maximum number of steps kept on each stack.
  final int limit;

  /// Consecutive [record] calls inside this window form one undo step.
  ///
  /// The default keeps every recorded change as its own step.
  final Duration coalesceWindow;

  final Duration Function() _clock;

  final List<UndoStep<T>> _undo = [];
  final List<UndoStep<T>> _redo = [];
  bool _grouping = false;
  Duration? _lastRecord;

  static Duration Function() _stopwatchClock() {
    final watch = Stopwatch()..start();
    return () => watch.elapsed;
  }

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
  /// a new change forks the timeline. Nearby changes can share one step when
  /// [coalesceWindow] is positive. Ignored inside a [group].
  void record(T before, {String? label}) {
    if (_grouping) return;
    _record(before, label: label);
  }

  void _record(T before, {String? label, bool coalesce = true}) {
    final now = _clock();
    final last = _lastRecord;
    _lastRecord = now;
    final hadRedo = _redo.isNotEmpty;
    _redo.clear();
    if (coalesce &&
        coalesceWindow > Duration.zero &&
        last != null &&
        now - last < coalesceWindow &&
        _undo.isNotEmpty) {
      if (hadRedo) notifyListeners();
      return;
    }
    _push(_undo, UndoStep<T>(before, label: label));
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
    _record(before, label: label, coalesce: false);
    return true;
  }

  /// Pops the last step and keeps [current] for [redo]. Returns the step to
  /// restore, or null when there is nothing to undo.
  UndoStep<T>? undo(T current) {
    if (_undo.isEmpty) return null;
    final step = _undo.removeLast();
    _push(_redo, UndoStep<T>(current, label: step.label));
    _lastRecord = null;
    notifyListeners();
    return step;
  }

  /// Replays the last undone step and keeps [current] for [undo]. Returns
  /// the step to restore, or null when there is nothing to redo.
  UndoStep<T>? redo(T current) {
    if (_redo.isEmpty) return null;
    final step = _redo.removeLast();
    _push(_undo, UndoStep<T>(current, label: step.label));
    _lastRecord = null;
    notifyListeners();
    return step;
  }

  /// Pops the last step without keeping anything for redo, for an undo-only
  /// history.
  UndoStep<T>? pop() {
    if (_undo.isEmpty) return null;
    final step = _undo.removeLast();
    _lastRecord = null;
    notifyListeners();
    return step;
  }

  /// Forgets every step (a reload, a discard, a save that resets the draft).
  void clear() {
    if (_undo.isEmpty && _redo.isEmpty) return;
    _undo.clear();
    _redo.clear();
    _lastRecord = null;
    notifyListeners();
  }

  void _push(List<UndoStep<T>> stack, UndoStep<T> step) {
    stack.add(step);
    if (stack.length > limit) stack.removeAt(0);
  }
}
