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
