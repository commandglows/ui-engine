# Window Engine

Shared desktop window chrome for ShipGlows Flutter apps.

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
    path: ../../window-engine/flutter/shipglows_window
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
