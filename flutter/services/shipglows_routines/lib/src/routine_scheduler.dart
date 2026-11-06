import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'routine.dart';
import 'routine_store.dart';

/// Runs registered [Routine]s: at start, on app resume, on their interval,
/// and when asked with [trigger].
///
/// Guarantees:
/// - one run at a time per routine: a trigger that arrives while one runs
///   waits for it and ends with [RoutineRunOutcome.joinedRunning];
/// - no run starts within [Routine.minGap] of the last recorded run, unless
///   the trigger is forced;
/// - [trigger] never throws. A store error is "no last run" on read and is
///   ignored on write. A routine error is [RoutineRunOutcome.failed] and is
///   kept in [status].
///
/// Create it after the Flutter binding is initialized: with
/// [observeAppLifecycle] the constructor reads [WidgetsBinding.instance].
/// Call [dispose] when the owner goes away.
class RoutineScheduler with WidgetsBindingObserver {
  /// [store] defaults to a [MemoryRoutineStore]; [clock] defaults to
  /// [DateTime.now]. With [observeAppLifecycle], an app resume triggers the
  /// routines with [Routine.runOnResume].
  RoutineScheduler({
    RoutineStore? store,
    DateTime Function()? clock,
    bool observeAppLifecycle = true,
  }) : _store = store ?? MemoryRoutineStore(),
       _clock = clock ?? DateTime.now,
       _observesLifecycle = observeAppLifecycle {
    if (observeAppLifecycle) WidgetsBinding.instance.addObserver(this);
  }

  final RoutineStore _store;
  final DateTime Function() _clock;
  final bool _observesLifecycle;
  final Map<String, _Entry> _entries = {};
  bool _disposed = false;

