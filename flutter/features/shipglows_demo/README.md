# shipglows_demo

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
