/// Named in-app routines for ShipGlows Flutter apps: run at start, on resume,
/// on an interval or on demand, with a minimum gap, one run at a time and a
/// persisted last run.
///
/// - [Routine] / [RoutineTrigger]: what runs, and why it runs.
/// - [RoutineScheduler]: registers routines, starts their timers and reports
///   each one through [RoutineStatus] ([RoutineScheduler.status]); a run ends
///   with a [RoutineRunOutcome].
/// - [RoutineStore], [MemoryRoutineStore], [CallbackRoutineStore]: where the
///   last run of each routine is kept.
library;

export 'src/routine.dart';
export 'src/routine_scheduler.dart';
export 'src/routine_store.dart';
