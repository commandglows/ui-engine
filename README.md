# UI Engine

Shared interface components for ShipGlows Flutter apps. One package per
component, consumed as a path dependency:

```yaml
dependencies:
  shipglows_command_bar:
    path: ../../shipglows-ui-engine/flutter/shipglows_command_bar
```

Each package keeps its own dependencies: an app that uses only the command bar
never pulls `window_manager`.

## `flutter/shipglows_command_bar`

Ctrl/⌘+K command bar, extracted from the ContentGlows bar.

- `CommandBarScope` around the app shell: global Ctrl/⌘+K (also inside text
  fields), inactive while another dialog is open; commands run with the
  scope's context, so routing works from them. On the web it cancels the
  browser's own Ctrl/⌘+K (address bar search).
- `opener` replaces the in-app bar by another one (the floating window):
  Ctrl/⌘+K (as a toggle) and every `CommandBarController.open()` go to it,
  so two bars never open together. The registry, recents and commands stay
  the scope's. It is read at each call, so it can be set after the first
  build (an open in-app bar then closes).
- `CommandBarContribution` around a screen: its commands are listed under
  their section while it is mounted and its route is on top. A screen kept
  alive offstage (indexed stack tab) passes `isActive`.
- Search: every word must match the label or keywords, accents folded
  (« ecran » finds « Écran »); label prefix ranks first, disabled entries
  last.
  `searchOnly` entries (songs, notes) stay hidden until something is typed.
- Sections in the order the app gives, recents first (`CommandBarRecentsStore`,
  memory by default; back it with `SharedPreferences` through
  `CallbackCommandBarRecents`).
- One-letter filters (`CommandBarFilter`): `n idea` becomes a « Notes » chip;
  Backspace on an empty field removes it.
- Keys: ↑/↓, Enter, Shift+Enter or Ctrl/⌘+Enter (secondary action, also on
  disabled rows), Ctrl/⌘+1…9 (hidden under 600 px), Esc (filter first, then
  close). `primaryLabel` names what Enter does on a row in the footer.
- Rows: `badge` shows a short state in a pill after the label;
  `CommandBarSection.limit` caps a section while no filter is active.
- Entries loaded after opening: pass a `refresh` listenable (scope,
  `showCommandBar`, `CommandBarView`); contributions refresh on their own.
- Texts: `CommandBarStrings.en`, `.fr`, or the app's own.
- Look: `CommandBarThemeData` theme extension, every value falls back on the
  `ColorScheme`; `keycapBuilder` for app-drawn keycaps.
  `highlightIndicatorColor` adds a leading bar to the highlighted row.
- `CommandBarTile`: the bar's row, for command suggestions an app lists in
  its own surface (under a search field).
