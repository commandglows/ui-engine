# shipglows_swipe_actions

Reusable Flutter action rows for touch, mouse and accessibility. No backend,
email model, persistence or global keyboard handler is included.

Wrap a bounded-width row with `ShipglowsSwipeActions`, provide localized
`revealLabel` / `closeLabel`, and lists of `SwipeRowAction` in `startActions`
and `endActions`. Start/end follow the current text direction.

```dart
ShipglowsSwipeActions(
  revealLabel: 'Actions',
  closeLabel: 'Fermer',
  longPressSide: SwipeActionSide.end,
  clickBindings: const [
    SwipeClickBinding(side: SwipeActionSide.end, control: true),
    SwipeClickBinding(side: SwipeActionSide.start, alt: true, shift: true),
  ],
  endActions: [SwipeRowAction(
    label: 'Archiver', icon: Icons.archive_outlined,
    onInvoke: () => archiveMessage(),
  )],
  child: messageRow,
)
```

Swipe reveals the buttons. Long press reveals the configured side, or can be
disabled with `longPressSide: null`. Click bindings match modifiers exactly:
Control, Shift, Alt and Meta can be combined. Normal clicks stay with the child;
configured modified clicks claim the gesture. Avoid taking over selection or
navigation shortcuts already used by the host. Native browser/OS shortcuts may
intercept combinations before Flutter receives them.

`commitStart` / `commitEnd` opt into invoking the first action on release beyond
`commitThreshold` (default 65% of row width). Velocity alone never commits an
action. Default behavior only reveals buttons, including on long press/click.

Use a `SwipeActionsController` per row for an explicit menu button or a host
keyboard shortcut, and dispose it with its owner. `reveal(side)` opens and
`close()` closes. Custom semantics actions expose each configured side to
assistive technology. Visible buttons carry their action labels; motion follows
the platform's reduced-animation preference. Outside taps and the close button
close the row. Hosts may close other controllers to enforce one open row.

While a callback is pending, the row blocks repeated invocations and shows its
label with progress. Success closes it; failure restores the revealed controls
and sends errors to `onError` or Flutter's error reporter. The host
owns confirmation, optimistic removal, rollback and undo (which can use
`shipglows_undo_trash`). Give each row a stable item key. Hosts own conflicts
with other horizontal gestures and long-press handlers inside their content.

Initial consumer: ReplayGlows feed list (watch state, copy link, add to playlist).
The email engine can supply email-specific callbacks through the same API.

## Motion contract

- Direct manipulation follows pointer displacement inside the useful range.
  Beyond it, asymptotic resistance avoids a hard stop (36 px maximum excess).
- Release uses Flutter `SpringSimulation` with mass 1, stiffness 420 and critical
  damping. Release velocity is supplied in logical pixels/second, capped at
  2400; a short 160 ms projection selects the open/closed destination. This is
  a package tuning choice, not a numerical requirement from Material or Apple.
- Buttons fade and translate with reveal progress. Full-swipe stretches the
  primary action continuously while secondary actions recede.
- The 65% default commit threshold has an 8% hysteresis band, a color/scale cue
  and optional haptic feedback (`hapticFeedback: false` disables it). Reversing
  before release cancels arming; a fast reverse release cancels commitment.
- Full-swipe animates the foreground away before invoking the callback. The
  busy lock stays held until the callback and closing animation finish.
- Reduced motion removes the spring, parallax, scale emphasis and haptics;
  direct manipulation and readable action state remain. Escape closes an open
  row when keyboard focus is inside it. Colors and short feedback durations
  come from the shared theme and `ShipglowsScale`.
- The foreground gesture detector keeps a stable key as background controls
  appear, so rendering a reveal cannot dispose an in-progress gesture.

States: closed -> dragging -> revealed or armed -> pending -> closed on
success, revealed on failure. A new drag interrupts settling at its current
position. Long press and modified click only enter revealed, never armed.

References discovered through Parallel and checked on their primary pages:
[Material gesture feedback](https://m2.material.io/design/interaction/gestures.html),
[Apple gesture conventions and alternate controls](https://developer.apple.com/design/human-interface-guidelines/gestures),
[Flutter velocity-driven spring simulation](https://docs.flutter.dev/cookbook/animation/physics-simulation).

## Validation

Five targeted Flutter widget tests pass: long-press reveal without execution,
exact modifier-click matching without activating the child, reverse-gesture
cancellation, full-swipe execution with an async lock, and failure recovery.
They were added after the dev launch found a missing semantics import and
subsequently caught gesture-detector replacement during reveal.

ReplayGlows starts through its managed debug web-server session with its
declared Doppler/Clerk/Convex recipe. Browser observation reaches sign-in;
login, protected feed access and visual gesture/device proof remain pending.
No standalone build, lint, analysis or performance measurement was run.
