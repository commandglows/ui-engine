import 'dart:async';

import 'package:flutter/foundation.dart';

/// Steps shown while an account's data first reaches a device.
enum SyncStage {
  /// Waiting for the account copy.
  waitingServer,

  /// The account copy arrived.
  dataReceived,

  /// The account copy is in place in the app.
  dataApplied,

  /// Done: a short success notice, then the progress hides.
  ready,
}

/// Drives the first-sync progress of a sign-in: each step stays on screen at
/// least [minStageDuration] so the user can read it, and the final notice
/// hides by itself after [readyDuration].
class SyncProgress extends ChangeNotifier {
  SyncProgress({
    this.minStageDuration = const Duration(seconds: 1),
    this.readyDuration = const Duration(seconds: 3),
  });

  final Duration minStageDuration;
  final Duration readyDuration;

  SyncStage? _stage;
  DateTime _stageStartedAt = DateTime.fromMillisecondsSinceEpoch(0);
  Timer? _hideTimer;
  int _run = 0;
  bool _disposed = false;

  /// Steps run one after the other, each after the previous one's minimum.
  Future<void> _queue = Future.value();

  /// The step shown, or `null` when hidden.
  SyncStage? get stage => _stage;

  bool get isVisible => _stage != null;

  /// Whether the app beneath must wait (every step but [SyncStage.ready]).
  bool get isBlocking => _stage != null && _stage != SyncStage.ready;

  /// Shows the first step; does nothing while a run is shown.
  void begin() {
    if (isBlocking) return;
    _run++;
    _set(SyncStage.waitingServer);
  }

  /// Moves to [stage] once the current step was shown long enough. Calls
  /// queue up, so `advance(a); advance(b);` shows both steps.
  Future<void> advance(SyncStage stage) {
    assert(stage != SyncStage.ready, 'Call finish() for the last step.');
    return _enqueue(stage);
  }

  /// Shows the success notice, then hides.
  Future<void> finish() => _enqueue(SyncStage.ready);

  Future<void> _enqueue(SyncStage stage) {
    final run = _run;
    return _queue = _queue.then((_) async {
      if (run != _run || !isBlocking || _stage == stage) return;
      await _waitMinimum();
      if (run != _run || !isBlocking) return;
      _set(stage);
      if (stage == SyncStage.ready) _hideTimer = Timer(readyDuration, reset);
    });
  }

  /// Hides at once (failure, review, sign-out).
  void reset() {
    _run++;
    _hideTimer?.cancel();
    _hideTimer = null;
    if (_stage == null) return;
    _stage = null;
    if (!_disposed) notifyListeners();
  }

  Future<void> _waitMinimum() async {
    final left = minStageDuration - DateTime.now().difference(_stageStartedAt);
    if (left > Duration.zero) await Future<void>.delayed(left);
  }

  void _set(SyncStage stage) {
    _hideTimer?.cancel();
    _stage = stage;
    _stageStartedAt = DateTime.now();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _hideTimer?.cancel();
    super.dispose();
  }
}
