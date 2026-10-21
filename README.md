# UI Engine

Shared interface components for ShipGlows Flutter apps. One package per
component, consumed as a path dependency:

```yaml
dependencies:
  shipglows_command_bar:
    path: ../../ui-engine/flutter/shipglows_command_bar
```

Desktop window chrome lives apart in `window-engine`: it depends on
`window_manager`, which web-only apps must not pull in.

## `flutter/shipglows_command_bar`

Ctrl/⌘+K command bar, extracted from the ContentGlows bar.

- `CommandBarScope` around the app shell: global Ctrl/⌘+K (also inside text
  fields), inactive while another dialog is open; commands run with the
  scope's context, so routing works from them. On the web it cancels the
  browser's own Ctrl/⌘+K (address bar search).
- `CommandBarContribution` around a screen: its commands are listed under
  their section while it is mounted and its route is on top. A screen kept
  alive offstage (indexed stack tab) passes `isActive`.
- Search: every word must match the label or keywords, accents folded
  (« ecran » finds « Écran »); label prefix ranks first, disabled entries
  last.
  `searchOnly` entries (songs, notes) stay hidden until something is typed.
- Sections in the order the app gives, recents first (`CommandBarRecentsStore`,
  memory by default; back it with `SharedPreferences` through
  `CallbackCommandBarRecents`).
- One-letter filters (`CommandBarFilter`): `n idea` becomes a « Notes » chip;
  Backspace on an empty field removes it.
- Keys: ↑/↓, Enter, Shift+Enter or Ctrl/⌘+Enter (secondary action, also on
  disabled rows), Ctrl/⌘+1…9 (hidden under 600 px), Esc (filter first, then
  close). `primaryLabel` names what Enter does on a row in the footer.
- Rows: `badge` shows a short state in a pill after the label;
  `CommandBarSection.limit` caps a section while no filter is active.
- Entries loaded after opening: pass a `refresh` listenable (scope,
  `showCommandBar`, `CommandBarView`); contributions refresh on their own.
- Texts: `CommandBarStrings.en`, `.fr`, or the app's own.
- Look: `CommandBarThemeData` theme extension, every value falls back on the
  `ColorScheme`; `keycapBuilder` for app-drawn keycaps.
  `highlightIndicatorColor` adds a leading bar to the highlighted row.
- `CommandBarTile`: the bar's row, for command suggestions an app lists in
  its own surface (under a search field).
- Resizing: the side and bottom edges (and bottom corners) drag the bar to
  another size; a grip shows on hover, double-click restores the theme's
  size. Kept in a `CommandBarSizeStore` (memory by default,
  `CallbackCommandBarSize` for the app's storage); `resizable: false` turns
  it off.
- Opt-in behaviours (`CommandBarBehavior`, all off by default; the scope
  takes a builder read at each opening, so app settings can drive it):
  `fuzzyMatch` (letters in order, ranked last), `sortSectionsByMatch`,
  `tappablePrefixHints`. `CommandBarFilter.requiresSpace: false` applies a
  symbol prefix without a space (`>foo`).
- Other engines (floating window, native relay): `CommandBarEntry.toJson` /
  `fromJson` (icons by code point through an app table), `CommandBarView` and
  `showCommandBar` with your own `CommandBarSource`.
