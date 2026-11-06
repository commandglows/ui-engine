# shipglows_command_bar_window

The shared command bar (`CommandBarView`) in its own floating window, on
`shipglows_overlay_window`: own engine, always on top, opened in the upper
part of the cursor's monitor, drag to move, edges to resize (native, no
flicker), position and size remembered, focus back to the previous window
on close. Escape and a click outside close it.

- App engine: `ShipglowsCommandBarWindow` publishes a
  `ShipglowsCommandBarSnapshot` (entries as `CommandBarEntry`, recent ids,
  brightness, locale), opens, closes or toggles the bar and updates it in
  place while open. `selections` reports each choice (`id`, `secondary`,
  `previousForeground` HWND, `query` for an entry that `usesQuery`, `action`
  for an action of its panel); the bar is already hidden and the app runs
  the effect itself.
- `data`: the app's own JSON-safe values for its bar (a color theme the
  bar's engine cannot read from storage), read back from
  `ShipglowsCommandBarOverlayController.snapshot`.
- `appWindowIds`: entries that open a screen of the app; choosing one brings
  the main window forward instead of the previous window.
  `appWindowActions` does the same for panel action ids (`open-in-app`).
- Bar engine: `runShipglowsCommandBarOverlay` from the app's
  `@pragma('vm:entry-point')` function, with its sections, filters, texts
  (per locale), themes and icon table (code point → constant `IconData`, so
  icon fonts stay tree-shaken). `initialEntries` fills the bar before the
  first snapshot. `ShipglowsCommandBarOverlayController` and
  `ShipglowsCommandBarOverlayApp` for an app that calls `runApp` itself.
- The bar fills the window's height (`fillHeight`), maximized included.
- Drag anywhere to move the window, the search field included; double-click
  on the search field or an empty area maximizes or restores it (`defaultOptions(doubleClickMaximizes:)`,
  on by default).
- The frame (dark mode, border, background) follows the bar's theme
  (`CommandBarThemeData`).
- App surface: `surfaceBuilder` (on `runShipglowsCommandBarOverlay` and
  `ShipglowsCommandBarOverlayApp`) wraps the bar in the app's own surface,
  such as a card outline with a margin and a hard shadow. With
  `defaultOptions(transparent: true)` the window has no background, corners
  or shadow of its own, so only that surface shows over the desktop; keep a
  margin in the surface for the shadow and as a drag handle.
  `ShipglowsCommandBarWindowState.maximizedOf(context)` lets the surface drop
  that margin while the window is maximized.
- Window options: `ShipglowsCommandBarWindow.defaultOptions(appFolder: …)`.
- In-app bar replaced: `CommandBarScope(opener: bar.scopeOpener, …)`, so
  Ctrl/⌘+K and the app's `open()` calls show only the floating bar.
- Global hotkey: `bar.bindHotkey(hotkeys, 'commandBar')` with
  `shipglows_hotkeys`. A press closes the open bar, otherwise opens it over
  the window in front, the app's own window included: the in-app bar is
  only the fallback off Windows or before the floating bar is ready.

```yaml
dependencies:
  shipglows_command_bar_window:
    path: ../../shipglows-app-engine/flutter/desktop/shipglows_command_bar_window
```

```dart
// App engine
final bar = ShipglowsCommandBarWindow(
  entrypoint: 'commandBarMain',
  options: ShipglowsCommandBarWindow.defaultOptions(appFolder: 'MyApp'),
);
bar.selections.listen((selection) {
  runCommand(selection.id, secondary: selection.secondary);
});
await bar.publish(ShipglowsCommandBarSnapshot(
  entries: [for (final command in commands) command.entry],
  recentIds: recents,
  brightness: Brightness.dark,
  locale: const Locale('fr'),
  appWindowIds: {'screen:/settings'},
));
unawaited(bar.prepare()); // optional, first opening instant
bar.bindHotkey(hotkeys, 'commandBar'); // see shipglows_hotkeys

// Bar engine (same Dart program, own entry point)
@pragma('vm:entry-point')
void commandBarMain() => runShipglowsCommandBarOverlay(
  sections: (locale) => [
    CommandBarSection(id: 'screens', title: tr(locale, 'Screens')),
  ],
  filters: (locale) => myFilters(locale),
  strings: (locale) =>
      locale.languageCode == 'fr' ? CommandBarStrings.fr : CommandBarStrings.en,
  theme: lightTheme,
  darkTheme: darkTheme,
  iconFor: (codePoint) => myIcons[codePoint],
  supportedLocales: const [Locale('en'), Locale('fr')],
);
```

Card surface on a transparent window (as CommandGlows does):

```dart
// App engine
final bar = ShipglowsCommandBarWindow(
  entrypoint: 'commandBarMain',
  options: ShipglowsCommandBarWindow.defaultOptions(
    appFolder: 'MyApp',
    transparent: true,
  ),
);

// Bar engine
@pragma('vm:entry-point')
void commandBarMain() => runShipglowsCommandBarOverlay(
  sections: (locale) => mySections(locale),
  surfaceBuilder: (context, bar) => Padding(
    // Room for the hard shadow; the margin also moves the window.
    padding: const EdgeInsets.fromLTRB(4, 4, 12, 12),
    child: DecoratedBox(
      decoration: myCardDecoration(context), // outline + offset shadow
      child: ClipRRect(borderRadius: BorderRadius.circular(24), child: bar),
    ),
  ),
);
```

The bar's engine registers no plugin and needs none. Icons travel as code
points: `iconFor` must know every icon the app's entries use.
