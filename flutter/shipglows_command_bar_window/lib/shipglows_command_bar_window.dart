/// The shared command bar in its own floating desktop window (Windows; no-op
/// elsewhere).
///
/// The app's engine publishes a [ShipglowsCommandBarSnapshot] and opens the
/// bar with [ShipglowsCommandBarWindow]; the bar runs in its own engine,
/// started by [runShipglowsCommandBarOverlay], and reports the chosen entry
/// back. The app runs the effect itself.
library;

export 'src/command_bar_overlay.dart';
export 'src/command_bar_window.dart';
export 'src/snapshot.dart';
