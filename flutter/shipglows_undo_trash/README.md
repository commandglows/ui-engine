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
