import 'package:flutter/foundation.dart';

/// What the package itself can do to a window when a trigger fires, so an app
/// only has to pair a trigger with an action.
///
/// Windows only. The window acted on is the one under the pointer for a mouse
/// trigger, the window in front for a key trigger. The desktop and the
/// taskbar are never touched.
enum ShipglowsWindowAction {
  minimize,
  maximize,

  /// Maximizes a normal window, restores a maximized one.
  toggleMaximize,

  /// Back from maximized or minimized.
  restore,

  /// Asks the window to close (like its close button).
  close,

  /// Keeps the window in front of the others, or stops. Reports
  /// [ShipglowsActionEvent.outcome] `topmostOn` or `topmostOff`.
  toggleAlwaysOnTop,

  /// Hides the window until [restoreHidden]. Hidden windows come back when the
  /// app quits.
  hide,

  /// Shows the window hidden last.
  restoreHidden,

  /// Half or quarter of the screen (`snapTop` maximizes, as Windows does).
  /// Remembers the previous size for [restoreSize].
  snapLeft,
  snapRight,
  snapTop,
  snapBottom,
  snapTopLeft,
  snapTopRight,
  snapBottomLeft,
  snapBottomRight,

  /// Snaps to the part of the screen the pointer ended in (left, right, top,
  /// bottom, corners; the middle maximizes). For a drag trigger.
  snapToPointer,

  /// Gives a snapped window its previous size back; restores a maximized one.
  restoreSize,

  volumeUp,
  volumeDown,
  volumeMute,
}

/// An action that ran, and how it ended.
@immutable
class ShipglowsActionEvent {
  const ShipglowsActionEvent({
    required this.id,
    required this.action,
    required this.outcome,
  });

  /// [ShipglowsHotkeyBinding.id] of the binding that triggered it.
  final String id;

  final ShipglowsWindowAction action;

  /// One of [ShipglowsOutcome].
  final String outcome;

  bool get succeeded =>
      outcome == ShipglowsOutcome.ok ||
      outcome == ShipglowsOutcome.topmostOn ||
      outcome == ShipglowsOutcome.topmostOff;

  /// The window belongs to a program running with more rights than the app
  /// (« Run as administrator »): Windows refuses to let the app act on it.
  bool get accessDenied => outcome == ShipglowsOutcome.accessDenied;
}

/// How an action ended ([ShipglowsActionEvent.outcome],
/// [ShipglowsHotkeys.run]).
abstract final class ShipglowsOutcome {
  static const ok = 'ok';

  /// [ShipglowsWindowAction.toggleAlwaysOnTop] put the window in front.
  static const topmostOn = 'topmostOn';

  /// [ShipglowsWindowAction.toggleAlwaysOnTop] let the window go back.
  static const topmostOff = 'topmostOff';

  /// Nothing to act on, or a window that must not be touched (the desktop,
  /// the taskbar).
  static const noWindow = 'noWindow';

  /// A window of an elevated program: only an app running as administrator
  /// can act on it.
  static const accessDenied = 'accessDenied';

  static const failed = 'failed';
}
