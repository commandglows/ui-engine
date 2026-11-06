import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// An editor that can receive the shell's undo and redo actions.
abstract interface class UndoTarget implements Listenable {
  /// Whether [undo] does something now.
  bool get canUndo;

  /// Whether [redo] does something now.
  bool get canRedo;

  /// Goes back one step.
  void undo();

  /// Goes forward one step.
  void redo();
}

/// Routes shell-level undo and redo to the active editor.
class UndoRegistry extends ChangeNotifier {
  UndoTarget? _active;

  /// Editor that receives undo and redo, or null.
  UndoTarget? get active => _active;

  /// Makes [target] the editor undo and redo go to.
  void activate(UndoTarget target) {
    if (identical(_active, target)) return;
    _active = target;
    notifyListeners();
  }

  /// Forgets [target] if it is the active one.
  void release(UndoTarget target) {
    if (!identical(_active, target)) return;
    _active = null;
    notifyListeners();
  }
}

/// Gives the widgets below the shell's [UndoRegistry].
class UndoScope extends InheritedWidget {
  /// Provides [registry] to [child].
  const UndoScope({super.key, required this.registry, required super.child});

  /// Registry of the editor on screen.
  final UndoRegistry registry;

  /// The nearest registry, or null outside the shell.
  static UndoRegistry? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<UndoScope>()?.registry;

  @override
  bool updateShouldNotify(UndoScope oldWidget) =>
      registry != oldWidget.registry;
}
