# shipglows_floating_launcher

A persistent floating launcher, next to the command bar: a round bubble with
the app's logo, always on top, whose actions fan out on hover. Built on
`shipglows_overlay_window` (own engine, transparent window, `activateOnClick:
false`, `clampRect`, window shape).

- Folded: one bubble (logo on the theme's raised surface, a thin ring, a soft
  shadow). The window is larger than the bubble but shaped to it, so clicks
  around the bubble reach the windows below.
- Hover: the actions (round buttons, one icon each) fan out on an arc toward
  the free side of the screen (bubble near the right edge: the arc opens
  left; near a corner: toward the screen), the bubble never moves. Hovering
  an action fills it with the accent and shows a tooltip card (bold label,
  shortcut line). Leaving the zone folds the fan after a short delay,
  animated; reduce-motion makes it instant.
- Click an action: the fan folds and the app receives its id
  (`selections`). Click the bubble: `bubbleTaps`, for the app's primary
  action. Disabled actions are dimmed and keep their tooltip.
- Right-click the bubble: a small menu beside it, closed by leaving it, a
  click on the bubble or a second right-click. Its opacity slider (20 to
  100 %, `opacityLabel`) fades the bubble at rest, live, and is kept across
  launches with its place; hovering the bubble brings it back to full. Its
  hide row (`hideLabel`) reports to `hideRequests`: the app saves the choice,
  calls `hide()` and keeps a way back (a tray entry, a setting). A snapshot
  with neither label has no menu.
- Drag the bubble to move it; only the bubble is kept inside the work area
  (`margin` from the edges), also after a display or taskbar change. Its
  place is remembered (across launches with `appFolder`). The first opening
  docks it against the right edge of the cursor's monitor.
- Never activated: hovering, clicking or dragging it leaves the keyboard in
  the window in front. No taskbar button, no Alt+Tab entry, invisible in
  screenshots and recordings (`excludeFromCapture`, on by default).
- Colors from `ShipglowsTheme` (surface raised, icon, border, accent, on
  accent, text, text muted), light or dark from the snapshot (the system's,
  followed live, when it gives none); sizes from
  `ShipglowsScale`. Each action carries its label (and shortcut as hint) for
  screen readers.
- App engine: `ShipglowsFloatingLauncher` publishes a
  `ShipglowsFloatingLauncherSnapshot` (`items` as
  `ShipglowsFloatingLauncherItem`: id, label, icon, shortcut text, enabled;
  `bubbleLabel`, `hideLabel`, `opacityLabel`, `brightness`, `data`), shows and hides the launcher and
  updates it in place while shown or still appearing. `appFolder` (on the
  constructor or `defaultOptions`) keeps the bubble's place across launches.
- Launcher engine: `runShipglowsFloatingLauncherOverlay` from the app's
  `@pragma('vm:entry-point')` function, with the `logo` widget, the icon
  table (code point → constant `IconData`), an optional `ringGradient` and
  the themes. `ShipglowsFloatingLauncherOverlayController` and
  `ShipglowsFloatingLauncherOverlayApp` for an app that calls `runApp`
  itself.
- Sizes: `ShipglowsFloatingLauncherGeometry` (bubble, actions, arc radius
  and angles, tooltip room). The app engine sizes the window from it and
  sends it with each snapshot; about a dozen actions fit with the defaults.

```yaml
dependencies:
  shipglows_floating_launcher:
    path: ../../shipglows-app-engine/flutter/desktop/shipglows_floating_launcher
```

```dart
// App engine
final launcher = ShipglowsFloatingLauncher(
  entrypoint: 'launcherMain',
  appFolder: 'MyApp',
);
launcher.selections.listen(runCommand); // item id
launcher.bubbleTaps.listen((_) => showMainWindow());
launcher.hideRequests.listen((_) => saveBubbleSetting(false)); // then hide()
await launcher.publish(ShipglowsFloatingLauncherSnapshot(
  items: [
    ShipglowsFloatingLauncherItem(
      id: 'capture.region',
      label: 'Capture a region',
      icon: Icons.crop,
      shortcut: 'Ctrl+Shift+R',
    ),
  ],
  bubbleLabel: 'MyApp',
  hideLabel: 'Hide the bubble',
  opacityLabel: 'Opacity',
  brightness: Brightness.dark,
));
await launcher.show();

// Launcher engine (same Dart program, own entry point)
@pragma('vm:entry-point')
void launcherMain() => runShipglowsFloatingLauncherOverlay(
  logo: Image.asset('assets/logo.png'),
  iconFor: (codePoint) => myIcons[codePoint],
  ringGradient: const SweepGradient(colors: [orange, green, orange]),
  theme: lightTheme,
  darkTheme: darkTheme,
);
```

The launcher's engine registers no plugin unless the logo needs one. A custom
geometry goes to `ShipglowsFloatingLauncher(geometry:)`, and to
`defaultOptions(geometry:)` when custom options are passed (asserted).
