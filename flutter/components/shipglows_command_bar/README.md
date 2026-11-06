# shipglows_command_bar

Ctrl/⌘+K command bar, extracted from the ContentGlows bar.

- `CommandBarScope` around the app shell: global Ctrl/⌘+K (also inside text
  fields), inactive while another dialog is open; commands run with the
  scope's context, so routing works from them. On the web it cancels the
  browser's own Ctrl/⌘+K (address bar search).
- `opener` replaces the in-app bar by another one (the floating window):
  Ctrl/⌘+K (as a toggle) and every `CommandBarController.open()` go to it,
  so two bars never open together. The registry, recents and commands stay
  the scope's. It is read at each call, so it can be set after the first
  build (an open in-app bar then closes).
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
- Keys: ↑/↓, Enter, Shift+Enter for a newline, Ctrl/⌘+Enter for the secondary
  action (also on disabled rows), Ctrl/⌘+1…9 (hidden under 600 px), Esc (filter first, then
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
  `tappablePrefixHints`, `showEntryKinds`, `hiddenKinds`, `kindDisplay`,
  `compactRows` (the subtitle follows the label on its line, muted, so more
  rows fit; a disabled row keeps its reason on a line of its own).
  `CommandBarFilter.requiresSpace: false` applies a symbol prefix without a
  space (`>foo`).
- Entry kinds (`CommandBarEntry.kind`, `CommandBarEntryKind`): what choosing
  a row does, so an action run right in the bar never looks like a way to a
  screen. Built-in `open` (a screen of the app), `action` (works from the
  bar: save, copy, toggle) and `app` (another application, the browser); an
  app adds its own with another id. `showEntryKinds` shows each kind at the
  end of its row, as `kindDisplay` says (`CommandBarKindDisplay.icon`,
  `label` or `iconAndLabel`): the icon, and/or the short muted text of
  `CommandBarStrings.entryKindLabels[id]` (« Action », « App »), with
  `entryKinds[id]` as tooltip and spoken text; `hiddenKinds` leaves whole
  kinds out (`{'open'}` for actions only).
- Actions menu (like Claude Desktop's search palette): `CommandBarEntry.actions`
  (`CommandBarEntryAction`: `id`, `label`, `icon`, one-chord `shortcut`,
  `group`, `destructive`, `confirm`, all JSON-safe) lists more things to do
  with a row, ungrouped ones first, then one titled block per `group`, then
  the `destructive` ones in the error color after a separator. The panel
  view lives on its own in `src/actions_panel.dart` (`CommandBarActionsPanel`,
  not exported), so a shared floating menu can replace it later. Alt+Enter
  (Ctrl+K stays the hotkey), a right-click or the « … » button shown on the
  hovered or highlighted row opens it, anchored to the end of the row: a
  header with the entry's label and a muted « section · badge · subtitle »
  line, then Enter (`primaryLabel`), Ctrl/⌘+Enter (`secondaryLabel`) and the
  actions, numbered 1–9 in keycaps. ↑/↓ and Enter choose, a digit runs its
  line, Escape, ← or Alt+Enter close it; scrolling the list closes it too.
  A `confirm` action asks for a second press first, its label replaced by
  `CommandBarStrings.confirmAction` (« Press again to confirm »). The footer
  shows « Alt Enter actions » when the row has any. An action's `shortcut` also
  runs it straight from the list. The choice carries
  `CommandBarChoice.action` (null for Enter and Ctrl/⌘+Enter, which keep
  working as before); actions run on a disabled row like the secondary
  action. In a `CommandBarScope`, `CommandBarCommand(actions: …, runAction:
  (context, actionId) …)`.
- Actions on the typed text: `CommandBarCommand.query(runQuery: (context,
  text) …)` (`CommandBarEntry.usesQuery` in JSON). Never searched nor kept in
  the recents: once words are typed they are listed last under « With this
  text » (`queryActionsSection`), alone when nothing matches, so a phrase
  that finds nothing still offers something to do with it. A filter keeps
  those it matches. `{query}` (`commandBarQueryPlaceholder`) in the label or
  subtitle shows the text; `CommandBarChoice.query` carries it (filter
  prefix left out) to the owner of a `CommandBarView`.
- Other engines (floating window, native relay): `CommandBarEntry.toJson` /
  `fromJson` (icons by code point through an app table), `CommandBarView` and
  `showCommandBar` with your own `CommandBarSource`.
- Search field gestures on `CommandBarView`: `onSearchDoubleTap` (expand the
  bar, maximize its window) keeps the caret instead of selecting a word;
  `onSearchDragStart` turns a mouse drag in the field into a window move
  instead of a text selection. Click to place the caret and keyboard
  selection (Shift+arrows, Ctrl/⌘+A) keep working.
- `CommandBarView.fillHeight`: the bar takes all the height it is given (the
  list grows, the footer stays at the bottom), for a window of its own; off,
  it is as tall as its content, as in a dialog.
- Shortcuts sheet, built from the same registry, so it follows the current
  screen and teaches its keys: « On this page » (the contributed commands
  that have `shortcuts`), the screen's other keys (`CommandBarShortcuts`
  around it, groups of `CommandBarShortcutHint`), « Everywhere » (Ctrl/⌘+K,
  the sheet's own keys), one group per bar section for the app-wide
  commands (`CommandBarSection.shortcutLabel: 'Aller à {label}'` renames
  them), then the scope's `shortcuts:` groups (Space plays or pauses).
  - One declaration for the key and its row: a hint's `bindings`
    (`ShortcutActivator` → callback) run while its screen is on top (or the
    scope, for `shortcuts:`), so the sheet cannot drift from the keys.
    Bindings without Ctrl, Alt or Meta pause while a text field has focus
    (`commandBarIsTyping`), which the sheet's footer says.
  - Search field (accents folded, keys and notes included) and an empty
    state; « or » between alternatives, « then » inside a sequence (`G N`).
  - `keysText` for what is not a key (« Glisser-déposer », « Q S D F… »),
    `note` for muted words after the keys (« dans la bibliothèque »).
  - « S'entraîner » (`CommandBarShortcutPractice`, also usable on its own):
    one card per shortcut of the listed groups (the search narrows them),
    in random order; the user presses the keys from memory. Checked against
    the hint's `bindings`, else its labels (Ctrl/Maj/Alt/Win, named keys in
    English or French, F1–F24, letters, symbols whatever the layout,
    sequences). Keys Windows takes first (Win, Alt+Tab, Alt+F4, Ctrl+Alt+Del,
    an app's global hotkey) or labels it cannot read ask the user to rate
    themselves. « Afficher la réponse » sends the card to review; the end
    shows the score and replays the missed cards. Escape climbs one level:
    once pauses the card (the keyboard reaches the buttons again,
    « Reprendre » listens anew), twice shows the answer, and from an
    answered card or the score it goes back to the list; so Escape is never
    an answer (such a card asks for a self-rating). While it runs, the scope
    leaves every key to it.
  - Opened with `CommandBarController.showShortcuts()`, F1
    (`shortcutsOnF1`) or « ? » outside text fields
    (`shortcutsOnQuestionMark`), both off by default;
    `shortcutsCommandSection` adds a « Keyboard shortcuts » entry to the bar.
    With a floating bar, list `commandBarShortcutsCommandId` as an entry that
    brings the main window forward and call `showShortcuts()` when chosen.
    `showCommandBarShortcuts` shows a list built elsewhere.

```dart
CommandBarScope(
  commands: appCommands,
  strings: CommandBarStrings.fr,
  sections: const [
    CommandBarSection(id: 'screens', title: 'Navigation', shortcutLabel: 'Aller à {label}'),
    CommandBarSection(id: 'actions', title: 'Actions'),
  ],
  shortcutsOnF1: true,
  shortcutsCommandSection: 'actions',
  shortcuts: (context) => [
    CommandBarShortcutGroup(title: 'Lecture', hints: [
      CommandBarShortcutHint(
        shortcuts: ['Space'],
        label: 'Lecture ou pause',
        bindings: {const SingleActivator(LogicalKeyboardKey.space): player.toggle},
      ),
      const CommandBarShortcutHint(keysText: 'Glisser-déposer', label: 'Importer des fichiers'),
    ]),
  ],
  child: shell,
);

// A screen
CommandBarShortcuts(
  groups: [
    CommandBarShortcutGroup(title: 'Écoute et tablature', hints: [
      CommandBarShortcutHint(
        shortcuts: ['Ctrl+←', 'Ctrl+→'],
        label: 'Reculer ou avancer de 5 secondes',
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowLeft, control: true): () => seek(-5),
          const SingleActivator(LogicalKeyboardKey.arrowRight, control: true): () => seek(5),
        },
      ),
      CommandBarShortcutHint(
        shortcuts: ['['],
        label: 'Poser le début (A) de la boucle',
        bindings: {const CharacterActivator('['): loop.setStart},
      ),
    ]),
  ],
  child: CommandBarContribution(commands: screenCommands, child: screen),
);
```
