# shipglows_theme

One theme for every app and package. `ShipglowsTheme` (a `ThemeExtension`)
holds the semantic roles: surfaces, text, icons, border/line, highlight,
accent, danger, success, warning, focus, scrim, keycap face, shape, spacing, control height and
motion. Each app fills it once from its own brand tokens (generated from its
design-token source, as its Astro site does) and adds it to
`ThemeData.extensions`, light and dark:

```dart
ThemeData(extensions: [ShipglowsTheme(surface: …, keyBorder: …, …)])
```

`ShipglowsScale` is the shared design scale, as constants usable in `const`
code and in screens: spacing `spaceXs`…`spaceXxxl` (4, 8, 12, 16, 24, 32, 48),
radii `radiusXs`…`radiusXl` plus `radiusFull` (4, 6, 10, 16, 24, 999), motion
`motionFast` / `motionNormal` / `motionSlow` (120, 200, 320 ms) with
`curveStandard` and `curveEmphasized`, type sizes `textXs`…`textHero` (11, 14,
16, 18, 22, 38), icon sizes `iconSm` / `iconMd` / `iconLg` (16, 20, 24) and the
Material 3 window breakpoints `breakpointCompact` / `breakpointMedium` /
`breakpointExpanded` (600, 840, 1200). `ShipglowsTheme`'s default spacing,
radii and motion come from it; an app overrides a brand role, not the scale.

Without one, `ShipglowsTheme.of(context)` (or `.from(themeData)`) derives the
roles from the `ColorScheme`: the former default look of the command bar,
guide and title bar. The menu changed to match the bar: its highlighted row
is `secondaryContainer` (was a 10 % `onSurface` tint), its keys are the shared
keycap on `surface`, its corners follow `radiusLg` (16, was 12) and its rows
`radiusMd` (10, was 8).

Base components drawn from the roles, the same everywhere:

- `ShipglowsKeycap('Entrée')`: one key, sized to its label;
  `ShipglowsKeys(['Ctrl', 'K'])`. The command bar and the menu draw their
  keys with it.
- `ShipglowsKeyButton(label: 'c Presse-papiers', onPressed: …, selected: …)`:
  a button drawn as one keycap holding its whole text, with a tap target of
  `controlMinHeight`; the selected one is opaque, the others fade.
- `ShipglowsKeyHint(keys: ['Alt', 'Entrée'], label: 'actions')`: a footer
  hint.
- `ShipglowsEmptyState(icon: …, message: 'Aucune …', actionLabel: 'Créer …',
  onAction: …)`: an empty list that says what belongs there and offers the
  first step; no button without `actionLabel`. The icon takes `accent`, the
  spacing the space roles; the texts are the caller's.
- `ShipglowsFocusRing(child: …, radius: …, width: …)`: a `focus` outline drawn
  while keyboard focus is inside `child` (never on a mouse click), for rows
  whose Material ink hides the focus. `radius` defaults to `radiusMd`, `width`
  to twice `lineWidth`.

The command bar, `shipglows_menu`, `shipglows_guide` and the
`shipglows_window` title bar read these roles for every value their own theme
extension leaves out, so one declaration dresses them all alike; a package
theme (`CommandBarThemeData`, `ShipglowsMenuTheme`, `GuideThemeData`) keeps
only what is specific to it. Rule: a new shared component takes its colors,
radii, spacing and keys from `ShipglowsTheme`, never from raw values or its
own palette.
