/// What every store shares to move a file: follow it ([TransferControl]),
/// stop it, and try again after a network hiccup ([RetryPolicy]).
library;

import 'dart:async';
import 'dart:math';

import 'blob_store.dart';

/// Follows and stops one transfer: pass it to [BlobStore.putFile],
/// [BlobStore.download], [BlobStore.putBytes] or [BlobStore.getBytes].
///
/// One control per transfer: once cancelled it stays cancelled.
class TransferControl {
  TransferControl({this.onProgress});

  /// Called with the bytes moved so far and the total (-1 when unknown).
  /// Bytes kept from an earlier, interrupted attempt count as moved, and the
  /// count may step back when a part is sent again.
  final void Function(int done, int total)? onProgress;

  final _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called.
  Future<void> get whenCancelled => _cancelled.future;

  /// Stops the transfer as soon as possible: the call throws
  /// [BlobTransferCancelled]. What was already sent can be resumed when the
  /// store keeps a journal.
  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  /// Throws [BlobTransferCancelled] once [cancel] was called.
  void check() {
    if (isCancelled) throw const BlobTransferCancelled();
  }

  void report(int done, int total) => onProgress?.call(done, total);
}

/// How often and how patiently a request is sent again after a
/// [BlobTransientFailure]. Any other failure is final at once.
class RetryPolicy {
  const RetryPolicy({
    this.attempts = 4,
    this.firstDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.sleep,
  }) : assert(attempts >= 1);

  /// One attempt, no wait.
  static const none = RetryPolicy(attempts: 1);

  /// Tries in all, the first included.
  final int attempts;

  /// Wait before the second try; it doubles for each next one.
  final Duration firstDelay;

  /// Longest wait between two tries.
  final Duration maxDelay;

  /// Waits for a duration; [Future.delayed] when null. Tests pass one that
  /// returns at once.
  final Future<void> Function(Duration)? sleep;

  static final _random = Random();

  /// Wait before try number [attempt] (2 for the first retry): [firstDelay]
  /// doubled for each earlier retry, capped at [maxDelay], minus up to a
  /// quarter at random so devices that failed together do not retry
  /// together.
  Duration delayBefore(int attempt) {
    final doublings = max(0, attempt - 2);
    final micros = min(
      firstDelay.inMicroseconds * pow(2, doublings),
      maxDelay.inMicroseconds,
    ).toInt();
    return Duration(microseconds: micros - _random.nextInt(micros ~/ 4 + 1));
  }

  /// The result of [action], tried up to [attempts] times while it throws
  /// [BlobTransientFailure]. Once [control] is cancelled, a failure or a
  /// wait ends in [BlobTransferCancelled].
  Future<T> run<T>(
    Future<T> Function() action, {
    TransferControl? control,
  }) async {
    for (var attempt = 1;; attempt++) {
      control?.check();
      try {
        return await action();
      } on BlobTransientFailure {
        control?.check();
        if (attempt >= attempts) rethrow;
      }
      final wait = (sleep ?? Future<void>.delayed)(delayBefore(attempt + 1));
      await (control == null
          ? wait
          : Future.any([wait, control.whenCancelled]));
    }
  }
}
