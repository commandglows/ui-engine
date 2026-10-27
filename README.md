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

## `flutter/shipglows_theme`

One theme for every app and package. `ShipglowsTheme` (a `ThemeExtension`)
holds the semantic roles: surfaces, text, icons, border/line, highlight,
accent, danger, success, warning, focus, scrim, keycap face, shape, spacing, control height and
motion. Each app fills it once from its own brand tokens (generated from its
design-token source, as its Astro site does) and adds it to
`ThemeData.extensions`, light and dark:

```dart
ThemeData(extensions: [ShipglowsTheme(surface: …, keyBorder: …, …)])
```

`ShipglowsScale` is the shared design scale, as constants usable in `const`
code and in screens: spacing `spaceXs`…`spaceXxxl` (4, 8, 12, 16, 24, 32, 48),
radii `radiusXs`…`radiusXl` plus `radiusFull` (4, 6, 10, 16, 24, 999), motion
`motionFast` / `motionNormal` / `motionSlow` (120, 200, 320 ms) with
`curveStandard` and `curveEmphasized`, type sizes `textXs`…`textHero` (11, 14,
16, 18, 22, 38), icon sizes `iconSm` / `iconMd` / `iconLg` (16, 20, 24) and the
Material 3 window breakpoints `breakpointCompact` / `breakpointMedium` /
`breakpointExpanded` (600, 840, 1200). `ShipglowsTheme`'s default spacing,
radii and motion come from it; an app overrides a brand role, not the scale.

Without one, `ShipglowsTheme.of(context)` (or `.from(themeData)`) derives the
roles from the `ColorScheme`: the former default look of the command bar,
guide and title bar. The menu changed to match the bar: its highlighted row
is `secondaryContainer` (was a 10 % `onSurface` tint), its keys are the shared
keycap on `surface`, its corners follow `radiusLg` (16, was 12) and its rows
`radiusMd` (10, was 8).

Base components drawn from the roles, the same everywhere:

- `ShipglowsKeycap('Entrée')`: one key, sized to its label;
  `ShipglowsKeys(['Ctrl', 'K'])`. The command bar and the menu draw their
  keys with it.
- `ShipglowsKeyButton(label: 'c Presse-papiers', onPressed: …, selected: …)`:
  a button drawn as one keycap holding its whole text, with a tap target of
  `controlMinHeight`; the selected one is opaque, the others fade.
- `ShipglowsKeyHint(keys: ['Alt', 'Entrée'], label: 'actions')`: a footer
  hint.
- `ShipglowsEmptyState(icon: …, message: 'Aucune …', actionLabel: 'Créer …',
  onAction: …)`: an empty list that says what belongs there and offers the
  first step; no button without `actionLabel`. The icon takes `accent`, the
  spacing the space roles; the texts are the caller's.
- `ShipglowsFocusRing(child: …, radius: …, width: …)`: a `focus` outline drawn
  while keyboard focus is inside `child` (never on a mouse click), for rows
  whose Material ink hides the focus. `radius` defaults to `radiusMd`, `width`
  to twice `lineWidth`.

The command bar, `shipglows_menu`, `shipglows_guide` and the
`shipglows_window` title bar read these roles for every value their own theme
extension leaves out, so one declaration dresses them all alike; a package
theme (`CommandBarThemeData`, `ShipglowsMenuTheme`, `GuideThemeData`) keeps
only what is specific to it. Rule: a new shared component takes its colors,
radii, spacing and keys from `ShipglowsTheme`, never from raw values or its
own palette.

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
  `tappablePrefixHints`, `showEntryKinds`, `hiddenKinds`, `kindDisplay`,
  `compactRows` (the subtitle follows the label on its line, muted, so more
  rows fit; a disabled row keeps its reason on a line of its own).
  `CommandBarFilter.requiresSpace: false` applies a symbol prefix without a
  space (`>foo`).
- Entry kinds (`CommandBarEntry.kind`, `CommandBarEntryKind`): what choosing
  a row does, so an action run right in the bar never looks like a way to a
  screen. Built-in `open` (a screen of the app), `action` (works from the
  bar: save, copy, toggle) and `app` (another application, the browser); an
  app adds its own with another id. `showEntryKinds` shows each kind at the
  end of its row, as `kindDisplay` says (`CommandBarKindDisplay.icon`,
  `label` or `iconAndLabel`): the icon, and/or the short muted text of
  `CommandBarStrings.entryKindLabels[id]` (« Action », « App »), with
  `entryKinds[id]` as tooltip and spoken text; `hiddenKinds` leaves whole
  kinds out (`{'open'}` for actions only).
