# UI Engine

Shared interface components for ShipGlows Flutter apps. One package per
component, consumed as a path dependency:

```yaml
dependencies:
  shipglows_command_bar:
    path: ../../ui-engine/flutter/shipglows_command_bar
```

Each package keeps its own dependencies: an app that uses only the command bar
never pulls `window_manager`.

## `flutter/shipglows_command_bar`

Ctrl/⌘+K command bar, extracted from the ContentGlows bar.

- `CommandBarScope` around the app shell: global Ctrl/⌘+K (also inside text
  fields), inactive while another dialog is open; commands run with the
  scope's context, so routing works from them. On the web it cancels the
  browser's own Ctrl/⌘+K (address bar search).
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
    path: ../../ui-engine/flutter/shipglows_window
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
- Showing it never shows, raises or activates the main window; focus goes
  back to the previous window when it hides.
- Revealed only after Dart has drawn the data passed to `show`.
- Drag to move; edges resize (`resizable`); double-click on an edge restores
  the default size; double-click on the drag area maximizes
  (`doubleClickMaximizes`).
- Position and size remembered (`sizeMemory`: none, session, persistent) in
  `%APPDATA%\<appFolder>\overlay_windows.json`, clamped to the screen;
  per-monitor DPI.
- Windows 11 rounded corners, border color and shadow (DWM).
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
