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

While a callback is pending, the row blocks repeated invocations. Success and
failure close it; errors go to `onError` or Flutter's error reporter. The host
owns confirmation, optimistic removal, rollback and undo (which can use
`shipglows_undo_trash`). Give each row a stable item key. Hosts own conflicts
with other horizontal gestures and long-press handlers inside their content.

Initial consumer: ReplayGlows feed list (watch state, copy link, add to playlist).
The email engine can supply email-specific callbacks through the same API.

Validation: source review and formatting only. No build, lint, analysis, tests
or interactive device proof were run for the initial implementation.