  /// Adds [routine], or replaces the routine with the same id: its timer
  /// restarts with the new [Routine.interval] and its status is kept. With
  /// [Routine.runOnStart] it is triggered once with [RoutineTrigger.start].
  ///
  /// Throws [StateError] after [dispose], and [ArgumentError] for a zero or
  /// negative interval or a negative [Routine.minGap].
  void register(Routine routine) {
    if (_disposed) throw StateError('RoutineScheduler is disposed.');
    final interval = routine.interval;
    if (interval != null && interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'must be positive');
    }
    if (routine.minGap.isNegative) {
      throw ArgumentError.value(
        routine.minGap,
        'minGap',
        'must not be negative',
      );
    }
    final id = routine.id;
    final entry = _entries.putIfAbsent(id, () => _Entry(routine));
    entry.routine = routine;
    entry.timer?.cancel();
    entry.timer = interval == null
        ? null
        : Timer.periodic(
            interval,
            (_) =>
                unawaited(trigger(id, trigger: RoutineTrigger.interval)),
          );
    if (routine.runOnStart) {
      unawaited(trigger(id, trigger: RoutineTrigger.start));
    }
  }

  /// Removes the routine [id]: its timer stops and its status notifier is
  /// disposed. A run in progress finishes, but no longer updates a status.
  /// An unknown id does nothing.
  void unregister(String id) {
    final entry = _entries.remove(id);
    if (entry != null) _close(entry);
  }

  /// Runs routine [id] unless it may not run now, and says what happened.
  /// Never throws.
  ///
  /// [trigger] is the reason, kept in [RoutineStatus.lastTrigger]. A
  /// [force]d call skips the [Routine.minGap] check; single-flight still
  /// applies. Each unforced call reads the last run from the store and
  /// returns [RoutineRunOutcome.skippedTooSoon] when it is too recent.
  /// A successful run records the time it ended; a failed one records the
  /// time it failed, so a failing routine does not run again at every trigger.
  Future<RoutineRunOutcome> trigger(
    String id, {
    RoutineTrigger trigger = RoutineTrigger.manual,
    bool force = false,
  }) async {
    final entry = _entries[id];
    if (entry == null) return RoutineRunOutcome.unknownRoutine;
    final running = entry.running;
    if (running != null) {
      await running;
      return RoutineRunOutcome.joinedRunning;
    }
    // Claimed before the first await, so a concurrent trigger joins this run.
    final done = Completer<void>();
    entry.running = done.future;
    try {
      return await _runOnce(entry, trigger, force);
    } finally {
      entry.running = null;
      done.complete();
    }
  }

  /// The live status of routine [id]. The notifier belongs to the scheduler:
  /// do not dispose it. Throws [ArgumentError] for an unknown id.
  ValueListenable<RoutineStatus> status(String id) {
    final entry = _entries[id];
    if (entry == null) {
      throw ArgumentError.value(
        id,
        'id',
        'No routine is registered under this id.',
      );
    }
    return entry.status;
  }

  /// Triggers every routine with [Routine.runOnResume] when the app comes to
  /// the foreground, with [RoutineTrigger.resume].
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // A copy: a run may register or unregister while this loop walks.
    for (final entry in _entries.values.toList()) {
      if (entry.routine.runOnResume) {
        unawaited(trigger(entry.routine.id, trigger: RoutineTrigger.resume));
      }
    }
  }

  /// Stops every timer, detaches from the app lifecycle and disposes every
  /// status notifier. Afterwards [trigger] answers
  /// [RoutineRunOutcome.unknownRoutine] and [register] throws. Idempotent.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_observesLifecycle) WidgetsBinding.instance.removeObserver(this);
    for (final entry in _entries.values) {
      _close(entry);
    }
    _entries.clear();
  }

  Future<RoutineRunOutcome> _runOnce(
    _Entry entry,
    RoutineTrigger trigger,
    bool force,
  ) async {
    final routine = entry.routine;
    final id = routine.id;
    if (!force) {
      final last = await _readLastRun(id);
      if (entry.closed) return RoutineRunOutcome.unknownRoutine;
      if (last != null && _clock().difference(last) < routine.minGap) {
        return RoutineRunOutcome.skippedTooSoon;
      }
    }
    final current = entry.status.value;
    _publish(
      entry,
      RoutineStatus(
        lastRun: current.lastRun,
        running: true,
        lastError: current.lastError,
        lastTrigger: trigger,
      ),
    );
    try {
      await routine.run(trigger);
    } catch (error) {
      final attempt = _clock();
      await _recordRun(id, attempt);
      _publish(
        entry,
        RoutineStatus(
          lastRun: attempt,
          lastError: error,
          lastTrigger: trigger,
        ),
      );
      return RoutineRunOutcome.failed;
    }
    final at = _clock();
    await _recordRun(id, at);
    _publish(
      entry,
      RoutineStatus(lastRun: at, lastTrigger: trigger),
    );
    return RoutineRunOutcome.ran;
  }

  /// A store error is "no last run": the routine may run.
  Future<DateTime?> _readLastRun(String id) async {
    try {
      return await _store.lastRun(id);
    } catch (_) {
      return null;
    }
  }

  /// A store error is ignored: the run happened and still counts for this
  /// session's status.
  Future<void> _recordRun(String id, DateTime at) async {
    try {
      await _store.recordRun(id, at);
    } catch (_) {
      // The run already happened: a store that cannot write must not fail it.
      return;
    }
  }

  void _publish(_Entry entry, RoutineStatus next) {
    if (!entry.closed) entry.status.value = next;
  }

  static void _close(_Entry entry) {
    entry.timer?.cancel();
    entry.timer = null;
    entry.closed = true;
    entry.status.dispose();
  }
}

/// One registered routine: its definition, its timer, the run in progress
/// and its status.
final class _Entry {
  _Entry(this.routine)
    : status = ValueNotifier<RoutineStatus>(const RoutineStatus());

  Routine routine;
  final ValueNotifier<RoutineStatus> status;
  Timer? timer;

  /// Completes when the run in progress ends; `null` while idle.
  Future<void>? running;

  /// Set once unregistered or disposed: the status is no longer updated.
  bool closed = false;
}
