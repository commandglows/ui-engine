/// Why a [Routine] runs. Passed to [Routine.run] and kept in
/// [RoutineStatus.lastTrigger].
enum RoutineTrigger {
  /// The routine was registered and [Routine.runOnStart] is set.
  start,

  /// The app came back to the foreground and [Routine.runOnResume] is set.
  resume,

  /// The routine's [Routine.interval] timer fired.
  interval,

  /// The page that uses the routine was shown.
  focus,

  /// An explicit [RoutineScheduler.trigger] call with no reason of its own.
  manual,
}

/// A named unit of background work the app runs next to its screens.
///
/// [run] does the work and completes when it is done. The scheduler awaits
/// it, never starts the same routine twice at once, and turns an error into
/// [RoutineRunOutcome.failed]. Keep [run] safe to repeat: it runs again at
/// the next trigger.
///
/// [interval] null means no timer. [minGap] is the least time between the end
/// of one run and the start of the next (a forced trigger skips it); it must
/// not be negative. [runOnStart] and [runOnResume] say whether the scheduler
/// triggers the routine when it is registered and when the app resumes.
final class Routine {
  const Routine({
    required this.id,
    required this.run,
    this.interval,
    this.minGap = Duration.zero,
    this.runOnStart = true,
    this.runOnResume = true,
  }) : assert(id != '', 'A routine needs a non-empty id.');

  /// Stable key: one routine per id, and the key of its stored last run.
  final String id;

  /// The work. Receives the reason it was triggered.
  final Future<void> Function(RoutineTrigger trigger) run;

  /// Period of the timer that triggers the routine with
  /// [RoutineTrigger.interval]; `null` for no timer. Must be positive.
  final Duration? interval;

  /// Least time between two runs that start, measured from the last recorded
  /// run (failed attempts included).
  final Duration minGap;

  /// Whether registering the routine triggers it once with
  /// [RoutineTrigger.start].
  final bool runOnStart;

  /// Whether an app resume triggers the routine with
  /// [RoutineTrigger.resume].
  final bool runOnResume;
}

/// What a [RoutineScheduler.trigger] call ended with. A call never throws.
enum RoutineRunOutcome {
  /// [Routine.run] ran and completed.
  ran,

  /// Not run: the last recorded run is less than [Routine.minGap] ago. Only
  /// an unforced trigger is skipped this way.
  skippedTooSoon,

  /// Not run on its own: the call waited for the run already in progress and
  /// ends when that run ends.
  joinedRunning,

  /// [Routine.run] threw. The error is in [RoutineStatus.lastError] and the
  /// attempt counts as the last run.
  failed,

  /// No routine is registered under the id, or the scheduler is disposed.
  unknownRoutine,
}

/// What a routine last did, for widgets to show. Immutable, with value
/// equality.
final class RoutineStatus {
  const RoutineStatus({
    this.lastRun,
    this.running = false,
    this.lastError,
    this.lastTrigger,
  });

  /// When the last run ended in this session (a failed attempt counts), or
  /// `null` until one did. The minimum gap is checked against the store,
  /// which survives restarts, not against this value.
  final DateTime? lastRun;

  /// Whether a run is in progress.
  final bool running;

  /// The error of the last run that failed. Cleared by the next run that
  /// completes.
  final Object? lastError;

  /// The reason of the last run that started.
  final RoutineTrigger? lastTrigger;

  @override
  bool operator ==(Object other) =>
      other is RoutineStatus &&
      other.lastRun == lastRun &&
      other.running == running &&
      other.lastError == lastError &&
      other.lastTrigger == lastTrigger;

  @override
  int get hashCode => Object.hash(lastRun, running, lastError, lastTrigger);

  @override
  String toString() =>
      'RoutineStatus(lastRun: $lastRun, running: $running, '
      'lastError: $lastError, lastTrigger: $lastTrigger)';
}
