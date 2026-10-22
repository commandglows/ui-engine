import 'package:flutter/foundation.dart';

/// Something the user did with the tray or with a new launch of the app.
@immutable
sealed class ShipglowsTrayEvent {
  const ShipglowsTrayEvent({this.previousForeground});

  /// Handle (HWND) of the last window in front before the click, ignoring
  /// the taskbar and the tray menu, for example to give the keyboard back
  /// to it (`ShipglowsCommandBarWindow.open(previousForeground:)`). It can
  /// be the app's own main window. Null when unknown.
  final int? previousForeground;
}

/// A menu entry was chosen, or the primary click stands for one
/// (`ShipglowsTrayClick.item`).
final class ShipglowsTrayItemSelected extends ShipglowsTrayEvent {
  const ShipglowsTrayItemSelected(this.id, {super.previousForeground});

  final String id;
}

/// The icon was clicked, or activated from the keyboard
/// (`ShipglowsTrayClick.openMainWindow` or `.event`).
final class ShipglowsTrayClicked extends ShipglowsTrayEvent {
  const ShipglowsTrayClicked({super.previousForeground});
}

/// The app was launched again while running; the new process forwarded its
/// command line and exited. The arguments come from any local process:
/// validate them before acting.
final class ShipglowsTraySecondInstance extends ShipglowsTrayEvent {
  const ShipglowsTraySecondInstance(this.arguments)
    : super(previousForeground: null);

  /// Command line arguments, without the executable.
  final List<String> arguments;
}
