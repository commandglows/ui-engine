import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Whether the focused widget is a text field, which owns Ctrl/⌘+Z itself.
bool isTextInputFocused() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

bool get _usesMeta => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => true,
  _ => false,
};

/// Ctrl/⌘+Z undoes, Ctrl/⌘+Shift+Z (and Ctrl+Y off Apple) redoes, for the
/// subtree. Keys pressed in a text field are left to it, so typing keeps its
/// own undo. A disabled action lets the key through.
///
/// A command bar running the same action calls the handler directly: its own
/// search field is focused, which this widget would skip.
class UndoShortcuts extends StatelessWidget {
  const UndoShortcuts({
    super.key,
    required this.child,
    this.onUndo,
    this.onRedo,
    this.canUndo = true,
    this.canRedo = true,
    this.autofocus = false,
  });

  final Widget child;
  final VoidCallback? onUndo;
  final VoidCallback? onRedo;
  final bool canUndo;
  final bool canRedo;

  /// Takes focus on mount, so the keys work before anything is clicked.
  final bool autofocus;

  /// The undo keys on this platform.
  static List<SingleActivator> get undoActivators => [
    SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: !_usesMeta,
      meta: _usesMeta,
    ),
  ];

  /// The redo keys on this platform.
  static List<SingleActivator> get redoActivators => [
    SingleActivator(
      LogicalKeyboardKey.keyZ,
      control: !_usesMeta,
      meta: _usesMeta,
      shift: true,
    ),
    if (!_usesMeta)
      const SingleActivator(LogicalKeyboardKey.keyY, control: true),
  ];

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || isTextInputFocused()) {
      return KeyEventResult.ignored;
    }
    final keyboard = HardwareKeyboard.instance;
    final undo = onUndo;
    if (undo != null &&
        canUndo &&
        undoActivators.any((key) => key.accepts(event, keyboard))) {
      undo();
      return KeyEventResult.handled;
    }
    final redo = onRedo;
    if (redo != null &&
        canRedo &&
        redoActivators.any((key) => key.accepts(event, keyboard))) {
      redo();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) => Focus(
    autofocus: autofocus,
    skipTraversal: true,
    onKeyEvent: _onKeyEvent,
    child: child,
  );
}