- Resizing: the side and bottom edges (and bottom corners) drag the bar to
  another size; a grip shows on hover, double-click restores the theme's
  size. Kept in a `CommandBarSizeStore` (memory by default,
  `CallbackCommandBarSize` for the app's storage); `resizable: false` turns
  it off.
- Opt-in behaviours (`CommandBarBehavior`, all off by default; the scope
  takes a builder read at each opening, so app settings can drive it):
  `fuzzyMatch` (letters in order, ranked last), `sortSectionsByMatch`,
  `tappablePrefixHints`. `CommandBarFilter.requiresSpace: false` applies a
  symbol prefix without a space (`>foo`).
- Other engines (floating window, native relay): `CommandBarEntry.toJson` /
  `fromJson` (icons by code point through an app table), `CommandBarView` and
  `showCommandBar` with your own `CommandBarSource`.
- Search field gestures on `CommandBarView`: `onSearchDoubleTap` (expand the
  bar, maximize its window) keeps the caret instead of selecting a word;
  `onSearchDragStart` turns a mouse drag in the field into a window move
  instead of a text selection. Click to place the caret and keyboard
  selection (Shift+arrows, Ctrl/⌘+A) keep working.
- `CommandBarView.fillHeight`: the bar takes all the height it is given (the
  list grows, the footer stays at the bottom), for a window of its own; off,
  it is as tall as its content, as in a dialog.
- Shortcuts sheet, built from the same registry, so it follows the current
  screen and teaches its keys: « On this page » (the contributed commands
  that have `shortcuts`), the screen's other keys (`CommandBarShortcuts`
  around it, groups of `CommandBarShortcutHint`), « Everywhere » (Ctrl/⌘+K,
  the sheet's own keys), one group per bar section for the app-wide
  commands (`CommandBarSection.shortcutLabel: 'Aller à {label}'` renames
  them), then the scope's `shortcuts:` groups (Space plays or pauses).
  - One declaration for the key and its row: a hint's `bindings`
    (`ShortcutActivator` → callback) run while its screen is on top (or the
    scope, for `shortcuts:`), so the sheet cannot drift from the keys.
    Bindings without Ctrl, Alt or Meta pause while a text field has focus
    (`commandBarIsTyping`), which the sheet's footer says.
  - Search field (accents folded, keys and notes included) and an empty
    state; « or » between alternatives, « then » inside a sequence (`G N`).
  - `keysText` for what is not a key (« Glisser-déposer », « Q S D F… »),
    `note` for muted words after the keys (« dans la bibliothèque »).
  - « S'entraîner » (`CommandBarShortcutPractice`, also usable on its own):
    one card per shortcut of the listed groups (the search narrows them),
    in random order; the user presses the keys from memory. Checked against
    the hint's `bindings`, else its labels (Ctrl/Maj/Alt/Win, named keys in
    English or French, F1–F24, letters, symbols whatever the layout,
    sequences). Keys Windows takes first (Win, Alt+Tab, Alt+F4, Ctrl+Alt+Del,
    an app's global hotkey) or labels it cannot read ask the user to rate
    themselves. « Afficher la réponse » sends the card to review; the end
    shows the score and replays the missed cards. Escape climbs one level:
    once pauses the card (the keyboard reaches the buttons again,
    « Reprendre » listens anew), twice shows the answer, and from an
    answered card or the score it goes back to the list; so Escape is never
    an answer (such a card asks for a self-rating). While it runs, the scope
    leaves every key to it.
  - Opened with `CommandBarController.showShortcuts()`, F1
    (`shortcutsOnF1`) or « ? » outside text fields
    (`shortcutsOnQuestionMark`), both off by default;
    `shortcutsCommandSection` adds a « Keyboard shortcuts » entry to the bar.
    With a floating bar, list `commandBarShortcutsCommandId` as an entry that
    brings the main window forward and call `showShortcuts()` when chosen.
    `showCommandBarShortcuts` shows a list built elsewhere.

```dart
CommandBarScope(
  commands: appCommands,
  strings: CommandBarStrings.fr,
  sections: const [
    CommandBarSection(id: 'screens', title: 'Navigation', shortcutLabel: 'Aller à {label}'),
    CommandBarSection(id: 'actions', title: 'Actions'),
  ],
  shortcutsOnF1: true,
  shortcutsCommandSection: 'actions',
  shortcuts: (context) => [
    CommandBarShortcutGroup(title: 'Lecture', hints: [
      CommandBarShortcutHint(
        shortcuts: ['Space'],
        label: 'Lecture ou pause',
        bindings: {const SingleActivator(LogicalKeyboardKey.space): player.toggle},
      ),
      const CommandBarShortcutHint(keysText: 'Glisser-déposer', label: 'Importer des fichiers'),
    ]),
  ],
  child: shell,
);

// A screen
CommandBarShortcuts(
  groups: [
    CommandBarShortcutGroup(title: 'Écoute et tablature', hints: [
      CommandBarShortcutHint(
        shortcuts: ['Ctrl+←', 'Ctrl+→'],
        label: 'Reculer ou avancer de 5 secondes',
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): () => seek(-5),
          const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): () => seek(5),
        },
      ),
      CommandBarShortcutHint(
        shortcuts: ['['],
        label: 'Poser le début (A) de la boucle',
        bindings: {const CharacterActivator('['): loop.setStart},
      ),
    ]),
  ],
  child: CommandBarContribution(commands: screenCommands, child: screen),
);
```

## `flutter/shipglows_window`

Hides the native title bar (Windows, Linux, macOS) and draws a themeable one
on top of [`window_manager`](https://pub.dev/packages/window_manager).

- Native move loop: edge snapping, Windows 11 snap bar, `Win` + arrows.
- Double-click toggles maximize; top edge and corners stay resizable.
- Windows/Linux: our minimize/maximize/close buttons. macOS: native traffic lights.
- Windows 11: native rounded corners and a 1 px border in the app color
  (`ShipglowsWindowFrame.borderColor`, or `ShipglowsWindow.setFrame`). The
  radius is the system one; Windows 10 stays square.
- Or the app's own radius: `ShipglowsWindowFrame.cornerRadius` makes the
  window frameless and transparent, clips it to that radius (antialiased) and
  adds 6 px resize edges. No native drop shadow in that mode.
- `outline`: an app-drawn border of any width along the corners, hidden when
  maximized or full screen.
- Mobile and web: no-op, the app renders unchanged.
- Not included: the Windows 11 Snap Layouts flyout on maximize hover
  (`Win` + `Z` still opens it). Keep the maximize button isolated so it can be
  added later.

- Session restore (`ShipglowsWindowSession`): position, size, maximized
  state, app zoom and last page come back at the next launch; a window left
  on an unplugged screen is ignored. The page is an app-defined string, only
  saved when listed in `restorableLocations`.

### Usage

```yaml
dependencies:
  shipglows_window:
    path: ../../shipglows-ui-engine/flutter/shipglows_window
```

```dart
// main(), after the binding is initialized and before runApp:
await ShipglowsWindow.ensureInitialized(minimumSize: const Size(720, 480));
await ShipglowsWindowSession.instance.restore(
  appFolder: 'MyApp',
  restorableLocations: {'/home', '/settings'},
);

// MaterialApp:
builder: (context, child) => ShipglowsWindowFrame(
  style: ShipglowsTitleBarStyle.fromTheme(Theme.of(context)),
  child: child ?? const SizedBox.shrink(),
),
```

Zoom (`shipglows_flutter_zoom`) and last page:

```dart
final session = ShipglowsWindowSession.instance;
FlutterZoomViewport(
  initialZoom: session.zoom,
  resetZoom: 1,
  minimumZoom: session.minimumZoom,
  maximumZoom: session.maximumZoom,
  onZoomChanged: session.saveZoom,
  child: child,
);
// On each route change: session.saveLocation(path);
// Once the user may see it: final page = session.takePendingLocation();
```

Each app passes its own brand tokens through `ShipglowsTitleBarStyle`.

## `flutter/shipglows_overlay_window`

Independent desktop overlay windows (Windows; no-op elsewhere): each runs its
own Flutter engine in its own window.

- Always on top by default (`alwaysOnTop`), taskbar button optional.
- A click outside (`outsideClick`) sends it just behind the window clicked
  by default (`background`), back on top when reactivated; `close` hides it,
  `none` keeps it above everything. Windows it owns (file dialogs) are not
  outside.
- Showing it never shows, raises or activates the main window; focus goes
  back to the previous window when it hides. `hide(focus:)` picks another
  target: `OverlayHideFocus.none`, or `.app` (the app's main window, shown
  if hidden). `previousForeground` (both sides) is the HWND of the window in
  front before the opening, for example to paste into it; `show` takes one
  to override it (a tray menu that activated the app first).
- Revealed only after Dart has drawn the data passed to `show`.
- Drag to move; edges resize (`resizable`); double-click on an edge restores
  the default size (eased, unless Windows animations are off); double-click
  on the drag area maximizes (`doubleClickMaximizes`): the overlay fills the
  work area of its monitor (taskbar left visible) and a second double-click
  gives back its exact bounds. `ShipglowsOverlayHost.maximized` tells the
  overlay (listeners notified before the eased resize). Dragging it while maximized restores its size
  under the pointer. Win+Up/Down use the same maximize. The system maximize
  is not used: it misplaced borderless and transparent overlays.
- Live resize without flicker: the view draws its frame at the new size
  during `WM_NCCALCSIZE`, before Windows resizes the window, and nothing of
  the old client area is blitted (`WVR_VALIDRECTS`), so the content never
  jumps when the left or top edge is dragged. `backgroundColor` paints what a
  step the engine could not follow in time (over 100 ms) would expose.
- Position and size remembered (`sizeMemory`: none, session, persistent) in
  `%APPDATA%\<appFolder>\overlay_windows.json`, clamped to the screen;
  per-monitor DPI.
- Windows 11 rounded corners, border color and shadow (DWM).
  `ShipglowsOverlayHost.setFrame` changes the dark frame, border and
  background colors while the overlay runs (theme changes).
- `transparent: true`: a see-through window with no system corners, border,
  shadow or background (same composition attribute as `window_manager`'s
  transparent background). The overlay draws its whole shape and paints no
  background of its own (`ShipglowsOverlayHost.transparent`); its transparent
  margin still moves and resizes the window but does not pass clicks through.
- Alt+F4 and a plain Escape ask the overlay to close (`onRequestClose`,
  default: hide), whichever window holds the keyboard; `closeOnEscape = false`
  for an overlay with its own Escape handling. A dialog or menu above the
  first route keeps Escape.

```dart
// Main engine
final palette = ShipglowsOverlayWindow(
  id: 'palette',
  entrypoint: 'paletteOverlayMain',
  options: const ShipglowsOverlayOptions(appFolder: 'MyApp'),
);
await palette.show(data: {'query': ''});
palette.messages.listen((message) { /* from the overlay */ });

// Overlay engine
@pragma('vm:entry-point')
void paletteOverlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  ShipglowsOverlayHost.instance.onShow = (data) { /* load data */ };
  runApp(const ShipglowsOverlayFrame(child: PaletteApp()));
  ShipglowsOverlayHost.instance.ready();
}
```

Overlay engines register no plugin unless the runner calls
`ShipglowsOverlayWindowSetPluginRegistrant`. Runners can also create an
overlay natively (`ShipglowsOverlayWindowCreate`, see
`windows/include/shipglows_overlay_window/overlay_window.h`), with a message
hook for native content and their own position store.

## `flutter/shipglows_command_bar_window`

The shared command bar (`CommandBarView`) in its own floating window, on
`shipglows_overlay_window`: own engine, always on top, opened in the upper
part of the cursor's monitor, drag to move, edges to resize (native, no
flicker), position and size remembered, focus back to the previous window
on close. Escape and a click outside close it.

- App engine: `ShipglowsCommandBarWindow` publishes a
  `ShipglowsCommandBarSnapshot` (entries as `CommandBarEntry`, recent ids,
  brightness, locale), opens, closes or toggles the bar and updates it in
  place while open. `selections` reports each choice (`id`, `secondary`,
  `previousForeground` HWND); the bar is already hidden and the app runs the
  effect itself.
- `data`: the app's own JSON-safe values for its bar (a color theme the
  bar's engine cannot read from storage), read back from
  `ShipglowsCommandBarOverlayController.snapshot`.
- `appWindowIds`: entries that open a screen of the app; choosing one brings
  the main window forward instead of the previous window.
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
    path: ../../shipglows-ui-engine/flutter/shipglows_command_bar_window
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

## `flutter/shipglows_tray`

Notification area (tray) icon for desktop apps (Windows; no-op on mobile,
web, macOS and Linux). Native Win32, no third-party plugin.

- Icon (the executable's by default, or an `.ico` asset or file), tooltip
  (127 characters), both changeable while running (`update`).
- Standard menu every app completes, with separators and monochrome glyphs
  (Segoe Fluent Icons, Segoe MDL2 Assets on Windows 10) in the light or dark
  theme of Windows apps: Ouvrir <app> (bold) │ app entries │ help entries │
  Version (greyed, read from the executable) · Rechercher une mise à jour ·
  Paramètres… │ Quitter <app>. Entries without a callback are left out;
  labels in French or English (`ShipglowsTrayStrings`).
- App entries: `ShipglowsTrayAction` (glyph, disabled, check mark, shortcut
  text, `showsMainWindow`), `ShipglowsTrayHeader` (greyed section title),
  `ShipglowsTraySubmenu`, `ShipglowsTraySeparator`.
- Click (or Enter on the icon): open the main window (default), the menu,
  an event, or a menu entry (`ShipglowsTrayClick`). Right click: the menu.
- Every event carries `previousForeground`, the HWND of the last window in
  front before the click (taskbar and menus ignored), for
  `ShipglowsCommandBarWindow.open(previousForeground:)`.
- Closing the main window (`ShipglowsTrayCloseBehavior`): ask (default), hide
  to the tray (minimize while the icon is missing), minimize, or quit.
  « Ask » shows a dialog (Réduire dans la zone de notification / Quitter /
  Annuler, « Ne plus me demander ») on `closeDialogContext`, a context below
  the app's `MaterialApp`; without one the window hides to the tray. A
  remembered choice is kept in `%APPDATA%\<appFolder>\tray.json` (or a
  `ShipglowsTrayStore`) and wins over the configured default.
  `ShipglowsTrayCloseSetting` is the settings row to change it back;
  `closeBehavior` / `setCloseBehavior` for a custom one. Quitting goes
  through `onQuitRequested` (false keeps the app running).
- Icon back after an Explorer restart, retried for a minute when the
  taskbar is not ready at sign-in.
- Single instance: a later launch hands its command line to the running app
  (`ShipglowsTraySecondInstance`) and exits; the running app comes to the
  front.

```yaml
dependencies:
  shipglows_tray:
    path: ../../shipglows-ui-engine/flutter/shipglows_tray
```

```dart
await ShipglowsTray.instance.start(ShipglowsTrayConfig(
  appName: 'ContentGlows',
  items: const [
    ShipglowsTrayAction('capture.screenshot', 'Capture d’écran',
        glyph: ShipglowsTrayGlyph.screenshot),
    ShipglowsTrayAction('commandBar', 'Barre de commandes',
        glyph: ShipglowsTrayGlyph.commandBar),
  ],
  standard: ShipglowsTrayStandardMenu(
    onSettings: () => router.go('/settings'),
    onCheckForUpdates: () => autoUpdater.checkForUpdates(inBackground: false),
  ),
  appFolder: 'ContentGlows',
  closeDialogContext: () => homeKey.currentContext,
  onQuitRequested: () async => saveEverything(),
));

ShipglowsTray.instance.events.listen((event) {
  switch (event) {
    case ShipglowsTrayItemSelected(id: 'commandBar', :final previousForeground):
      commandBar.open(previousForeground: previousForeground);
    case ShipglowsTrayItemSelected(:final id):
      runCommand(id);
    case ShipglowsTraySecondInstance(:final arguments):
      handleArguments(arguments); // untrusted: validate
    case ShipglowsTrayClicked():
      break;
  }
});
```

Single instance, in `windows/runner/main.cpp` before the window is created:

```cpp
#include <shipglows_tray/single_instance.h>

if (ShipglowsTrayForwardToPrimary(L"contentglows")) return EXIT_SUCCESS;
```

The plugin decides on `WM_CLOSE` through Flutter's top-level window delegate
(`HandleTopLevelWindowProc`). A runner drops its own tray icon, and runs any
`WM_CLOSE` handling of its own (an orderly shutdown) after that call: the
message only reaches it when the app really quits. The icon stays until the
engine goes away, so a shutdown the runner cancels keeps it.

## `flutter/shipglows_hotkeys`

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
    path: ../../shipglows-ui-engine/flutter/shipglows_hotkeys
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
