import 'dart:async';

import 'package:flutter/foundation.dart';

/// How a [PendingUndo] ended.
enum PendingUndoOutcome { undone, committed }

/// A reversible action whose « Undo » window is open.
///
/// The action shows its effect at once (an item hidden, a card swiped); the
/// lasting part ([onCommit]: a server call, a publish) waits for the window
/// to close. It settles exactly once: [undo] or [commit], whichever comes
/// first, so a late toast timeout never commits an undone action.
class PendingUndo {
  PendingUndo({this.onUndo, this.onCommit, this.onError});

  /// Reverts the visible effect.
  final VoidCallback? onUndo;

  /// Makes the action lasting. Its errors go to [onError].
  final FutureOr<void> Function()? onCommit;

  /// Receives a failed [onCommit]; without it the error is reported to
  /// [FlutterError.onError].
  final void Function(Object error, StackTrace stackTrace)? onError;

  final Completer<PendingUndoOutcome> _settled = Completer();
  PendingUndoOutcome? _outcome;

  /// Whether neither [undo] nor [commit] has run yet.
  bool get isOpen => _outcome == null;

  /// How it ended, or null while open.
  PendingUndoOutcome? get outcome => _outcome;

  /// Completes when the action is undone or committed.
  Future<PendingUndoOutcome> get settled => _settled.future;

  /// Reverts the action if its window is still open. Returns whether it did.
  bool undo() {
    if (!isOpen) return false;
    _settle(PendingUndoOutcome.undone);
    onUndo?.call();
    return true;
  }

  /// Makes the action lasting if it is still open. Never throws: a failed
  /// [onCommit] goes to [onError].
  Future<void> commit() async {
    if (!isOpen) return;
    _settle(PendingUndoOutcome.committed);
    try {
      await onCommit?.call();
    } catch (error, stackTrace) {
      final handler = onError;
      if (handler != null) {
        handler(error, stackTrace);
      } else {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'shipglows_undo_trash',
            context: ErrorDescription('while committing an undoable action'),
          ),
        );
      }
    }
  }

  void _settle(PendingUndoOutcome outcome) {
    _outcome = outcome;
    _settled.complete(outcome);
  }
}

/// The open « Undo » windows of a screen, keyed by item.
///
/// A screen hides the items [isHidden] reports, undoes the latest with
/// Ctrl/⌘+Z through [undoLast], and lets a toast commit each one when it
/// closes ([attachUndoSnackBar]). Commits still run after the screen is gone:
/// disposing the window only stops its notifications.
class UndoWindow<K> extends ChangeNotifier {
  final Map<K, PendingUndo> _open = {};
  final Set<K> _committed = {};
  bool _disposed = false;

  /// Whether [key] should stay out of sight: its window is open, or it was
  /// committed with `keepHiddenAfterCommit` and not yet [release]d.
  bool isHidden(K key) => _open.containsKey(key) || _committed.contains(key);

  /// Keys whose window is open, oldest first.
  Iterable<K> get openKeys => _open.keys;

  /// Whether an action can still be undone.
  bool get canUndoLast => _open.isNotEmpty;

  /// Opens a window for [key]. [onUndo] restores what the screen changed
  /// beyond hiding the item; [commit] makes it lasting.
  ///
  /// With [keepHiddenAfterCommit], the item stays hidden after a successful
  /// commit, until [release] (or a refreshed list drops it): no flicker while
  /// the list reloads. A failed commit always shows it again.
  PendingUndo start(
    K key, {
    required FutureOr<void> Function() commit,
    VoidCallback? onUndo,
    void Function(Object error, StackTrace stackTrace)? onError,
    bool keepHiddenAfterCommit = false,
  }) {
    final previous = _open[key];
    if (previous != null) unawaited(previous.commit());
    late final PendingUndo pending;
    void close() {
      if (identical(_open[key], pending)) _open.remove(key);
    }

    pending = PendingUndo(
      onUndo: () {
        close();
        _notify();
        onUndo?.call();
      },
      onCommit: () async {
        close();
        if (keepHiddenAfterCommit) _committed.add(key);
        _notify();
        try {
          await commit();
        } catch (_) {
          if (_committed.remove(key)) _notify();
          rethrow;
        }
      },
      onError: onError,
    );
    _open[key] = pending;
    _notify();
    return pending;
  }

  /// Undoes the most recent open action. Returns whether one was undone.
  bool undoLast() {
    if (_open.isEmpty) return false;
    return _open.values.last.undo();
  }

  /// Commits every open action now (the app goes to the background, the
  /// user signs out).
  Future<void> flush() => Future.wait([
    for (final pending in _open.values.toList()) pending.commit(),
  ]);

  /// Shows [key] again after a commit kept it hidden.
  void release(K key) {
    if (_committed.remove(key)) _notify();
  }

  /// Keeps hidden only the committed keys still in [present], once the list
  /// has been reloaded.
  void retainCommitted(Iterable<K> present) {
    final keep = present.toSet();
    final before = _committed.length;
    _committed.removeWhere((key) => !keep.contains(key));
    if (_committed.length != before) _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
