# shipglows_routines

Named in-app routines: work the app runs at start, on resume, on an interval
or when a page asks for it. Flutter SDK only. A routine has a minimum gap
between two runs, runs one at a time (a trigger during a run waits for it),
and keeps its last run in a `RoutineStore` so the gap holds after a restart.

- `Routine(id:, run:, interval:, minGap:, runOnStart:, runOnResume:)`; `run`
  receives the `RoutineTrigger` (`start`, `resume`, `interval`, `focus`,
  `manual`).
- `RoutineScheduler(store:, clock:, observeAppLifecycle:)`: `register` (same
  id replaces), `unregister`, `trigger(id, trigger:, force:)` answers a
  `RoutineRunOutcome` (`ran`, `skippedTooSoon`, `joinedRunning`, `failed`,
  `unknownRoutine`) and never throws, `status(id)` is a
  `ValueListenable<RoutineStatus>` (`lastRun`, `running`, `lastError`,
  `lastTrigger`), `dispose`. Create it after the binding is initialized.
- `RoutineStore`: `MemoryRoutineStore` (default) or
  `CallbackRoutineStore(read:, write:)` over any device store. A store error
  is "no last run" on read and is ignored on write.

```dart
final routines = RoutineScheduler(); // after WidgetsFlutterBinding.ensureInitialized()

routines.register(
  Routine(
    id: 'email-auto-triage',
    interval: const Duration(hours: 1),
    minGap: const Duration(minutes: 10),
    run: (trigger) => triage.runOnce(),
  ),
);

// When a page is shown:
unawaited(routines.trigger('email-auto-triage', trigger: RoutineTrigger.focus));
```

```yaml
dependencies:
  shipglows_routines:
    path: ../../shipglows-app-engine/flutter/services/shipglows_routines
```