- Actions menu (like Claude Desktop's search palette): `CommandBarEntry.actions`
  (`CommandBarEntryAction`: `id`, `label`, `icon`, one-chord `shortcut`,
  `group`, `destructive`, `confirm`, all JSON-safe) lists more things to do
  with a row, ungrouped ones first, then one titled block per `group`, then
  the `destructive` ones in the error color after a separator. The panel
  view lives on its own in `src/actions_panel.dart` (`CommandBarActionsPanel`,
  not exported), so a shared floating menu can replace it later. Alt+Enter
  (Ctrl+K stays the hotkey), a right-click or the « … » button shown on the
  hovered or highlighted row opens it, anchored to the end of the row: a
  header with the entry's label and a muted « section · badge · subtitle »
  line, then Enter (`primaryLabel`), Shift+Enter (`secondaryLabel`) and the
  actions, numbered 1–9 in keycaps. ↑/↓ and Enter choose, a digit runs its
  line, Escape, ← or Alt+Enter close it; scrolling the list closes it too.
  A `confirm` action asks for a second press first, its label replaced by
  `CommandBarStrings.confirmAction` (« Press again to confirm »). The footer
  shows « Alt Enter actions » when the row has any. An action's `shortcut` also
  runs it straight from the list. The choice carries
  `CommandBarChoice.action` (null for Enter and Shift+Enter, which keep
  working as before); actions run on a disabled row like the secondary
  action. In a `CommandBarScope`, `CommandBarCommand(actions: …, runAction:
  (context, actionId) …)`.
- Actions on the typed text: `CommandBarCommand.query(runQuery: (context,
  text) …)` (`CommandBarEntry.usesQuery` in JSON). Never searched nor kept in
  the recents: once words are typed they are listed last under « With this
  text » (`queryActionsSection`), alone when nothing matches, so a phrase
  that finds nothing still offers something to do with it. A filter keeps
  those it matches. `{query}` (`commandBarQueryPlaceholder`) in the label or
  subtitle shows the text; `CommandBarChoice.query` carries it (filter
  prefix left out) to the owner of a `CommandBarView`.
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

Zoom ([`shipglows_flutter_zoom`](#fluttershipglows_flutter_zoom)) and last page:

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

Changes are written 400 ms later. Before quitting, `flush()` writes them now
(never throws, errors go to `onError`), e.g. with
[`shipglows_tray`](#fluttershipglows_tray):

```dart
ShipglowsTrayConfig(
  // …
  onQuitRequested: () async {
    await ShipglowsWindowSession.instance.flush();
    return true;
  },
);
```

Each app passes its own brand tokens through `ShipglowsTitleBarStyle`.

## `flutter/shipglows_flutter_zoom`

Zooms the whole app UI while the window stays filled: Ctrl/Command+wheel,
trackpad pinch, Ctrl/Command+= / Ctrl/Command+- (5 % per press by default) and
Ctrl/Command+0. Bounds 75–150 % by default. See the
[package README](flutter/shipglows_flutter_zoom/README.md).

```yaml
dependencies:
  shipglows_flutter_zoom:
    path: ../../shipglows-ui-engine/flutter/shipglows_flutter_zoom
```

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
- Window shape: `ShipglowsOverlayHost.setShape(List<RRect>?)` clips a
  transparent overlay to rounded rectangles (logical pixels from the window's
  top-left corner). Pixels outside are neither drawn nor hit, so clicks there
  reach the window below; the edge is not smoothed, so keep a few transparent
  pixels around what is drawn. `null` gives the whole window back.
- `activateOnClick: false`: clicks, hover and drags never activate the
  overlay (`WS_EX_NOACTIVATE`), so the window in front keeps the keyboard.
  `startDrag` then moves the window itself while it holds the mouse capture
  (the system move loop would activate it), and saves the position when the
  button is up.
- `clampRect`: only that part of the window (logical, from its top-left
  corner) is kept inside the work area, when the overlay opens, while it is
  dragged and when displays or the taskbar change; the rest may leave the
  screen. `OverlayPlacement.cursorMonitorRight` docks that part against the
  right edge of the cursor's monitor, vertically centered.
- `ShipglowsOverlayHost.workArea`: the monitor's work area in logical pixels
  relative to the window, set before `onShow` and updated after a move, a DPI
  change or a display change (listeners notified), so an overlay can open
  its content toward the free side of the screen. `placements` counts those
  reports (listeners notified at each, even unchanged): one always follows
  a `startDrag`, so an overlay can wait for its new place after a drag. With
  a `clampRect`, a DPI change keeps that part's center where it was.
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

## `flutter/shipglows_floating_launcher`

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
  `bubbleLabel`, `brightness`, `data`), shows and hides the launcher and
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
    path: ../../shipglows-ui-engine/flutter/shipglows_floating_launcher
```

```dart
// App engine
final launcher = ShipglowsFloatingLauncher(
  entrypoint: 'launcherMain',
  appFolder: 'MyApp',
);
launcher.selections.listen(runCommand); // item id
launcher.bubbleTaps.listen((_) => showMainWindow());
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

## `flutter/shipglows_menu`

Action menu used everywhere in an app, modelled on Raycast's ≡ menu: the
same entries in the native tray menu and in a floating Flutter list
anchored to a button, a right click or a « ⋯ » menu. Not tied to the
command bar.

- Model, pure Dart (`package:shipglows_menu/shipglows_menu_model.dart`):
  `ShipglowsMenuAction` (id, label, icon, shortcut text such as
  `Ctrl+Alt+K`, checked, disabled, search `keywords`, `onSelected`),
  `ShipglowsMenuSeparator`, `ShipglowsMenuHeader` (a titled group runs to
  the next separator or header; `ShipglowsMenuItem.group(title, items)`),
  `ShipglowsMenuSubmenu`, and `ShipglowsMenu` (title, subtitle, items).
  Everything but the callbacks round-trips through `toJson` / `fromJson`.
- Icons: `ShipglowsMenuIcon` carries a Segoe Fluent / MDL2 glyph (drawn by
  the tray) and a name (drawn by Flutter). Named constants (`settings`,
  `feedback`, `manual`, `whatsNew`, `info`, `quit`…) map to Material icons
  (`ShipglowsMenuIcons.material`, extended by `ShipglowsMenuTheme.icons`);
  an icon with only a glyph is drawn with the Segoe font on Windows;
  `ShipglowsMenuIcon.named('myapp.icon')` is for Flutter-only icons.
- Standard entries declared once (`ShipglowsAppMenu`): Envoyer un avis… ·
  Manuel · Nouveautés · help entries │ Version · À propos de <app> ·
  Rechercher une mise à jour · Paramètres… │ Quitter <app>. Entries without
  a callback are left out; reserved ids in `ShipglowsMenuStandardIds`;
  labels in `ShipglowsMenuStrings.fr` / `.en`; `formatShipglowsVersion`
  turns `1.2.3+4` into `1.2.3 (4)`.
- Flutter list (`showShipglowsMenu`, `ShipglowsMenuButton`,
  `ShipglowsMenuAnchor`, or `ShipglowsMenuPanel` to embed): title line (app
  name and version), group titles, shortcuts as keys on the right,
  « Rechercher une action… » filtering as you type (accents and case
  ignored, keywords and group titles included, submenus searched too).
  Keyboard: ↑/↓, Enter, → / ← into and out of submenus, Escape closes only
  the menu (the key never reaches the window). Opens below its anchor, or
  above with `preferAbove` (a bar's bottom-left ≡), on the side with room.
  Returns the chosen id and calls the action's `onSelected` once closed.
- Theme from the app's `ColorScheme`, customised with the
  `ShipglowsMenuTheme` extension (colours, width, height, radius, row
  height, shadows, label style, icons). Rows are 44 px minimum, with
  button, header, selected and checked semantics; reduced motion removes
  the fade.

```yaml
dependencies:
  shipglows_menu:
    path: ../../shipglows-ui-engine/flutter/shipglows_menu
```

```dart
final appMenu = ShipglowsAppMenu(
  appName: 'ContentGlows',
  version: formatShipglowsVersion(packageInfo.version),
  onSettings: () => router.go('/settings'),
  onFeedback: openFeedback,
  onManual: () => launchUrl(manualUrl),
  onWhatsNew: showWhatsNew,
  onAbout: showAbout,
  onQuit: () => ShipglowsTray.instance.quit(),
  shortcuts: {ShipglowsMenuStandardIds.settings: 'Ctrl+,'},
);

// Tray: the same standard entries.
ShipglowsTray.instance.start(ShipglowsTrayConfig(
  appName: 'ContentGlows',
  standard: ShipglowsTrayStandardMenu.app(appMenu),
));

// In the app: a ≡ button at the bottom left of a bar.
ShipglowsMenuButton(
  preferAbove: true,
  menu: appMenu.menu(actions: [
    ...ShipglowsMenuItem.group('Capture', const [
      ShipglowsMenuAction('capture.screenshot', 'Capture d’écran',
          icon: ShipglowsMenuIcon.screenshot, shortcut: 'Ctrl+Shift+S'),
    ]),
  ]),
  onSelected: runCommand,
);

// Or on a right click.
ShipglowsMenuAnchor(
  menu: rowMenu,
  openOnSecondaryTap: true,
  builder: (context, open) => ListTile(title: Text(row.title), onTap: open),
);
```

## `flutter/shipglows_tray`

Notification area (tray) icon for desktop apps (Windows; no-op on mobile,
web, macOS and Linux). Native Win32, no third-party plugin.

- Icon (the executable's by default, or an `.ico` asset or file), tooltip
  (127 characters), both changeable while running (`update`).
- Standard menu every app completes, with separators and monochrome glyphs
  (Segoe Fluent Icons, Segoe MDL2 Assets on Windows 10) in the light or dark
  theme of Windows apps: Ouvrir <app> (bold) │ app entries │ Envoyer un
  avis… · Manuel · Nouveautés · help entries │ Version (greyed, read from
  the executable) · À propos de <app> · Rechercher une mise à jour ·
  Paramètres… │ Quitter <app>. Entries without a callback are left out;
  labels in French or English (`ShipglowsTrayStrings`, whose `menu` labels
  are the shared `ShipglowsMenuStrings`).
- Entries are the action menu model of
  [`shipglows_menu`](#fluttershipglows_menu), re-exported:
  `ShipglowsMenuAction` (icon, disabled, check mark, shortcut text,
  `showsMainWindow`, `onSelected` called after the event),
  `ShipglowsMenuHeader` (greyed section title), `ShipglowsMenuSubmenu`,
  `ShipglowsMenuSeparator`. The former `ShipglowsTray*` names
  (`ShipglowsTrayAction`, `ShipglowsTrayGlyph`, `ShipglowsTrayHeader`,
  `ShipglowsTrayStandardIds`…) remain as aliases, and `glyph:` as a
  deprecated name of `icon:`.
- Shared standard entries: declare a `ShipglowsAppMenu` once and pass
  `ShipglowsTrayStandardMenu.app(appMenu)`; the same object gives the
  Flutter menu (`appMenu.menu(actions: …)`). The tray quits itself
  (`onQuitRequested`), whatever the app menu's `onQuit`.
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
- Launch at Windows sign-in (`setLaunchAtStartup`, `launchAtStartup`): an
  entry `<appName>` under `HKCU\…\CurrentVersion\Run` starting this
  executable with `--launched-at-startup` (a dev build, run from
  `<project>\build\windows\…\runner\Debug` or `Profile`, registers
  `shipglows-dev start -ProjectPath <project> -FlutterDevice windows`
  instead, since its exe lacks the hot reloads; a stale entry of this
  executable is rewritten at the next start); turned off in Task Manager reads
  as off, and turning it on again clears that. After such a launch the main
  window starts as the user chose (`ShipglowsTrayStartupWindow`): hidden in
  the tray until opened (default; minimized while the icon is missing),
  minimized in the taskbar, or open. The choice is kept with the close
  behavior (`startupWindow` / `setStartupWindow`, default from the config);
  `launchedAtStartup` tells the app. `ShipglowsTrayStartupSetting` is the
  settings switch plus that choice.
- Icon back after an Explorer restart, retried for a minute when the
  taskbar is not ready at sign-in.
- Single instance: a later launch hands its command line to the running app
  (`ShipglowsTraySecondInstance`) and exits; the running app comes to the
  front.
- Jump List of the taskbar button (right click on it), like the
  « Épinglé » / « Récent » of document apps: `ShipglowsJumpListRecents`
  keeps the last opened items (`opened(ShipglowsJumpListItem(id, title))`,
  10 by default, in `%APPDATA%\<appFolder>\jump_list.json`, `items` for an
  in-app menu) and shows them under « Récent ». Windows lets the user pin
  each one (« Épingler à cette liste », kept by Windows even once the app
  forgets it) or remove it (the app forgets it at the next update). Fixed
  tasks (`ShipglowsJumpListTask`) go below. Choosing an item starts the app
  with `--shipglows-open=<id>`: `ShipglowsJumpList.itemIdFrom(args)` at
  launch, `ShipglowsTraySecondInstance.openedItemId` while it runs (needs
  `ShipglowsTrayForwardToPrimary`). A pinned id can point to a deleted
  item. « Récent » stays empty while Windows hides recently opened items
  (Paramètres › Personnalisation › Démarrer). The list replaces any list
  the runner commits itself (move its tasks to `tasks`), and a runner that
  sets an explicit AppUserModelID passes it as `appUserModelId`.
  `ShipglowsJumpList.instance.update(recent:, categories:, tasks:)` for an
  app that derives its lists from its data (« Publiés récemment »,
  « Brouillons en cours »: `ShipglowsJumpListCategory`); the 10 default
  slots are shared between categories, and with `appFolder` the items the
  user removed stay out of later updates.

```yaml
dependencies:
  shipglows_tray:
    path: ../../shipglows-ui-engine/flutter/shipglows_tray
```

```dart
await ShipglowsTray.instance.start(ShipglowsTrayConfig(
  appName: 'ContentGlows',
  items: const [
    ShipglowsMenuAction('capture.screenshot', 'Capture d’écran',
        icon: ShipglowsMenuIcon.screenshot),
    ShipglowsMenuAction('commandBar', 'Barre de commandes',
        icon: ShipglowsMenuIcon.commandBar),
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
    case ShipglowsTraySecondInstance(openedItemId: final id?):
      openDocument(id); // untrusted: look it up
    case ShipglowsTraySecondInstance(:final arguments):
      handleArguments(arguments); // untrusted: validate
    case ShipglowsTrayClicked():
      break;
  }
});

// Jump List: recent items the user can pin from the taskbar.
final recents = ShipglowsJumpListRecents(appFolder: 'ContentGlows');
await recents.load();
if (ShipglowsJumpList.itemIdFrom(args) case final id?) openDocument(id);
// Each time a document opens:
await recents.opened(ShipglowsJumpListItem(doc.id, doc.title,
    description: doc.path));
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

## `flutter/shipglows_updater`

Release updates behind one API, on Windows and Android. Depends on
`auto_updater` (WinSparkle) only; the Android side is the package's own
Kotlin plugin. Debug and profile builds never update (the debug key cannot
take a release APK); web does nothing.

- `ShipglowsUpdater.instance.start(ShipglowsUpdaterConfig(windowsFeedUrl:,
  androidManifestUrl:, checkInterval:), quitForUpdate:)` once after the first
  frame; idempotent, never throws. An empty or non-HTTPS URL turns that
  platform off. `checkNow()` for « Rechercher une mise à jour » (tray
  `onCheckForUpdates`, menu), `install()`, `state` (a
  `ValueListenable<ShipglowsUpdateState>`: idle, checking, up to date,
  available, downloading with progress, needs permission, installing,
  failed with an `ShipglowsUpdateErrorKind`), `currentVersion` (Android).
- Windows: WinSparkle reads the appcast, shows its own window, checks the
  installer's DSA signature against the runner's `DSAPub` resource
  (`DSAPub DSAPEM "winsparkle_dsa_pub.pem"` in `Runner.rc`) and runs it;
  `quitForUpdate` closes the tray first so the installer can replace the
  executable. Taken from ContentGlows (`windows_app_updater.dart`,
  `scripts/package-windows-installer.ps1`, Inno Setup).
- Android: installs from the Play Store (`com.android.vending`) are left to
  the store. Otherwise the app reads `android.json` (`version` `1.2.3+45`,
  `url`, `sha256`, `size`, `publishedAt`, `notesUrl`), compares it with the
  installed `versionName` + `versionCode`, downloads the APK into the cache
  (`shipglows_updates/`, cleared on the next start), and the plugin checks
  SHA-256, package name, a higher `versionCode` and a common signing
  certificate (rotation history included) before it opens the system
  installer through its own `FileProvider`. Without « install unknown apps »
  the state becomes `needsPermission` and the system page opens; `install()`
  again once back. Background checks stay silent on failure.
- The experience, the same on every app: nothing interrupts a session. A
  waiting version is announced at every launch (`ShipglowsUpdateAnnouncer`
  in `MaterialApp.builder`, given the navigator key) until it is installed
  or the person picks « Ne plus me rappeler pour cette version »
  (`skippedVersion` / `onSkipVersion` keep that choice; a newer version is
  announced again). « Plus tard » only closes the dialog. Afterwards a quiet
  `ShipglowsUpdatePill(appName:, compact:)` in the app's chrome (sidebar,
  menu) and `ShipglowsUpdateBadge(child:)` (a dot on the settings icon)
  stay while the update waits.
- `openShipglowsUpdate(context, appName:)` from any entry point:
  `showShipglowsUpdateDialog` on Android (the version and the installed
  one, « Nouveautés » from the manifest's `notes`, what installing does to
  the person's work, then progress, « Masquer » that lets the download carry
  on, the « install unknown apps » step resumed on return, the system
  installer offered again if cancelled, calm errors with « Réessayer »),
  WinSparkle's own window on Windows.
- `ShipglowsUpdateSetting(appName:, strings:)`: the settings row: the state
  as an announced subtitle (or the installed version), « Rechercher une mise
  à jour », « Voir la mise à jour » or « Réessayer »; nothing where the
  updater is inactive. `ShipglowsUpdaterStrings.fr` / `.en` (`{app}`,
  `{version}`, `{current}`, `{percent}`).
- The plugin adds `INTERNET` and `REQUEST_INSTALL_PACKAGES`. A Play Store
  build must remove the second one, which Play restricts:

  ```xml
  <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"
      tools:node="remove" />
  ```

### Publishing

Releases live in one public repository (`dianedef/shipglows-releases`); the
apps' code stays private. `tool/publish-release.ps1 -Repo -App -Apk
-WindowsInstaller -Appcast` puts the files in a versioned release
`<app>-v1.2.3-45` (never replaced; `-Notes` for « Nouveautés »), then
`android.json` and `appcast.xml`
in the rolling `<app>-latest` release, last, so an app never sees a version
whose files are missing. The apps read:

```text
https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/android.json
https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/appcast.xml
```

```dart
unawaited(ShipglowsUpdater.instance.start(
  const ShipglowsUpdaterConfig(
    windowsFeedUrl: String.fromEnvironment('WINDOWS_UPDATE_FEED_URL'),
    androidManifestUrl: String.fromEnvironment('ANDROID_UPDATE_MANIFEST_URL'),
  ),
  quitForUpdate: () => ShipglowsTray.instance.quit(),
));
```

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

## `flutter/shipglows_sync`

Device-to-account sync, ported from CommunityGlows (`cloudReconciliation.ts`,
`NativeSyncReview.vue`, `postAuthSyncFeedback.ts`). No dependency beyond
Flutter; `shipglows_settings` builds on it, and business-data stores can too.

- `SyncStatus` / `SyncHealth`: localOnly, synced, pending, syncing,
  needsReview, unreachable, failed. `SyncSource`: anything with a `status`
  and `sync()`.
- `reconcileSnapshots(device, account, choices:)` on two `SyncSnapshot`s
  (`fields`, and `collections` of records by stable id): union; a value or
  record set differently on both sides is a `SyncConflict`, resolved per key
  (`fields/theme`, `profiles/p1`) with `SyncSide.device` or `.account`.
  `fingerprint` tells whether a side changed before confirming.
- `SyncReviewHost` (`review`, `resolveReview`, `reviewError`: changed or
  failed) and `SyncRecoveryHost` (`recovery`, `restoreRecovery`,
  `dropRecovery`); `SyncRecovery` is JSON for the store's own storage.
- `SyncProgress`: first-sync steps, each shown at least 1 s, the « ready »
  notice hides after 3 s.
- Widgets: `SyncStatusChip` (tap syncs or opens the review),
  `SyncIssueBanner` (retry, sign in, compare), `SyncReviewPrompt` (opens the
  review once per new comparison) and `showSyncReviewDialog` (keep device or
  account for all or per difference, « Rester en local »),
  `SyncProgressOverlay`, `SyncRecoveryPanel`. Texts: `SyncStrings.fr` (default),
  `.en`, `forLocale`; `labelOf` / `describe` name settings and values in the
  app's words.

## `flutter/shipglows_storage`

Files kept away from this computer (audio, video, images), extracted from
BeatGlows. Business-data sync is not here: it belongs to `shipglows_sync`.
The chosen provider is Cloudflare R2, spoken to only through the S3 API so
another S3-compatible bucket is an endpoint change.

- `BlobStore`: `putBytes` (with `WriteCondition.always`, `.ifAbsent`,
  `.ifMatch(etag)`), `putFile` (streamed), `getBytes`, `download` (to a
  `.part` file, then renamed), `head`, `delete`, `list(prefix)`. A key is a
  relative forward-slash path (`checkBlobKey`). Failures are a sealed
  `BlobStoreException` with a French message: `BlobPreconditionFailed`,
  `BlobAccessDenied` (do not retry), `BlobTransientFailure` (may retry),
  `BlobInvalidKey`, `BlobTransferCancelled`.
- `TransferControl(onProgress: (done, total) {…})`, passed to `putBytes`,
  `putFile`, `getBytes` and `download`: progress (bytes kept from an
  interrupted attempt count as done) and `cancel()`, which aborts the request
  under way.
- `S3BlobStore(config, retry:, journal:, multipartThreshold:, partBytes:)`:
  path-style requests over `dart:io`, signed by `SigV4Signer` (checked on the
  AWS test vectors), no AWS SDK; files over 64 MB go up in 16 MB parts.
  `RetryPolicy` (4 tries, waits from 0.5 s doubling up to 30 s, with
  jitter) sends again every request that can safely be sent twice, a single
  part rather than the whole file; a conditional write is never resent. With
  a `TransferJournal` (`FileTransferJournal(dir)` survives a restart,
  `MemoryTransferJournal` does not), a cancelled or failed multipart upload
  is kept and resumes from its stored parts (started over if the bucket
  dropped it), and a download resumes from its `.part` file with a `Range`
  bound to the version by `If-Match`. Without a journal an interrupted
  upload is aborted.
- `FolderBlobStore(root, incomingSuffix:)`: a folder kept in sync by another
  program; writes go through a temporary file, the tag is the SHA-256, a
  missing root (unmounted drive) is reported, never created.
- `MemoryBlobStore` for tests; `parseS3Endpoint` (https, or http on this
  computer for MinIO) and `testBlobStore` (write, read back, delete a probe)
  for a settings page.
- Tests: one contract suite run on every store, including a local fake S3
  bucket (`test/fake_s3_server.dart`) that also proves retries and resumes;
  the run on a real bucket needs `SHIPGLOWS_S3_ENDPOINT`, `_BUCKET`,
  `_REGION`, `_KEY_ID`, `_SECRET` and is skipped without them. Proven on
  Cloudflare R2 on 2026-10-27 (bucket `shipglows-storage-tests`, EU
  jurisdiction, keys limited to it in Doppler `dotfiles`/`dev`):

  ```bash
  SHIPGLOWS_S3_ENDPOINT=https://b805cca6c486d78d68e7a4498292be56.eu.r2.cloudflarestorage.com SHIPGLOWS_S3_BUCKET=shipglows-storage-tests SHIPGLOWS_S3_REGION=auto doppler run --project dotfiles --config dev -- flutter test test/blob_stores_test.dart
  ```

- Backend-signed uploads, extracted from ContentGlows: the backend keeps
  the storage keys and signs one part at a time. `import
  'package:shipglows_storage/signed_upload.dart'` is the web-safe entry (no
  `dart:io`). The ShipGlows protocol under a base path: `POST <base>`
  (`clientKey`, `fileName`, `mimeType`, `byteSize`, `checksumSha256`) opens
  `{uploadId, parts}` or answers `{result}`; `POST
  <base>/<id>/parts/<n>/sign` answers `{uploadUrl, headers}`; `POST
  <base>/<id>/complete` with the receipts; `DELETE <base>/<id>` abandons.
  `SignedUploadClient(call:, put:, journal:).upload(...)` runs it all;
  `uploadSignedParts(parts:, source:, sign:, put:)` is the part loop alone,
  for a backend with its own open and complete routes. The app brings
  `call` (its JSON client with base URL and auth) and `put` (a raw PUT),
  and says which failures are transient (`BlobTransientFailure(cause:)`).
  A transiently failed part is signed and sent again; a sign answer that
  names a bucket or provider key is refused; with a journal a resend skips
  the parts already stored.

- `download(key, target, expectedSha256:)` checks the bytes before
  `target` is written (a resumed download is checked whole) and throws
  `BlobChecksumMismatch` otherwise; `sha256OfFile(file)` hashes in chunks.
- `S3BlobStore(partConcurrency: 3)`: the parts of one file go up three at a
  time (each holds `partBytes` in memory); resume and progress are
  unchanged.
- `BlobCache(directory:, store:, maxBytes:)`: `fetch(key, expectedSha256:)`
  downloads on demand into `directory` (two callers share one download),
  marks the file as used and drops the least recently used ones above
  `maxBytes`, never the file just fetched; `peek`, `remove`, `evictToFit`.

- Signed uploads send three parts at a time too
  (`SignedUploadClient(partConcurrency:)`, `uploadSignedParts(partConcurrency:)`):
  the source is read once, at most that many parts in memory, journal notes
  written one at a time; the first failure starts no new part and is
  rethrown.
- `BrowserTransferJournal(prefix:)` keeps the resume notes in
  `localStorage`, so a web upload resumes its missing parts after a reload
  (its constructor throws off the web; use `FileTransferJournal` there).
  `KeyValueTransferJournal(store)` is the same over any synchronous
  key-value store; a full or blocked store only means the upload starts
  over.
- Error messages: every `BlobStoreException` keeps its data and a reason
  (`BlobAccessReason`, `BlobTransientReason`); `messageIn(BlobStrings.en)`,
  `BlobStrings.fr` or the app's own `BlobStrings` give the text, `message`
  stays French.

Not yet: background transfers (Android/iOS).

## `flutter/shipglows_xml`

A small XML reader for untrusted documents, extracted from BeatGlows:
`parseSafeXml` builds a `SafeXmlNode` tree (`child`, `childrenNamed`,
`descendants`, `text`) and rejects every `<!` declaration but an optional
plain `DOCTYPE`, so entities are never expanded; `SafeXmlLimits` bounds size,
depth, node count and text. Used by `shipglows_storage` for S3 answers and by
BeatGlows for MusicXML and Guitar Pro.

## `flutter/shipglows_organize`

Folders, tags and search for business items, started from the CommandGlows
snippets. Storage stays in each app: an item only exposes a folder id and a
tag list. Status and due dates are not here (separate packages later).

- Tags: `normalizeTags` (string or list, `#` removed, lower case, no
  duplicate, `TagRules` limits), `normalizeTag`, `distinctTags`, `tagCounts`,
  `renameTag` (merges into an existing tag), `removeTag`.
- Folders: `Folder(id, name, parentId)`, flat or nested. `FolderTree` gives
  `children`, `path`, `label` (`Parent / Child`), `descendants`,
  `subtreeIds` (filter or cascading delete), and checks `checkName` (unique
  among siblings, ignoring case) and `checkMove` (no cycle) as a
  `FolderProblem`. Missing parents and stored cycles show at the root.
  Apps that store a folder name instead (CommandGlows snippets) use
  `normalizeFolderName` and `distinctFolderNames`.
- Search: `OrganizeQuery.parse` (`#term` prefixes a tag, other terms search
  the given fields or prefix a tag); `OrganizeFilter` (folders, tags with
  `TagMatch.all` or `.any`).
- Labels: `normalizeLabels` for free comma lists (keywords, topics) that keep
  their case and inner spaces, without duplicates (ignoring case).
- Sort: `sortedBy(items, key, direction: SortDirection.descending)`, stable,
  items with a `null` key last (dates, names, counts).
- Names: `nameKey` (`searchKey`, trimmed and single-spaced: one name
  whatever its case, accents or spaces), `compareNames` to sort by it,
  `checkNameAmong` for flat collections stored by name (playlists: empty or
  taken, as `FolderProblem`), `duplicateAliases` mapping the ids of items
  created twice under one name (two devices) to the smallest id kept.
- Text search: `searchKey` (lower case, no accents, `œ`/`æ` as `oe`/`ae`), `searchWords`,
  `matchesSearch(query, fields)` (every word in some field) and
  `rankBySearch(items, query, label:, fields:)` (label starting with the
  query, then label holding every word, then a match in the fields).

Used by CommandGlows (snippets), ContentGlows (History search with
`#tag` and date sort, keyword and topic lists), BeatGlows (library search
and sort, playlist names, artist and song merge after a sync) and the
ShipGlows app (command palette ranking, GitHub repository picker). Not
yet: manual folder order, tag colours, UI widgets.

## `flutter/shipglows_settings`

User settings (not business data), merged from CommandGlows (sync engine),
ContentGlows (offline queue, per-account cache, partial writes), BeatGlows
(atomic files, secrets apart) and DreamGlows (web storage, test isolation).

- Each setting is declared once as a `SettingKey` (id, type, default,
  `SettingScope.device` or `.account`). The id is the field name everywhere:
  device file, Firestore document, REST payload. Bad stored data reads as the
  default.
- `SettingsSchema(version:, migrations:)` upgrades stored values, device and
  remote, before use.
- `SettingsController.open(importLegacy:)` loads the device copy; on a fresh
  device it imports the old storage once (secure storage keys,
  SharedPreferences).
- `set`, `reset`, `edit` (batch): saved on the device before returning
  (throws `SettingsStorageException`), then only the changed fields are
  pushed. A pending field keeps its device value until the remote accepts it;
  every other field follows the remote.
- `setAccount(SettingsAccount(id:, remote:))`: one device copy per account,
  never mixed. The first sign-in on a device unites the signed-out values with
  the account's (`shipglows_sync`): a value set on one side only is kept;
  values set differently on both sides put the status in `needsReview` until
  `resolveReview(choices)`, and the device values stay in use meanwhile.
  `reviewFirstSync: false` keeps the former rule (the account replaces the
  signed-out values). `forgetAccount` deletes a copy and its recovery.
- Before applying a review, copies of both sides are saved as a
  `SyncRecovery` (bucket `recovery.account.<id>`, never sent);
  `restoreRecovery(side)` puts one back here and in the account,
  `dropRecovery` deletes them.
- `progress` (`SyncProgress`): steps of an account's first sync on this device
  (waiting, received, applied, ready), for `SyncProgressOverlay`.
- Retry: 30 s doubling to 5 min, on app resume and on `sync()`;
  `SettingsRemoteAuthException` stops until the account changes.
- Map settings (`SettingKey.map(id)`, `mergeFields` on by default): a change
  marks only the nested fields that differ, `setField(key, path, value)`
  edits one of them, the push sends a partial map (the remote deep-merges:
  Firestore `merge: true`, an API merge), and a pull keeps the pending nested
  fields while taking the others.
- Records created offline: `isTemporaryId` (`(id) => id.startsWith(
  'offline-')`) holds every pending field pointing at one; it is shown but
  not sent until `rewriteIds({tempId: serverId})`, which rewrites the stored
  values and sends them. The value helpers (`rewriteSyncIds`,
  `holdsTemporaryId`) live in `shipglows_sync` for data stores too.
- `status` (`SyncStatus`: also `unreachable` when the account was never read
  on this device), `listenable(key)` (notifies only for that key),
  `SettingBuilder`, `SettingSwitchTile`. The controller is a `SyncSource`,
  `SyncReviewHost` and `SyncRecoveryHost`: the sync widgets come from
  `shipglows_sync`.
- Storage ports: `FileSettingsStorage(directory)` (native, temp file then
  rename), `MemorySettingsStorage`, `CallbackSettingsStorage` (IndexedDB,
  SharedPreferences). Remote ports: `CallbackSettingsRemote` (REST client,
  blob store), `MemorySettingsRemote` (tests, two devices).
- Several windows (one Flutter engine each: command bar, quick capture):
  `FileSettingsStorage` is a `WatchableSettingsStorage`, so every
  controller on the same folder reloads a bucket another window wrote;
  `reload()` does it by hand for other storages. Fields pending in a window
  keep its value.
- Secrets never go in a `SettingKey`: `SecretStore` (`read`, `write`,
  `delete`, from BeatGlows) is the interface for the app's secure storage,
  plugged in with `CallbackSecretStore` over `flutter_secure_storage`;
  `MemorySecretStore` for tests. The app deletes the secrets a setting no
  longer needs (S3 keys when the storage choice leaves S3).

## `flutter/shipglows_settings_firestore`

`FirestoreSettingsRemote(document, decorate:)`: merged writes with a server
`updatedAt`, `null` deletes the field, live `snapshots()` without local
echoes, Timestamps read as ISO text, `permission-denied` mapped to
`SettingsRemoteAuthException`. `decorate` adds derived fields for security
rules.

## `flutter/shipglows_feedback`

In-app messages: info, success, warning, error. One look and one queue in
every app instead of each app's own SnackBars and toasts. Depends on
`shipglows_theme`. Not the Windows system toasts (see the desktop shell
audit, item 12).

- `showFeedback(context, message, kind:)`, or `context.showInfo` /
  `showSuccess` / `showWarning` / `showError`: a floating snack bar on
  `surfaceRaised` with a `border` outline, 480 wide on large windows. The
  icon in the kind's color (`accent`, `success`, `warning`, `danger`), the
  text in `text`, so the kind never rests on color alone.
- Defaults by kind: 4 s for info and success, 6 s for warning, 8 s with a
  close button for errors. Optional action (`actionLabel`, `onAction`): the
  message then stays until dismissed for assistive-technology users.
- Messages queue one after the other; `replaceCurrent: true` closes the one
  on screen first. The same text of the same kind, still queued or shown, is
  not queued again (a failing sync reporting each retry).
- Read as « Error: … » by a screen reader: `FeedbackStrings.en`, `.fr`
  (picked from the app locale) or the app's own (`copyWith`).
- After an await, read `FeedbackMessenger.of(context)` before it and show
  through it after (same queue, theme and texts, the widget may be gone).
  Never pass the `ScaffoldMessenger`'s own context to `feedbackSnackBar`:
  `MaterialApp` puts it above the theme, so the brand roles are lost.
- `showError(…, details: () => error.toString())` offers « Copy details »
  (beside the action when there is one), then confirms « Details copied ».
- Two actions: `secondaryActionLabel:` / `onSecondaryAction:` on
  `showFeedback`, `FeedbackMessenger.show` and `feedbackSnackBar`; a snack
  bar takes one `SnackBarAction`, so the second is a text button beside the
  message, which closes it too.
- `replaceCurrent: true` also skips the repeat check.
- `FeedbackInline(message:, kind:, title:, dense:, trailing:, actions:)`: a message in
  place (under a form, in a panel), tinted with its kind, announced when it
  appears. `FeedbackContent(liveRegion: true)` for the bare icon and text.
- `FeedbackErrorState(message:, title:, onRetry:, details:)`: what a screen
  shows when loading it failed, with « Retry » and « Copy details ».
  `compact: true` aligns it to the start with a smaller icon (a panel, a
  card); `helperText:` says what to do; `selectable: true` lets the message
  be copied by hand; `secondaryLabel:` / `onSecondary:` for a second
  action; `showIcon:`, `copyLabel:`.
- `FeedbackStringsScope(strings: FeedbackStrings.fr, child:)` in
  `MaterialApp.builder` sets the texts for the whole app (French apps
  without `flutter_localizations` read as English otherwise).
- `feedbackSnackBar(context, …, wrapContent:)` builds the same snack bar for
  code that shows it itself; `FeedbackContent` is the icon and text alone,
  for an app's own surface.
- `FeedbackLog.addListener` hears every message shown through
  `showFeedback` / `FeedbackMessenger` (repeats not queued are not heard),
  for a history: `FeedbackHistory` of `shipglows_notification_center`.
- Errors take `danger`, which the `ColorScheme` fallback sets to
  `scheme.error`: an app keeping red for emergencies sets its own.

```dart
context.showSuccess('Saved');
context.showError('Could not publish', actionLabel: 'Retry', onAction: publish);

final feedback = FeedbackMessenger.of(context);
try {
  await api.save();
  feedback.showSuccess('Saved');
} catch (error) {
  feedback.showError('Could not save', details: () => '$error');
}
```

## `flutter/shipglows_metrics`

Metrics dashboards: the same tiles, trends and layout in every app. Only
draws: the app fetches, computes and formats its values (currency, units,
locale) and hands them over. Depends on `shipglows_theme` and
`shipglows_icons`.

- `Metric(label:, value:, delta:, series:, caption:)`: one value, already
  formatted (« 1 240 € »), its change and its recent values, oldest first.
- `MetricDelta(0.12, polarity:, label:)`: the change as a fraction.
  `MetricPolarity.higherIsBetter` (default), `lowerIsBetter` (load time,
  churn) or `neutral` decides the color; under `flatThreshold` (0.5 %) it
  counts as unchanged. `label` replaces the default « +12 % ».
- `MetricTile(metric, onTap:)`: label, value in `fontDisplay` with tabular
  figures, `MetricDeltaBadge`, caption and sparkline on `surfaceRaised` with
  a `border` outline. Read as one sentence (« Revenue, 1 240 €, up 12 %,
  vs. last week »). `MetricTile.loading(label:)`, `.empty(label:, message:)`
  and `.error(label:, message:, onRetry:)` keep the label and the value
  line's height, so the dashboard does not jump when data arrives. Every
  state takes an optional `icon:` before the label (decorative, in `icon`
  or the app's own `iconColor:`; the value stays in `text`). ContentGlows'
  Search Console cards use it.
- `MetricDeltaBadge(delta)`: arrow and signed text in a pill, `success` when
  good, `danger` when bad, `textMuted` when neither, so the trend never
  rests on color alone. New base icons `trendUp`, `trendDown`, `trendFlat`.
- `MetricSparkline(values, color:)`: a small line with a faint area under
  it, decorative (no semantics); nothing under two values. In a tile it
  takes the badge's color.
- `MetricGrid(children:, minTileWidth: 220, maxColumns: 4)`: equal columns,
  as many as fit, the tiles of a row as tall as the tallest; one column on a
  phone. Its children must not use `LayoutBuilder` (rows are measured with
  `IntrinsicHeight`).
- `MetricSection(title:, trailing:, child:)`: a heading, a control on its
  right (under it below 480 wide), then the grid.
- `MetricPeriodSelector(periods: [MetricPeriod(value, '7 j'), …], selected:,
  onChanged:)`: the periods as a segmented button, `highlight` on the
  selected one.
- `MetricDelta.between(current, previous)`: the change computed, never
  NaN; from 0 it reads +100 % (or −100 %, or 0 when both are 0).
- `Metric(points: [MetricPoint(day, value), …])`: dated values drawn by
  `MetricSparkline.points`, spaced by date; a null value is a gap that
  breaks the line. Hover or touch shows the nearest point (`describe:` for
  its text). Takes precedence over `series`.
- `MetricTile(…, density: MetricTileDensity.compact)`: smaller padding,
  value and sparkline, no caption on screen (still read).
- `MetricBarList(items: [MetricBarItem(label:, value:, valueLabel:)], …)`:
  labelled horizontal bars (a funnel, content by type, top pages);
  `labelWidth:` puts labels in a column from 480 wide, `sort:`, `maxItems:`,
  `maxValue:`; rows with `onTap` are buttons. Tracks in `border`.
- `MetricProgressBar(target: MetricTarget(value: 3, target: 5))` and
  `MetricProgressTile(label:, target:, caption:)`: « 3 of 5 », the fill turns
  `success` once reached.
- `MetricSection(subtitle:, freshness: MetricFreshness(source:, updatedAt:,
  stale:, partial:))`: a muted line « Google Search Console · Updated 2 h
  ago » with « Stale » and « Partial data » badges (`MetricFreshnessLine`
  alone elsewhere).
- `MetricFormat.of(context)`: `integer` (« 1 240 »), `decimal`, `compact`
  (« 1.2k », « 2,5M »), `percent(signed:)` and `duration` (« 2 min 5 s »),
  with the separators, minus sign and units of `MetricStrings`.
- `MetricStrings.en`, `.fr` (picked from the app locale) or the app's own;
  `MetricStringsScope` in `MaterialApp.builder` for the whole app.

```dart
MetricSection(
  title: 'Activité',
  trailing: MetricPeriodSelector(
    periods: const [MetricPeriod(7, '7 j'), MetricPeriod(30, '30 j')],
    selected: days,
    onChanged: setDays,
  ),
  child: MetricGrid(children: [
    MetricTile(Metric(
      label: 'Revenus',
      value: '1 240 €',
      delta: const MetricDelta(0.12),
      series: revenueByDay,
      caption: 'vs. 7 jours précédents',
    )),
    const MetricTile(Metric(
      label: 'Temps de chargement',
      value: '1,2 s',
      delta: MetricDelta(-0.08, polarity: MetricPolarity.lowerIsBetter),
    )),
    const MetricTile.loading(label: 'Utilisateurs actifs'),
  ]),
)
```

## `flutter/shipglows_notification_center`

The notification center: the latest lasting notifications (a new replay, a
comment, a reminder), read or unread, distinct from the passing messages of
`shipglows_feedback`. Depends on `shipglows_feedback`, `shipglows_icons`
and `shipglows_theme`, plus `flutter_local_notifications` and `timezone`
for the daily reminders; stores nothing itself.

- `NotificationStore` is the port the app plugs in, like the settings
  storage: `watch()` (newest first, again on every change), `refresh()`
  after an error, `markRead`, `markAllRead(ids)`, `delete`, `deleteAll(ids)`
  with `canDelete` / `canDeleteAll`, and `hasMore` / `loadMore()` for older
  pages (the longer list comes back through `watch()`).
  `CallbackNotificationStore` wraps an existing client (without `delete`
  the delete buttons and « Delete all » are hidden; without `deleteAll` it
  deletes one by one; without `loadMore` the list is one page);
  `MemoryNotificationStore` for tests, demos and device-only logs.
- `NotificationItem(id, title, body, createdAt, read, icon, kind,
  source, count, payload)`: the app maps its own record to it and gets it
  back in `payload` on « open »; `kind` (a `FeedbackKind`) tints the icon;
  `source` (an account, a channel) shows over the title; `count` stands for
  a live counter row (« 12 new »).
- `NotificationCenterController(store:)`: list, loading, error,
  `unreadCount`; read and delete show at once and come back when the store
  fails; `retry()`. Filters `unreadOnly` and `source` (`sources` lists
  them); `unreadCount` ignores the filters (the badge), the global actions
  work on the `items` shown. `hasMore`, `loadingMore` and `loadMore()`
  (one page at a time, until the store's next list). One per screen or
  panel, disposed with it.
- `NotificationCenterView(controller:, onOpen:, leadingBuilder:)`: the
  body: rows with the type's icon in a tinted circle (or the app's
  thumbnail through `leadingBuilder`, given the icon as fallback), the
  title bold when unread, the body, « 3 min ago » refreshed every minute
  (the medium date after four weeks, `formatDate:`), an unread dot, a
  44 px delete button. Over the list « 3 unread » / « All caught up »,
  announced on change. Opening marks read first. Empty state (`empty`,
  `emptyDescription`), `FeedbackErrorState` when loading fails (an inline
  error over a list already shown). `showToolbar: true` puts the summary
  and the actions over the list, for a panel without an app bar;
  `showFilters` (on by default) adds « Unread only » and, with several
  sources, one chip per source (from the CommunityGlows center). While
  the store `hasMore`, the list ends with a loader (`loadingMore` text)
  that asks for the next page once scrolled into view; a failure reaches
  `onError:` as `NotificationOperation.loadMore`.
- `NotificationCenterActions(controller:)`: « Mark all as read » and, when
  the store can, « Delete all » in a menu, confirmed (`confirm:` for the
  app's own dialog). Failed actions show an error message with « Copy
  details »; `onError:` (on the view and the actions) hears every failure
  for the app's log, the background read mark of an opened one included.
- `NotificationBadge(count:, child:)` (hidden at 0, « 99+ ») and
  `NotificationBellButton(count:, onPressed:)`, read « Notifications, 3
  unread notifications ».
- `FeedbackHistory()..attach()`: a store of the in-app messages already
  shown (`FeedbackLog` of `shipglows_feedback`), errors unread, their
  details as the body: a « Recent messages » center to see again an error
  that went by too fast.
- Texts: `NotificationStrings.en`, `.fr` (from the app locale), `copyWith`,
  `NotificationStringsScope` for the whole app.

```dart
final controller = NotificationCenterController(
  store: CallbackNotificationStore(
    watch: () => api.notifications().map((rows) => [
      for (final row in rows)
        NotificationItem(id: row.id, title: row.title,
            createdAt: row.createdAt, read: row.read, payload: row),
    ]),
    markRead: api.markRead,
    markAllRead: (_) => api.markAllRead(),
  ),
);

Scaffold(
  appBar: AppBar(actions: [NotificationCenterActions(controller: controller)]),
  body: NotificationCenterView(
    controller: controller,
    onOpen: (item) => open(item.payload! as Row),
  ),
);
```

### Daily reminders

System notifications (a Windows toast, an Android notification) at the
times the person chose, even while the app is closed. Off by default. Used by
DreamGlows (settings « Rappels »).

- `DailyReminderPlan(enabled:, times:)`: one to three `ReminderTime`s a
  day, sorted, the same every day; `withTime`, `withoutTime`, `replacing`;
  `toJson` / `fromJson` for the app's settings. No streak and no catching
  up: a missed reminder is gone. `upcoming(from, days:)` lists the next
  ones in local time, computed per calendar day (daylight saving never
  shifts them).
- `ReminderScheduler`: `isSupported`, `requestPermission()`,
  `replaceAll(reminders)`. `LocalReminderScheduler(LocalReminderConfig(…))`
  over `flutter_local_notifications` on Windows and Android (elsewhere
  unsupported); `MemoryReminderScheduler` for tests. Windows cannot repeat
  a notification, so each one is planned on its own over the next days
  (7 by default) and planned again at every launch. It owns ids `firstId`
  to `firstId + maxReminders - 1` only. On Android the alarms are inexact
  (no exact-alarm permission): a reminder may come a few minutes late.
- `DailyReminders(scheduler:, load:, save:, content:)`: `start()` once the
  app runs, `update(plan)` from the settings. Turning reminders on asks
  the system first (Android 13+); a refusal leaves them off with
  `permissionDenied`. `content(time)` gives title, body and payload.
- `DailyReminderSettings(reminders:, strings: ReminderStrings.fr)`: a
  switch, the times as chips (tap to change with the time picker, × to
  remove the extra ones), « Add a time » while under three.
- The app declares, once: for Windows, an `appUserModelId` and a GUID of
  its own (registered for the current user, no MSIX needed); for Android,
  core library desugaring in `build.gradle.kts`
  (`isCoreLibraryDesugaringEnabled = true`, `coreLibraryDesugaring(
  "com.android.tools:desugar_jdk_libs:2.1.5")`) and, in the manifest,
  `RECEIVE_BOOT_COMPLETED` with the plugin's `ScheduledNotificationReceiver`
  and `ScheduledNotificationBootReceiver` (see the plugin's README).

```dart
final reminders = DailyReminders(
  scheduler: LocalReminderScheduler(const LocalReminderConfig(
    appName: 'DreamGlows',
    windowsAppUserModelId: 'ShipGlows.DreamGlows',
    windowsGuid: '…',
    androidChannelId: 'dreamglows_reminders',
    androidChannelName: 'Rappels',
  )),
  load: settings.loadReminders,
  save: settings.saveReminders,
  content: (time) => (title: 'DreamGlows', body: 'Ton prochain pas ?', payload: null),
)..start();

DailyReminderSettings(reminders: reminders, strings: ReminderStrings.fr);
```

## `flutter/shipglows_undo_trash`

Undo, redo and trash, extracted from ContentGlows. Depends on
`shipglows_feedback` for its snack bar.

- `UndoRedoHistory<T>`: undo/redo stacks of snapshots for an editor. `record(before)`
  before each change (clears redo), `undo(current)` / `redo(current)` return
  the step to restore, `pop()` for an undo-only history. `group(before,
  change, changed:)` folds a batch (an AI pass) into one step, and records
  nothing when `changed` says it was a no-op. Capped at `limit` (oldest
  dropped); optional labels for « Undo: … » tooltips; a `ChangeNotifier`.
- `UndoCommandStack<T>`: a bounded stack of compensating commands for an app
  that keeps both events instead of rewriting history. `push(command, label:)`
  returns the `UndoCommandEntry` kept (oldest dropped past `limit`); `latest`
  and `popLatest()` serve Ctrl/⌘+Z; `remove(entry)` takes a specific one (its
  own « Undo » message); `clear()`. It only orders the entries: the caller runs
  the commands and checks whether a change is still undoable. Undo-only, no
  redo; a `ChangeNotifier`.
- `UndoShortcuts`: Ctrl/⌘+Z undoes, Ctrl/⌘+Shift+Z (and Ctrl+Y off Apple)
  redoes for the subtree; keys typed in a text field stay its own
  (`isTextInputFocused()`), disabled actions let the key through. A command
  bar calls the same handlers directly.
- `PendingUndo`: an action shown at once whose lasting part (`onCommit`: a
  server call) waits for the « Undo » window. Settles exactly once, undo or
  commit; commit errors go to `onError`.
- `UndoWindow<K>`: a screen's open windows by item. `start(key, commit:)`
  hides the item (`isHidden`), `undoLast()` for Ctrl/⌘+Z,
  `flush()` commits everything (app backgrounded). `keepHiddenAfterCommit`
  avoids a flicker while the list reloads; a failed commit shows it again.
  Commits still run once the screen is gone.
- `showUndoSnackBar(context, message:, pending:)`: the shared message snack
  bar (`feedbackSnackBar`, info by default, `kind:` to change) with « Undo »
  (persists for assistive-technology users); `attachUndoSnackBar`
  ties a `PendingUndo` to the app's own toast instead (closing commits),
  with its content wrapped in `UndoSnackBarContent` so undoing elsewhere
  closes that toast, never another message it was queued behind.
- `TrashView<T>`: trash screen body inside the app's scaffold. `entryOf` maps
  an item to a `TrashEntry` (title, deletion and purge dates, `purging`);
  search with accents folded, `TrashFilter`s, restore, delete permanently and
  empty the trash (confirmed through `confirm`, an `AlertDialog` by default),
  a spinner per row, errors to `onError`. Most recent first; the subtitle
  turns red `warnDays` before the purge. Texts: `TrashStrings.en`, `.fr`, or
  the app's own (`copyWith`).

```dart
final window = UndoWindow<String>();

void trash(Item item) {
  final pending = window.start(
    item.id,
    commit: () => api.trash(item.id),
    keepHiddenAfterCommit: true,
  );
  showUndoSnackBar(context, message: 'Moved to trash', pending: pending);
}
```

## `flutter/shipglows_guide`

In-app guidance: guided tours across screens, coach marks on a precise
widget (spotlight, « this control is for… », « try it »), one-step tips,
shown on a screen's first visit and replayable. Extracted from the
ContentGlows guided tour. No dependency besides Flutter: routing, storage and
translations are the app's, passed as callbacks. Not the first-launch
onboarding (`shipglows_onboarding`).

### Tours and steps

```dart
const videosTour = GuideTour(
  id: 'videos.intro',
  steps: [
    GuideStep(
      id: 'filter',
      targetId: 'videos.filter',          // a GuideTarget on screen
      route: '/videos',                   // opened when the step starts
      title: 'guide.videos.filterTitle',  // text or translation key
      body: 'guide.videos.filterBody',
      hint: 'guide.videos.filterHint',    // optional call to action
    ),
    GuideStep(
      id: 'play',
      targetId: 'videos.play',
      advanceOnTargetTap: true,           // « try it »: tapping moves on
      title: '…',
      body: '…',
    ),
  ],
);
```

- `GuideStep.targetId`: the step points at that `GuideTarget`; a ring and a
  pulsing halo mark it (still under reduce-motion). The card sits below it,
  else above, else beside it, never over it; it is measured, kept inside the
  safe area and scrolls when taller than the screen, so it is never cut. The
  target is scrolled into view and tracked while it moves. A target not on screen (narrow layout, offstage
  tab) leaves the card floating at the bottom center.
- `spotlight` (default on): dims the rest of the screen and absorbs taps
  there; the target stays usable. Off: a ring around the target only, the
  screen keeps working.
- `advanceOnTargetTap`: the card says « Try it » and the target's own tap
  (its action runs first) moves to the next step.
- `route` / `routeLabel`: the controller opens the route when the step
  starts; if the user leaves it, the card offers « Open {routeLabel} ».
- A tour of one step is a tip: « Tip » header, no progress, « Got it » and
  the close button end it for good.
- The card can be dragged anywhere (kept on screen), reset at each step.

### Controller

```dart
final guide = GuideController(
  tours: [videosTour],
  store: CallbackGuideStore(
    onRead: (id) async => GuideProgress.decode(
      (await SharedPreferences.getInstance()).getString('guide:$id')),
    onWrite: (id, p) async =>
      (await SharedPreferences.getInstance()).setString('guide:$id', p.encode()),
  ),
  navigate: (route) => router.go(route),
  location: () => router.routerDelegate.currentConfiguration.uri.path,
);
```

One per app (a Riverpod `Provider` with `ref.onDispose(guide.dispose)`).
It is a `ChangeNotifier`: a settings row rebuilds with `ListenableBuilder`.

- `start(id, {step})`, `resume(id)` (where the user left it, from the start
  once completed), `pause()` (resumable), `skip()` (completed), `next()`,
  `previous()`, `openStepRoute()`.
- `startIfFirstVisit(id)`: starts a tour never shown, unless another runs.
- `reset(id)` / `resetAll()`: « Show tips again ».
- `progressOf(id)` (after `load(id)`): `stepIndex`, `started`, `completed`.
- A tour is never resumed on its own at startup.
- `store`: `MemoryGuideStore` by default; `CallbackGuideStore` for the
  app's storage (`GuideProgress.encode` / `decode` for one string per tour).

### Widgets

```dart
GuideScope(                       // around the shell, under the navigator
  controller: guide,
  strings: GuideStrings.forLocale(Localizations.localeOf(context)),
  resolveText: (context, key) => t(key, locale: appLocale(context)),
  child: shell,
)

GuideTrigger(tourId: 'videos.intro', child: VideosScreen())  // first visit
GuideTarget(id: 'videos.filter', child: IconButton(...))      // pointable
```

- `GuideScope.navigate` / `location`: context-based routing
  (`(context, route) => context.go(route)`) for an app whose controller has
  no `navigate` of its own; used while the scope is mounted. A tour started
  outside the shell (onboarding) opens its first route itself:
  `context.go(guide.activeStep?.route ?? '/home')`.
- `GuideScope.of(context)` / `maybeOf`: the controller, for a « Replay the
  tour » button inside the shell.
- `GuideTrigger.enabled: false` while the screen is not ready (loading); it
  fires when it turns on, after `delay` (600 ms), and only while its screen
  is shown (an offstage tab waits).
- `GuideTarget` ids are unique among mounted screens.

### Texts, look, accessibility

- Card texts: `GuideStrings.en`, `.fr`, `forLocale(locale)` or the app's
  own (`{current}`, `{total}`, `{screen}` are filled in). Step texts go
  through `resolveText`.
- Look: `GuideThemeData` theme extension (accent, surface, scrim, max width,
  radii, spotlight padding, bottom offset of a floating card), every value
  falls back on the `ColorScheme`.
- Accessibility: the card is a live region (read when a step changes), the
  primary button takes focus, Esc pauses (closes a tip), every button is
  44 px at least, icons are excluded from semantics, reduce-motion turns the
  card's entrance and the scroll to the target off.

## `flutter/shipglows_onboarding`

First-run introduction: one fixed two-column card (texts and actions on the
left, a preview on the right) under a segmented progress bar, shown once per
account and replayable. Extracted from the ReplayGlows introduction. A
teaser of what the app does, not a walkthrough of its controls (that is
`shipglows_guide`). No dependency besides Flutter and `shipglows_theme`:
texts, previews, storage and the signed-in account are the app's.

- `OnboardingPage`: `title` (null when the `body` brings its own heading,
  like an embedded sign-in form), optional `eyebrow`, `leading` (icon badge, before the title on its line),
  `description` (`descriptionLines` keeps a series aligned), `note` (italic
  word from the maker), `body` (status, links), `preview` builder.
  `centered` for feature pages, `scrollable` for a page whose body grows,
  `showBack` / `showSkip`, `showPrimary` (off when the body owns the way
  forward: a sign-in form, a start-trial panel), `primaryLabel` /
  `primaryArrow`.
- `OnboardingLanguagePage`: first page, one button per
  `OnboardingLanguageOption` (label and greeting in its own language), a
  specimen of the greetings as preview; picking one moves on.
- `OnboardingThemePage`: its twin for the theme, one button per
  `OnboardingThemeOption` (`ThemeMode` and label), small light, dark and
  system windows as preview; picking one moves on.
- `OnboardingStatements`: labelled statements (mission, vision, goal) for a
  page `body`, with `scrollable: true`.
- `OnboardingFlow(pages:, strings:, onFinish:)`: Skip jumps to the last page,
  done segments of the progress bar go back, focus follows the title. Pages
  can be rebuilt (new language, a status that loads): the current one is kept
  by index. Below `narrowWidth` the card is one scrolling column without
  preview. With `index:` the app owns the page (the introduction wraps
  sign-in and access, CommandGlows): every move is asked through
  `onIndexChanged` and the app answers with a new `index`;
  `progressNavigation: false` keeps done segments still. Stable keys for
  tests: `onboarding-primary`, `onboarding-finish` (last page),
  `onboarding-back`, `onboarding-skip`, `onboarding-language-<code>`.
- `OnboardingGate`: due once per `setScope(userId)` and `version`
  (`onboarding_completed:v1:<user>`), `complete()`, `replay()` for
  Preferences. Signed out (null scope) never shows it. Keys go through an
  `OnboardingCompletionStore` (`Memory…`, `Callback…` for
  `SharedPreferences`).
- `OnboardingOverlay(pending:, introduction:, child:)` from
  `MaterialApp.builder`.
- Texts: `OnboardingStrings.en`, `.fr`, or the app's own.
- Look: `OnboardingThemeData` theme extension (title, description, eyebrow,
  skip and specimen styles merged onto the defaults, `progressGradient`,
  card color, border and shadows, radii, card size, motion); fallbacks from `ShipglowsTheme`. Motion is off
  when the platform asks to reduce it.

```dart
OnboardingFlow(
  strings: OnboardingStrings.forLocale(locale),
  onFinish: gate.complete,
  pages: [
    OnboardingLanguagePage(
      id: 'language',
      title: 'Choose your language',
      options: const [
        OnboardingLanguageOption(
            locale: Locale('fr'), label: 'Français', greeting: 'Bonjour'),
        OnboardingLanguageOption(
            locale: Locale('en'), label: 'English', greeting: 'Hello'),
      ],
      onSelected: setLocale,
    ),
    OnboardingPage(
      id: 'welcome',
      title: 'Welcome',
      description: '…',
      preview: (_) => const AppMark(),
      showBack: false,
      primaryLabel: 'Get started',
    ),
    // one page per feature, then the access summary
  ],
)
```


## `flutter/shipglows_calendar`

One calendar for every app. Each app keeps its own data (actions, posts,
habits…) and converts it to `CalendarEvent`s; the package draws them and
reports what the user does. It stores nothing.

- `CalendarEvent(id:, title:, start:, end:, allDay:, description:, colorKey:)`:
  all-day events take civil days (`end` included), the others instants; no
  `end` draws a marker. Events with the same `colorKey` share a palette
  color. `canMove` / `canResize` lock them.
- `CalendarTimeZone`: how instants become days and hours.
  `CalendarTimeZone.device` follows the device; an app showing an IANA zone
  implements the four methods with its own database (the package ships
  none). Days of 23 or 25 hours are drawn as they are.
- `ShipglowsCalendar(events:, date:, onDateChanged:)`: toolbar (today,
  previous, next, period title opening a date picker, view switch, your
  `toolbarActions`) and the day, week, month or agenda view, sliding to the
  next period. Below `agendaBreakpoint` (700) the day and week views become
  the agenda. `header` sits between the toolbar and the view,
  `panelBuilder` draws the surface under it.
- Moves and resizes are proposals: `onEventDropped(CalendarDrop(event, day,
  instant))` (instant when dropped on an hour, snapped to `snapMinutes`,
  15 by default; the grid shows where it lands while dragging),
  `onEventResized(event, end)`, `onSlotDoubleTap(instant)`, `onEventEdit`.
  The app saves, asks or refuses.
- Building blocks for other layouts: `CalendarToolbar`, `CalendarTimeGrid`,
  `CalendarMonthView` (`compact: true` shows only day numbers and counts,
  for phones), `CalendarDayStrip` (one week of compact days),
  `CalendarDayCell`, `CalendarMiniMonth`, `CalendarAgenda`,
  `CalendarEventCard`. Their drop targets accept `Draggable<CalendarEvent>`,
  so the app's own list tiles can be dragged onto a day.
- Dates: `calendarDay`, `calendarAddDays`, `calendarSameDay`,
  `calendarShift(view, date, step)`, `CalendarRange.of(view, date)`,
  `.week`, `.month`. `parseCivilDate('2026-10-18')` reads a `YYYY-MM-DD`
  day (null otherwise).
- `CalendarDateField(label:, value:, onChanged:)`: the form field for any
  date the user enters, never a `YYYY-MM-DD` text field. One wheel per part
  (day, month, year; hour and minute with `withTime: true`) rolls with the
  mouse wheel, a mouse drag or a finger; the calendar icon on the right
  opens the date picker (then the time picker). Chips under it pick
  quickly: today, tomorrow, the day after, in a week, in a month; with the
  time, in 1 h, in 3 h, tomorrow 09:00, in a week. They count from `now`,
  the wall time in the app's zone (the device's by default), and roll the
  wheels to the date; `quickPicks: false` hides them. The value is a civil
  day at UTC midnight, or a wall time on UTC fields; a null `value` dims
  the wheels on `initialDate`. `firstDate` / `lastDate` bound the year
  wheel and the picker; a 31 on a 30-day month rolls back to the 30th.
- Texts: `CalendarStrings.fr`, `.en`, `forLocale(locale)`, `copyWith`.
  Short labels in the same language: `shortDay(day)` « sam. 18 oct. »,
  `shortDateTime(date)` « sam. 18 oct. à 14:05 », `shortRange(start, end)`
  « 12 – 18 oct. » (the year appears only outside `reference`, today by
  default), `longDateTime(date)` « lundi 26 octobre 2026 à 09:00 ».
  Sizes: `CalendarMetrics` (`const CalendarMetrics(hourHeight: 48)`).
- Colors come from `ShipglowsTheme` and the `ColorScheme`; reduced motion
  turns the slide off.

```dart
ShipglowsCalendar(
  events: [for (final task in tasks) task.toCalendarEvent()],
  date: date,
  onDateChanged: (day) => setState(() => date = day),
  timeZone: CalendarTimeZone.device,
  strings: CalendarStrings.forLocale(Localizations.localeOf(context)),
  selectedEventId: selected,
  onEventTap: (event) => setState(() => selected = event.id),
  onEventEdit: (event) => openEditor(event.id),
  onEventDropped: (drop) => reschedule(drop.event.id, drop.day, drop.instant),
)
```

## `flutter/shipglows_reviews`

Customer reviews, the same on Android, iOS, macOS, Windows and the web:
asking at the right moment, the app's own review form sent to its backend,
the public rating page and the settings rows. Depends on `in_app_review`,
`package_info_plus`, `path_provider`, `url_launcher`, `web`,
`shipglows_settings` (device state), `shipglows_feedback`, `shipglows_theme`
and `shipglows_icons`.

- `ShipglowsReviews.open(config: ShipglowsReviewsConfig(appId:, appStoreId:,
  microsoftStoreId:, playStoreListed:, reviewSite:, policy:), sink:)` once
  at startup; never throws. Counts launches, reads the install (Google Play,
  App Store, TestFlight, direct installer or APK, web), sends the reviews
  left unsent. The state lives in the app support folder
  (`%APPDATA%\<company>\<app>\shipglows.reviews.json` on Windows), in
  `localStorage` on the web, or in any `SettingsStorage` given.
- `maybeAskForReview(context, appName:)` at a natural break: the store's
  rating prompt on Google Play and App Store installs; elsewhere (Windows,
  the web, APKs) the app's invitation « Donner mon avis » / « Noter sur
  {page} » / « Plus tard » / « Ne plus me demander »
  (`showShipglowsReviewInvitation` on demand, `inviteWithoutStorePrompt`).
  The `ReviewPolicy` asks only after 7 days, 5 launches and 3 successes
  since the last prompt, never within 3 days of an error or 30 of a form
  review, 120 days apart, 3 a year, once per version, never again after
  rating or « Ne plus me demander ». Never in debug builds
  (`promptInDebug`). `eligibility` says why it waits. With `followFeedback`
  (default) every `shipglows_feedback` success counts as a positive moment
  and every error as a problem.
- Form: `showShipglowsReviewForm(context, reviews:, appName:, topic:)` (a
  bottom sheet on compact windows, a dialog otherwise): stars, topic
  (praise, idea, problem, other), message, optional address, consent to
  publish as a testimonial with an optional display name, a note on what is
  sent. Ctrl+Enter sends from any field. The thank-you offers the public
  page to everyone, whatever the rating: stores and review sites forbid
  sending only happy people to rate.
- Public page (`ratingPage`, `openRatingPage()`): the store page (Google
  Play, App Store, Microsoft Store), or else the `ReviewSite` (Trustpilot,
  Google reviews…) for the WinSparkle Windows builds and the web.
- `ShipglowsReviewSettings(reviews:, appName:)`: « Donner mon avis » (with
  the reviews waiting offline) and « Noter {app} ». `ShipglowsStarRating`
  alone. `ShipglowsReviewStrings.fr` / `.en`, `ShipglowsReviewStringsScope`.
- Backend: a `ReviewSink` (`CallbackReviewSink` over a Convex mutation, a
  Firestore collection, a REST call). `CustomerReview.toJson()` is plain
  JSON with a device-made `id` for deduplication; no device id, no IP.
  Unsent reviews stay on the device, retried 30 s doubling to 5 min, on
  resume and at the next launch; `ReviewRejectedException` drops one.
  Platform table, field table and Convex example in
  `flutter/shipglows_reviews/README.md`; a Windows and web playground in
  `flutter/shipglows_reviews/example`.

```dart
final reviews = await ShipglowsReviews.open(
  config: const ShipglowsReviewsConfig(
    appId: 'commandglows',
    reviewSite: ReviewSite(name: 'Trustpilot', url: 'https://…'),
  ),
  sink: CallbackReviewSink(
    (review) => convex.mutation('reviews:submit', review.toJson()),
  ),
);
unawaited(reviews.maybeAskForReview(context, appName: 'CommandGlows'));
showShipglowsReviewForm(context, reviews: reviews, appName: 'CommandGlows');
```

## `flutter/shipglows_contact`

« Contact us » without a backend: one button opening a list of channels
(WhatsApp, Messenger, Instagram, Telegram, email, phone, SMS, any link), each
launched through its deeplink. No inbox, no CRM, no network call. A channel
with no handler on the device (`tel:` or `sms:` on a desktop, say) copies its
value and says so through `shipglows_feedback`, which needs a
`ScaffoldMessenger`. Depends on `url_launcher`, `shipglows_feedback`,
`shipglows_icons` and `shipglows_theme`.

- `ContactChannel.whatsApp(phone, message:)`, `.messenger(page)`,
  `.instagram(username)`, `.telegram(username)`, `.email(address, subject:,
  body:)`, `.phone(number)`, `.sms(number, body:)`, `.link(url, label:)`:
  the `uri` is computed (`%20` for spaces, `@` stripped from handles, a
  pasted profile link reduced to its handle), `displayValue` is the
  address, number or handle shown under the label. WhatsApp needs an
  international number (`+33…` or `0033…`; asserted in debug).
- `ShipglowsContactConfig(channels:, title:, intro:)`: the channels in
  display order.
- `ShipglowsContactButton(config:, extended:)`: a floating button for
  `Scaffold.floatingActionButton`; opens `showShipglowsContactSheet(context,
  config:)` (a bottom sheet on compact windows, a dialog otherwise).
- `ShipglowsContactList(config:, onSelected:)`: the rows alone, for a settings
  or about page.
- `openContactChannel(context, channel, launcher:)`: external application by
  default (`ContactLauncher`, injectable). Never throws.
- `ShipglowsContactStrings.fr` / `.en`, `ShipglowsContactStringsScope`.

```dart
ShipglowsContactButton(
  config: ShipglowsContactConfig(
    channels: [
      ContactChannel.whatsApp('+33 6 12 34 56 78'),
      ContactChannel.email('hello@example.com', subject: 'Support'),
    ],
  ),
);
```

## `flutter/shipglows_demo`

The demo-mode surfaces every app shows the same way. Each app keeps its own
demo data (a seeded workspace, sample entities…) and decides what leaving
the demo or creating an account does; the package only draws and asks.

- `DemoBanner(title:, message:, action:)`: panel saying the data is a
  sample, with an optional button below.
- `DemoExitButton(onPressed:)`: « Sortir du mode démo ».
- `showDemoExitDialog(context)`: confirm leaving the demo, true once
  confirmed.
- `showDemoAccountDialog(context, action:)`: an action the demo cannot run;
  true when the person chooses to create an account.
- Texts: `DemoStrings.fr`, `.en`, `copyWith`, once for the app with
  `DemoStringsScope` or per widget with `strings:`.
- Colors come from `ShipglowsTheme`.

```dart
if (await showDemoExitDialog(context)) await repository.exitDemoMode();
```

## `flutter/shipglows_clerk_auth`

Clerk sign-in for native apps (Android, Windows), without the Clerk Flutter
SDK (still beta). OpenID Connect, Authorization Code + PKCE (S256), through
the system browser: a Custom Tab on Android, the default browser with a
loopback listener on Windows (RFC 8252, no embedded webview).

- One Clerk application per product, one **public** OAuth client in it (no
  secret, « Require PKCE » on, consent screen off), with exactly these
  redirect URIs: `<scheme>://oauth/clerk` and
  `http://localhost:<port>/callback`. The scheme is reverse-DNS and
  lowercase, usually the Android application id; `_` is not allowed in a
  scheme, so drop it when the id has one.
- `ClerkAuthConfig.fromEnvironment(androidScheme:, desktopPort:)` reads
  `CLERK_OIDC_ISSUER` (the instance's Frontend API URL) and
  `CLERK_OIDC_CLIENT_ID` from `--dart-define`; both are public values.
- `ClerkAuthClient`: `restore()` once at launch, `signIn()`,
  `accessToken()` (refreshed shortly before expiry, one refresh at a time),
  `signOut()` (revokes the refresh token, forgets the session); `session`
  is a `ValueListenable` for the UI. A revoked session is forgotten; offline,
  the stored one is kept.
- The session lives in secure storage (Keystore on Android, DPAPI on
  Windows), one entry per OAuth client; `MemoryClerkSessionStore` for tests.
- Every failure is a `ClerkAuthException` with a stable `code`
  (`canceled`, `invalid_grant` → sign in again, `network`…), never a token.
- Signing out does not sign the browser out of Clerk: the next sign-in may
  complete at once with the same account.

Android: the app declares the callback activity of `flutter_web_auth_2` in
its `AndroidManifest.xml`, with its scheme:

```xml
<activity android:name="com.linusu.flutter_web_auth_2.CallbackActivity"
    android:exported="true" android:taskAffinity="">
  <intent-filter android:label="flutter_web_auth_2">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="com.example.app" />
  </intent-filter>
</activity>
```

```dart
final clerk = ClerkAuthClient(
  config: ClerkAuthConfig.fromEnvironment(
    androidScheme: 'com.example.app',
    desktopPort: 47821,
  ),
);
await clerk.restore();
final token = await clerk.accessToken(); // Bearer for the product backend
```

Schemes and desktop ports in use: CommandGlows `com.commandglows.app` 47821,
ShipGlows app `com.shipglows.app` 47822, GoCharbon `fr.gocharbon.quiz`
47823, ReplayGlows `com.replayglows.app` 47824, ContentGlows
`com.contentglows.app` 47825. The Clerk applications and client ids are listed
in CommandGlows `shipglows_data/workflow/docs/technical/suite-authentication.md`.

## `flutter/shipglows_convex`

Convex HTTP client for the native apps (Android, Windows), used instead of
Firestore where an app runs on Convex. No Convex SDK, no codegen:
`ConvexHttpClient` calls `/api/query`, `/api/mutation` and `/api/action`, and
uploads files to Convex storage, with `Authorization: Bearer` from a `token`
callback (for Clerk, `ClerkAuthClient.accessToken`).

- `ConvexException.code` is stable: `unauthenticated` (retried once after the
  token runs again), `convex_error` (payload in `data`, or an app code such as
  `no_access`), `function_error`, `network`, `bad_response`.
- Plain JSON only: no int64, bytes or `DateTime` args. Files go through
  `uploadBytes`, times through `dateTimeToConvexMillis`. No realtime
  subscriptions.
- Usage and error table in `flutter/shipglows_convex/README.md`.
