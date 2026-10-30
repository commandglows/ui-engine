import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_routines/shipglows_routines.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('an unforced trigger inside minGap is skipped, then runs again', () async {
    var now = DateTime(2026, 10, 30, 9);
    var runs = 0;
    final scheduler = RoutineScheduler(
      store: MemoryRoutineStore(),
      clock: () => now,
      observeAppLifecycle: false,
    );
    scheduler.register(
      Routine(
        id: 'triage',
        minGap: const Duration(minutes: 10),
        runOnStart: false,
        run: (_) async {
          runs++;
        },
      ),
    );

    expect(await scheduler.trigger('triage'), RoutineRunOutcome.ran);
    now = now.add(const Duration(minutes: 5));
    expect(await scheduler.trigger('triage'), RoutineRunOutcome.skippedTooSoon);
    now = now.add(const Duration(minutes: 5));
    expect(await scheduler.trigger('triage'), RoutineRunOutcome.ran);
    expect(runs, 2);

    scheduler.dispose();
  });

  test('a trigger during a run joins it and never starts a second run', () async {
    final gate = Completer<void>();
    var runs = 0;
    final scheduler = RoutineScheduler(
      store: MemoryRoutineStore(),
      clock: () => DateTime(2026, 10, 30, 9),
      observeAppLifecycle: false,
    );
    scheduler.register(
      Routine(
        id: 'sync',
        runOnStart: false,
        run: (_) async {
          runs++;
          await gate.future;
        },
      ),
    );

    final first = scheduler.trigger('sync');
    final second = scheduler.trigger('sync', trigger: RoutineTrigger.focus);
    gate.complete();

    expect(await first, RoutineRunOutcome.ran);
    expect(await second, RoutineRunOutcome.joinedRunning);
    expect(runs, 1);

    scheduler.dispose();
  });

  test('a failing run returns failed, keeps the error and records the attempt', () async {
    final now = DateTime(2026, 10, 30, 9);
    final store = MemoryRoutineStore();
    final scheduler = RoutineScheduler(
      store: store,
      clock: () => now,
      observeAppLifecycle: false,
    );
    scheduler.register(
      Routine(
        id: 'sync',
        runOnStart: false,
        run: (_) async => throw StateError('offline'),
      ),
    );

    expect(await scheduler.trigger('sync'), RoutineRunOutcome.failed);
    final status = scheduler.status('sync').value;
    expect(status.running, isFalse);
    expect(status.lastError, isA<StateError>());
    expect(await store.lastRun('sync'), now);

    scheduler.dispose();
  });

  test('an unknown id answers unknownRoutine and status throws ArgumentError', () async {
    final scheduler = RoutineScheduler(observeAppLifecycle: false);

    expect(await scheduler.trigger('missing'), RoutineRunOutcome.unknownRoutine);
    expect(() => scheduler.status('missing'), throwsArgumentError);

    scheduler.dispose();
  });
}
