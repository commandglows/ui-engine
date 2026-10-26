/// Undo, redo and trash for ShipGlows Flutter apps.
///
/// - [UndoRedoHistory]: undo/redo stacks of snapshots for an editor.
/// - [UndoCommandStack]: a bounded stack of compensating commands (each
///   change kept with the command that reverts it), undo of the latest or
///   of a specific entry; the caller runs the commands.
/// - [UndoShortcuts]: Ctrl/⌘+Z, Ctrl/⌘+Shift+Z and Ctrl+Y, text fields left
///   alone.
/// - [UndoWindow], [PendingUndo] and [showUndoSnackBar]: act at once, offer
///   « Undo » for a few seconds, commit when the window closes.
/// - [TrashView]: the trash screen body (search, filter, restore, delete
///   permanently, empty the trash).
library;

export 'src/pending_undo.dart';
export 'src/strings.dart';
export 'src/trash_view.dart';
export 'src/undo_command_stack.dart';
export 'src/undo_history.dart';
export 'src/undo_shortcuts.dart';
export 'src/undo_snack_bar.dart';
