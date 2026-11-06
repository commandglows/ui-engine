# shipglows_hotkeys

System-wide **triggers** for ShipGlows desktop Flutter apps (Windows; no-op
elsewhere). The app declares *actions*; the user chooses what starts each one.

| Trigger | Class | Caught with |
| --- | --- | --- |
| Key combination (`Ctrl+Alt+Space`) | `ShipglowsKeyTrigger` | `RegisterHotKey` |
| Key pressed twice (`Esc ×2`) | `ShipglowsDoubleKeyTrigger` | keyboard hook (never swallows the key) |
| Mouse gesture, alone or with modifier keys (`Ctrl+wheel up`, `middle click on a title bar`) | `ShipglowsMouseTrigger` | mouse hook, installed only while one is active |

Mouse gestures: `click`, `hold` (press kept still), `drag` (press moved at
least N px), `wheelUp`, `wheelDown`, `touch` (pointer rests in a screen
corner). Zones: anywhere (needs a modifier), title bar, taskbar, minimize /
maximize / close button, four screen corners.

One trigger per action. A combination another app owns is reported
(`alreadyRegistered`), never swapped. The user's choices are saved in
`%APPDATA%\<appFolder>\hotkeys.json` (a file from 0.1 is read as is).
Unassigned = off.

```dart
final triggers = ShipglowsHotkeys(appFolder: 'MyApp');
await triggers.apply([
  const ShipglowsHotkeyBinding(
    id: 'minimize',
    action: ShipglowsWindowAction.minimize,        // the package runs it
    trigger: ShipglowsMouseTrigger.wheelDown(zone: ShipglowsZone.titleBar),
  ),
  const ShipglowsHotkeyBinding(
    id: 'closeForeground',
    action: ShipglowsWindowAction.close,
    trigger: ShipglowsDoubleKeyTrigger(ShipglowsKey.escape),
    excludeProcesses: {'code.exe'},                // passes through there
  ),
  const ShipglowsHotkeyBinding(id: 'openBar'),     // off until the user picks
]);

triggers.events.listen((e) => print('${e.id} on window ${e.window}'));
await triggers.setTrigger('openBar', ShipglowsTrigger.key(
  ShipglowsHotkey(ShipglowsKey.space, control: true, alt: true)));
```

`ShipglowsTrigger.label(ShipglowsTriggerLabels.fr)` gives the text to show
(`Molette vers le bas sur la barre de titre`); `isValid` and the
`ShipglowsHotkeyConflict` of a refused change tell the settings screen what to
say (`ShipglowsHotkeyConflictTexts`).

## Rules the package enforces

- A plain left click is never a trigger, and a gesture "anywhere" needs a
  modifier, or the trigger would hijack the mouse.
- `click` and the wheel are swallowed; `hold`, `drag` and `touch` let the
  mouse through, so dragging a window keeps working.
- Input sent by a program (including this one) is never a gesture.
- The desktop, the taskbar and other shell windows are never closed, hidden,
  moved or resized by an action.
- Hidden windows (`ShipglowsWindowAction.hide`) come back when the app quits.

## Actions

`ShipglowsWindowAction`: minimize, maximize, toggleMaximize, restore, close,
toggleAlwaysOnTop, hide / restoreHidden, snap* (halves, quarters), snapToPointer
(for a drag: the part of the screen the pointer ended in), restoreSize,
volumeUp / volumeDown / volumeMute. The window is the one under the pointer for
a mouse trigger, the one in front for a key trigger. `actionEvents` reports
what ran (`topmostOn` / `topmostOff`, `noWindow`…).

`ShipglowsTriggers` is an alias of `ShipglowsHotkeys`.

## Settings, rest and diagnostics (0.3)

- **Master switch and exceptions.** `setEnabled(false)` unregisters everything
  (the key combinations are free for other apps again) and is remembered.
  `updateSettings` edits the programs left alone: `excludedProcesses` (all
  bindings) and, per binding, `ShipglowsBindingFilter.excluded` /
  `only` (a white list). They add to the binding's own
  `excludeProcesses`, apply to mouse triggers and double keys, and are saved in
  `hotkeys.json` (`settings`). `state.value.customized` / `isCustomized(id)`
  tell whether the user chose a trigger; `reset(id)` / `resetAll()` bring the
  defaults back.
- **Rest while recording.** `suspend()` / `resume()` (counted) or
  `whileSuspended(body)` unregister every trigger, so a shortcut being recorded
  is not fired or swallowed by Windows. Changes made meanwhile are saved and
  take effect on `resume()`.
- **Picker.** `showShipglowsTriggerPicker(context, title:, current:, hotkeys:,
  labels: ShipglowsTriggerPickerLabels.fr)` asks for a shortcut, a key pressed
  twice or a mouse gesture (+ modifiers), and rests `hotkeys` meanwhile.
  `ShipglowsTriggerPicker` is the same without the dialog.
- **Outcomes.** `ShipglowsOutcome`: `ok`, `topmostOn/Off`, `noWindow`,
  `accessDenied` (the window belongs to an elevated program: only an app run
  as administrator can act on it), `failed`.
- **Hook watchdog.** Windows silently drops a low-level hook after a sleep, a
  session lock or a callback that took too long. The hooks are put back after
  a resume or an unlock and every 30 seconds while idle; `hookStatus()` reports
  them (`mouseHook`, `keyboardHook`, `reinstalls`, `fullscreen`).
- **Full screen.** `ShipglowsHotkeys(pauseInFullscreen: true)`: mouse triggers
  and double keys rest while a full-screen program (a game, a presentation)
  is in front. Key combinations are not concerned.
