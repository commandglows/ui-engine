# `shipglows_undo_trash`

Shared undo/redo primitives and undo/trash UI for ShipGlows Flutter apps.

## Local editor history

`UndoRedoHistory<T>` keeps immutable snapshots in memory. The caller supplies
the state before each change, then applies the state returned by `undo` or
`redo`:

```dart
final history = UndoRedoHistory<EditorState>(
  limit: 100,
  coalesceWindow: const Duration(milliseconds: 400),
);

history.record(stateBeforeChange);
final previous = history.undo(currentState);
if (previous != null) restore(previous.state);
```

`coalesceWindow` combines nearby `record` calls into one undo step. It defaults
to zero, so existing consumers keep one step per call. Pass a monotonic clock
when a deterministic clock is needed. `group` combines synchronous changes into
one step; snapshot copying or immutability remains the caller's responsibility.

The app supplies an `UndoTarget` for editor-specific restore behavior.
`UndoRegistry` and `UndoScope` route shell shortcuts to whichever editor is
active. Use `UndoShortcuts` when a subtree should handle Ctrl/⌘+Z and redo
directly; focused text fields keep their own native undo history.

## Immutable edit journal

`UndoJournal<T>` holds an ordered list of edits and a cursor. `activeEntries`
is the prefix to replay; `redoEntries` is the inactive suffix. `append` drops
that suffix, and `undo`/`redo` return a new journal without changing the old one.
`fromEntries` copies its input and checks the cursor; returned lists are read-only.
Entries themselves must be immutable. Import `package:shipglows_undo_trash/undo_journal.dart`
for a Dart-only API without Flutter imports.

`append(edit, replaceLast: true)` replaces the last active edit when the host
chooses to compact it. The host validates domain limits before appending;
the journal never silently drops edits required to reconstruct a document.
ContentGlows Image Studio replays image edits through this journal. ShipGlows
Studio wraps it with its own command compaction, admission limits and runner
revision checks. This in-memory cursor does not change backend authority.

## Consumers

- BeatGlows: snapshot history, active-editor routing and undo snack bars.
- ContentGlows: timeline snapshots, pending actions, trash UI and image journal.
- CommandGlows: deferred deletions in clipboard, snippets, dictionary, voice
  transcriptions and custom action buttons through `PendingUndo` and the shared
  undo snack bar. The host awaits settlement before its storage commit.
- ReplayGlows: hide/unhide undo snack bars.
- DreamGlows: compensating command stack and shell shortcuts.
- ShipGlows app: immutable Studio command journal.

Text editors using Flutter's native history retain that history. Apps without
an existing reversible action need a domain contract before adding undo.

## Immediate action undo

`PendingUndo` and `showUndoSnackBar` offer a short-lived inverse for an action
that has already happened. `UndoWindow<K>` coordinates multiple item-scoped
offers and deferred commits. The app owns the operation, persistence, stale
state checks, and failure feedback; the package does not provide a backend
transaction or durable undo journal.

## Trash

`TrashView<T>` supplies the list UI. The host app supplies its item adapter,
retention policy, restore operation, permanent-delete operation, and localized
`TrashStrings`.

## More

Shared in-memory undo/redo history, immutable edit journals, active-editor routing, undo snack bars,
shortcuts, and the reusable trash list. The host supplies editor snapshots,
domain commands, persistence, stale-state checks, and retention policy. See the
[package contract](../../features/shipglows_undo_trash/README.md).
Undo, redo and trash, extracted from ContentGlows. Depends on
`shipglows_feedback` for its snack bar.

- `UndoRedoHistory<T>`: undo/redo stacks of snapshots for an editor. `record(before)`
  before each change (clears redo), `undo(current)` / `redo(current)` return
  the step to restore, `pop()` for an undo-only history. `group(before,
  change, changed:)` folds a batch (an AI pass) into one step, and records
  nothing when `changed` says it was a no-op. Capped at `limit` (oldest
  dropped); optional labels for « Undo: … » tooltips; a `ChangeNotifier`.
- `UndoCommandStack<T>`: a bounded stack of compensating commands for an app
  that keeps both events instead of rewriting history. `push(command, label:)`
  returns the `UndoCommandEntry` kept (oldest dropped past `limit`); `latest`
  and `popLatest()` serve Ctrl/⌘+Z; `remove(entry)` takes a specific one (its
  own « Undo » message); `clear()`. It only orders the entries: the caller runs
  the commands and checks whether a change is still undoable. Undo-only, no
  redo; a `ChangeNotifier`.
- `UndoShortcuts`: Ctrl/⌘+Z undoes, Ctrl/⌘+Shift+Z (and Ctrl+Y off Apple)
  redoes for the subtree; keys typed in a text field stay its own
  (`isTextInputFocused()`), disabled actions let the key through. A command
  bar calls the same handlers directly.
- `PendingUndo`: an action shown at once whose lasting part (`onCommit`: a
  server call) waits for the « Undo » window. Settles exactly once, undo or
  commit; commit errors go to `onError`.
- `UndoWindow<K>`: a screen's open windows by item. `start(key, commit:)`
  hides the item (`isHidden`), `undoLast()` for Ctrl/⌘+Z,
  `flush()` commits everything (app backgrounded). `keepHiddenAfterCommit`
  avoids a flicker while the list reloads; a failed commit shows it again.
  Commits still run once the screen is gone.
- `showUndoSnackBar(context, message:, pending:)`: the shared message snack
  bar (`feedbackSnackBar`, info by default, `kind:` to change) with « Undo »
  (persists for assistive-technology users); `attachUndoSnackBar`
  ties a `PendingUndo` to the app's own toast instead (closing commits),
  with its content wrapped in `UndoSnackBarContent` so undoing elsewhere
  closes that toast, never another message it was queued behind.
- `TrashView<T>`: trash screen body inside the app's scaffold. `entryOf` maps
  an item to a `TrashEntry` (title, deletion and purge dates, `purging`);
  search with accents folded, `TrashFilter`s, restore, delete permanently and
  empty the trash (confirmed through `confirm`, an `AlertDialog` by default),
  a spinner per row, errors to `onError`. Most recent first; the subtitle
  turns red `warnDays` before the purge. Texts: `TrashStrings.en`, `.fr`, or
  the app's own (`copyWith`).

```dart
final window = UndoWindow<String>();

void trash(Item item) {
  final pending = window.start(
    item.id,
    commit: () => api.trash(item.id),
    keepHiddenAfterCommit: true,
  );
  showUndoSnackBar(context, message: 'Moved to trash', pending: pending);
}
```
