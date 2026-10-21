import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Moves the window when [child] is dragged, through the native move loop.
///
/// Unlike the title bar, a double-click does nothing: meant for compact,
/// frameless surfaces (a command bar) whose title bar is hidden.
class ShipglowsWindowDragArea extends StatelessWidget {
  const ShipglowsWindowDragArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanStart: (_) => windowManager.startDragging(),
      child: child,
    );
  }
}