- **Why did it not fire?** `inspectPointer()` returns the window, program and
  every `ShipglowsZone` under the pointer right now.

## More

System-wide hotkeys for desktop apps (Windows; no-op elsewhere): they fire
while the app is in front, in the background or hidden in the tray. Native
Win32 (`RegisterHotKey` on a hidden message-only window), no third-party
plugin, nothing to route in the runner.

- Declared once at startup with `apply`: one action, one combination (its
  default `hotkey`, or the user's saved choice). No fallback list: when
  another app owns it, the app says so and offers to change it
  (`ShipglowsHotkeyConflictTexts.fr` : « Déjà utilisé par une autre
  application. Choisis une autre combinaison. »).
- `events`: id, `foreground` (`otherApp`, `app`, `ownWindow`, `none`) and
  `previousForeground`, the HWND in front read natively at the press, before
  any Dart code runs: the window to give the keyboard back to or paste into.
- Conflicts by id in `state` (`alreadyRegistered`, `duplicate`, `invalid`,
  `failed`); another app's hotkey is reported, never stolen nor replaced by
  another combination.
- Settings: `set(id, hotkey)` (null leaves it unassigned), `setAll` for
  several at once, all or none (two hotkeys can swap), `reset(id)` back to
  the default. Choices are saved in `%APPDATA%\<appFolder>\hotkeys.json`
  (or a custom `ShipglowsHotkeyStore`); a failed save undoes the change.
- `hookFallback: true`: a hotkey Windows refuses for another reason than an
  owner is caught with a low-level keyboard hook instead.
- `ShipglowsHotkey.label(ShipglowsHotkeyLabels.fr)` → « Ctrl+Alt+Espace ».
- **0.2 — triggers.** A binding's trigger is no longer only a key
  combination: `ShipglowsTrigger` is a key combination, a key pressed twice
  (`ShipglowsDoubleKeyTrigger`, `Esc ×2`) or a mouse gesture
  (`ShipglowsMouseTrigger`: click, hold, drag, wheel, screen corner, in a
  zone — title bar, taskbar, window buttons, corners — alone or with
  modifier keys). `set`/`setAll` keep working for keys; `setTrigger` and
  `setAllTriggers` take any trigger. Mouse gestures use a low-level mouse
  hook installed only while one is active; `click` and the wheel are
  swallowed, `hold`, `drag` and `touch` are not; injected input is ignored.
  A binding can declare a `ShipglowsWindowAction` (minimize, close, always
  on top, snap, volume…) that the package runs on the window under the
  pointer (mouse) or in front (keys); `excludeProcesses` lets a trigger pass
  through in given programs. `ShipglowsTriggers` is an alias of
  `ShipglowsHotkeys`. A 0.1 `hotkeys.json` is read as is. See the package
  README.
- 0.3: master switch and per-program lists (`setEnabled`, `updateSettings`,
  saved in `hotkeys.json`), `suspend()` / `resume()` / `whileSuspended` so a
  shortcut being recorded is not fired or swallowed, the ready-made
  `showShipglowsTriggerPicker` dialog (`ShipglowsTriggerPicker` widget),
  `ShipglowsOutcome.accessDenied` for windows of elevated programs, a hook
  watchdog (reinstall after sleep / unlock / every 30 s), `pauseInFullscreen`,
  `hookStatus()` and `inspectPointer()` for diagnostics.
- After an Alt+key hotkey pressed in the app, releasing Alt no longer opens
  the main window's menu mode (which swallowed the next key).

Default combinations, so the ShipGlows apps do not take each other's:

| App | Hotkey | Default |
|---|---|---|
| ContentGlows | command bar | Ctrl+Alt+Space |
| CommandGlows | command bar | Alt+Space |
| CommandGlows | inline overlay | Ctrl+Alt+Space today: to change |
| CommandGlows | shortcut sheet | Ctrl+Alt+K |
| ShipGlows app | command bar | Ctrl+Shift+Space |
| DreamGlows | quick capture | Shift+Alt+S |

```yaml
dependencies:
  shipglows_hotkeys:
    path: ../../shipglows-app-engine/flutter/desktop/shipglows_hotkeys
```

```dart
final hotkeys = ShipglowsHotkeys(appFolder: 'MyApp');
await hotkeys.apply([
  ShipglowsHotkeyBinding(
    id: 'commandBar',
    hotkey: ShipglowsHotkey(ShipglowsKey.space, control: true, alt: true),
  ),
  ShipglowsHotkeyBinding(
    id: 'capture',
    hotkey: ShipglowsHotkey(ShipglowsKey.f(2), control: true, shift: true),
  ),
]);
// Taken by another app: say it and offer to change it.
for (final MapEntry(key: id, value: conflict)
    in hotkeys.state.value.conflicts.entries) {
  showHotkeyProblem(id, ShipglowsHotkeyConflictTexts.fr.of(conflict));
}

bar.bindHotkey(hotkeys, 'commandBar'); // shipglows_command_bar_window
hotkeys.events
    .where((event) => event.id == 'capture')
    .listen((event) => startCapture());

// Settings screen
final result = await hotkeys.set(
  'commandBar',
  ShipglowsHotkey(ShipglowsKey.character('K'), control: true, alt: true),
);
if (!result.applied) {
  showHotkeyProblem(
    'commandBar',
    ShipglowsHotkeyConflictTexts.fr.of(result.conflicts['commandBar']!),
  );
}
```

One `ShipglowsHotkeys` per app, in the main engine. Adding the package adds a
native plugin: the app needs a full restart, not a hot reload.
