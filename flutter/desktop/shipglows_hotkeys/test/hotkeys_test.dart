import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_hotkeys/shipglows_hotkeys.dart';

// The test host is not Windows: nothing reaches the native side, so these
// cover the state the settings screen reads (switch, suspension, settings,
// outcomes), not the registration itself.
void main() {
  late ShipglowsHotkeyMemoryStore store;
  late ShipglowsHotkeys hotkeys;

  setUp(() {
    store = ShipglowsHotkeyMemoryStore();
    hotkeys = ShipglowsHotkeys(store: store);
    addTearDown(hotkeys.dispose);
  });

  test('the master switch is saved and published', () async {
    expect(hotkeys.state.value.enabled, isTrue);
    expect(await hotkeys.setEnabled(false), isTrue);
    expect(hotkeys.state.value.enabled, isFalse);
    expect(hotkeys.state.value.isLive, isFalse);
    expect((await store.loadSettings()).enabled, isFalse);
    expect(await hotkeys.setEnabled(true), isTrue);
    expect(hotkeys.state.value.isLive, isTrue);
  });

  test('updateSettings saves the lists the user edits', () async {
    await hotkeys.updateSettings(
      (settings) => settings
          .copyWith(excludedProcesses: {'Game.exe'})
          .withFilter('close', const ShipglowsBindingFilter(only: {'a.exe'})),
    );
    final saved = await store.loadSettings();
    expect(saved.excludedProcesses, {'game.exe'});
    expect(saved.filterOf('close').only, {'a.exe'});
    expect(hotkeys.settings, saved);
  });

  test('suspensions are counted', () async {
    await hotkeys.suspend();
    await hotkeys.suspend();
    expect(hotkeys.state.value.suspended, isTrue);
    await hotkeys.resume();
    expect(hotkeys.state.value.suspended, isTrue);
    await hotkeys.resume();
    expect(hotkeys.state.value.suspended, isFalse);
  });

  test('resume without suspend does nothing', () async {
    await hotkeys.resume();
    expect(hotkeys.state.value.suspended, isFalse);
  });

  test('whileSuspended resumes even when the body throws', () async {
    await expectLater(
      hotkeys.whileSuspended<void>(() async {
        expect(hotkeys.state.value.suspended, isTrue);
        throw StateError('boom');
      }),
      throwsStateError,
    );
    expect(hotkeys.state.value.suspended, isFalse);
  });

  test('actions report the outcome strings of ShipglowsOutcome', () {
    const denied = ShipglowsActionEvent(
      id: 'close',
      action: ShipglowsWindowAction.close,
      outcome: ShipglowsOutcome.accessDenied,
    );
    expect(denied.accessDenied, isTrue);
    expect(denied.succeeded, isFalse);
    const topmost = ShipglowsActionEvent(
      id: 'top',
      action: ShipglowsWindowAction.toggleAlwaysOnTop,
      outcome: ShipglowsOutcome.topmostOn,
    );
    expect(topmost.succeeded, isTrue);
  });

  test('without Windows, run and diagnostics are inert', () async {
    expect(
      await hotkeys.run(ShipglowsWindowAction.minimize),
      ShipglowsOutcome.failed,
    );
    expect(await hotkeys.inspectPointer(), isNull);
  });

  test('pointer info reads what the native side sends', () {
    final info = ShipglowsPointerInfo.fromJson({
      'x': 10,
      'y': 20,
      'window': 4242,
      'process': 'code.exe',
      'zones': ['anywhere', 'titleBar', 'nonsense'],
    });
    expect(info, isNotNull);
    expect(info!.process, 'code.exe');
    expect(info.zones, {ShipglowsZone.anywhere, ShipglowsZone.titleBar});
    expect(ShipglowsPointerInfo.fromJson({'x': 'a'}), isNull);
  });
}
