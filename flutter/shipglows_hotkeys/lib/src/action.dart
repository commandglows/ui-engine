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

  /// `ok`, `topmostOn`, `topmostOff`, `noWindow` (nothing to act on, or a
  /// window that must not be touched) or `failed`.
  final String outcome;

  bool get succeeded =>
      outcome == 'ok' || outcome == 'topmostOn' || outcome == 'topmostOff';
}
