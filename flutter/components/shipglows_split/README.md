# shipglows_split

Two panes split by a handle the user drags: `ShipglowsSplitView(first:,
second:, axis:)`. Mouse, touch, or the arrow keys once the handle is focused
(`keyboardStep`); the grip brightens under the pointer, while dragged and
when focused, and screen readers get a slider. `minFirst` and `minSecond`
always hold. The app keeps the position: `initialFraction` (a new value read
late from storage is taken while not dragging) and `onChangeEnd` (end of a
drag or key press). ContentGlows' capture overlay splits its text and files
with it and keeps the share through `ShipglowsOverlayHost.writeValue`.
