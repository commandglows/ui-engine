# shipglows_overlay_window

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
- Views of one window (native runners): `SetSizedView("text")` keeps the
  size the user gives the window while that view shows, read back with
  `ViewSize("text")` before presenting it, so a resizable editor keeps its
  size while a fixed chooser in the same window keeps its own. Stored as
  `<view>:width`/`<view>:height` beside the bounds (in memory without an app
  folder); `resetSize` forgets the current view's size too.
- Kept values: `ShipglowsOverlayHost.readValue(key)` /
  `writeValue(key, int?)` keep small integers for the overlay (a splitter
  position, a tab) beside its bounds, as `value:<key>`: across launches with
  an app folder, else until the app quits. Writes only change their own
  fields, so bounds, view sizes and values never erase one another.
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
