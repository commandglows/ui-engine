# shipglows_flutter_zoom

App-wide zoom for Flutter web and desktop. The viewport stays filled while
Ctrl/Command+mouse wheel, a trackpad pinch or a browser scale signal changes
the complete UI. Ctrl/Command+= and Ctrl/Command+- step it, Ctrl/Command+0
resets it.

```dart
FlutterZoomViewport(
  minimumZoom: 0.75,
  maximumZoom: 1.5,
  zoomStep: 0.1, // per wheel notch
  keyboardZoomStep: 0.05, // per Ctrl+= / Ctrl+-
  child: const MyAppSurface(),
)
```

Defaults follow CommunityGlows: 75–150 %, 5 % per key press. Each press lands
on a multiple of `keyboardZoomStep`. `zoomInShortcuts`, `zoomOutShortcuts` and
`resetShortcuts` replace the key bindings.

```yaml
dependencies:
  shipglows_flutter_zoom:
    path: ../../shipglows-ui-engine/flutter/shipglows_flutter_zoom
```

`ShipglowsWindowSession` (`shipglows_window`) saves and restores the zoom.
