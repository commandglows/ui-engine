# shipglows_window

Hides the native title bar (Windows, Linux, macOS) and draws a themeable one
on top of [`window_manager`](https://pub.dev/packages/window_manager).

- Native move loop: edge snapping, Windows 11 snap bar, `Win` + arrows.
- Windows: once a size change settles (100 ms), the Flutter view is shrunk by
  one pixel then restored. Two sizes back to back (a `Win` + arrow snap,
  quarter to half especially) can otherwise leave the engine's render
  surface at the old size, every frame stretched and cropped into it until
  the next resize. Native plugin (`windows/`), no Dart API. A frameless
  transparent window also gets this rebuild 3 s after its first frame: it
  otherwise stays frozen on an early frame until the next resize.
- Stays on `window_manager` 0.5: from 0.6 its calls are synchronous FFI, and a
  resize from Dart then re-enters Dart through Flutter's message pump and
  crashes the app (`Dart_InvokeClosure`, Windows, Flutter 3.47).
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
    path: ../../shipglows-app-engine/flutter/desktop/shipglows_window
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

Zoom ([`shipglows_zoom`](../../components/shipglows_zoom/README.md)) and last page:

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
[`shipglows_tray`](../../desktop/shipglows_tray/README.md):

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
