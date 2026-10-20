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
- Mobile and web: no-op, the app renders unchanged.
- Not included: the Windows 11 Snap Layouts flyout on maximize hover
  (`Win` + `Z` still opens it). Keep the maximize button isolated so it can be
  added later.

### Usage

```yaml
dependencies:
  shipglows_window:
    path: ../../window-engine/flutter/shipglows_window
```

```dart
// main(), after the binding is initialized and before runApp:
await ShipglowsWindow.ensureInitialized(minimumSize: const Size(720, 480));

// MaterialApp:
builder: (context, child) => ShipglowsWindowFrame(
  style: ShipglowsTitleBarStyle.fromTheme(Theme.of(context)),
  child: child ?? const SizedBox.shrink(),
),
```

Each app passes its own brand tokens through `ShipglowsTitleBarStyle`.
