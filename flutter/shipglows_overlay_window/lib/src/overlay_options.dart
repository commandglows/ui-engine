import 'dart:ui' show Color, Rect, Size;

import 'package:flutter/foundation.dart';

/// How long the size the user gave an overlay by dragging its edges lasts.
enum OverlaySizeMemory {
  /// Back to the default size at each opening.
  none,

  /// Kept until the app quits.
  session,

  /// Kept across launches.
  persistent,
}

/// Where an overlay opens when it has no remembered position.
enum OverlayPlacement {
  /// Centered on the monitor under the mouse cursor.
  cursorMonitorCenter,

  /// Centered horizontally, a fifth of the way down the cursor's monitor
  /// (command bars).
  cursorMonitorUpper,

  /// Centered on the monitor of the window that was in front.
  foregroundMonitorCenter,

  /// Against the right edge of the cursor's monitor, vertically centered
  /// (docked launchers). With [ShipglowsOverlayOptions.clampRect], that part
  /// of the window touches the edge.
  cursorMonitorRight,
}

/// What a click outside an overlay (another window becoming active) does.
/// Windows the overlay owns, such as a file dialog, never count as outside.
enum OverlayOutsideClick {
  /// Goes just behind the window clicked; back on top once reactivated.
  background,

  /// Hides (command bars).
  close,

  /// Nothing: an [ShipglowsOverlayOptions.alwaysOnTop] overlay stays above
  /// every window.
  none,
}

/// What gets the keyboard when an overlay hides.
enum OverlayHideFocus {
  /// The window that was in front before the overlay opened, if the overlay
  /// still had focus.
  previous,

  /// Nothing is activated: the app activates a window itself.
  none,

  /// The main window of the app that created the overlay, shown if hidden
  /// (a command that opens a screen of the app).
  app,
}

/// Window behaviour of a [ShipglowsOverlayWindow], fixed at creation.
@immutable
class ShipglowsOverlayOptions {
  const ShipglowsOverlayOptions({
    this.size = const Size(640, 440),
    this.minimumSize = const Size(240, 120),
    this.title = '',
    this.appFolder,
    this.alwaysOnTop = true,
    this.showInTaskbar = false,
    this.outsideClick = OverlayOutsideClick.background,
    this.excludeFromCapture = false,
    this.activateOnClick = true,
    this.resizable = true,
    this.doubleClickMaximizes = true,
    this.sizeMemory = OverlaySizeMemory.persistent,
    this.rememberPosition = true,
    this.placement = OverlayPlacement.cursorMonitorCenter,
    this.margin = 16,
    this.clampRect,
    this.cornerRadius = 12,
    this.darkFrame = true,
    this.transparent = false,
    this.borderColor,
    this.backgroundColor,
  });

  /// Default size in logical pixels, scaled to the monitor's DPI.
  final Size size;

  /// Smallest size the edges can be dragged to.
  final Size minimumSize;

  /// Window title, shown in the taskbar when [showInTaskbar].
  final String title;

  /// Folder under `%APPDATA%` where the position and size are saved, as in
  /// `ShipglowsWindowSession` (usually the app's name). Null: nothing is
  /// saved across launches.
  final String? appFolder;

  /// Stays above every other window, even when another app is active.
  final bool alwaysOnTop;

  /// Own taskbar button and Alt+Tab entry; otherwise a tool window.
  final bool showInTaskbar;

  /// What a click outside the overlay does.
  final OverlayOutsideClick outsideClick;

  /// Invisible in screenshots and screen recordings.
  final bool excludeFromCapture;

  /// Whether a click activates the overlay. False: the window in front keeps
  /// the keyboard while the overlay is hovered, clicked and dragged (a
  /// floating launcher); the overlay never takes focus by itself, and
  /// [ShipglowsOverlayHost.startDrag] moves it without the system move loop.
  final bool activateOnClick;

  /// The edges can be dragged; a double-click on an edge restores [size].
  final bool resizable;

  /// A double-click on the drag area maximizes the overlay, or restores it.
  final bool doubleClickMaximizes;

  /// How long a size chosen by dragging the edges lasts.
  final OverlaySizeMemory sizeMemory;

  /// Reopens where the user last dragged it, also after a restart (with
  /// [appFolder]).
  final bool rememberPosition;

  /// Where the overlay opens the first time.
  final OverlayPlacement placement;

  /// Logical space kept between the overlay and the screen edges.
  final double margin;

  /// Part of the window, in logical pixels from its top-left corner, kept
  /// inside the monitor's work area (with [margin]) when the overlay opens,
  /// is dragged or the displays change; the rest of the window may leave the
  /// screen, as the transparent room around a launcher bubble. Null: the
  /// whole window is kept inside.
  final Rect? clampRect;

  /// Corner radius on Windows 10, where the system does not round windows.
  final double cornerRadius;

  /// Dark window frame (Windows 11 border and shadow).
  final bool darkFrame;

  /// See-through window: no system corners, border, shadow or background.
  /// The overlay draws its whole shape; its transparent pixels show what is
  /// behind (a card with its own margin and shadow).
  final bool transparent;

  /// 1 px border color drawn by Windows 11. Null: the system color.
  final Color? borderColor;

  /// Painted by the window under the Flutter view: the strip Windows may
  /// expose for a frame when a resize step outruns the engine. Give it the
  /// overlay's background color. Null: left to the system (black).
  final Color? backgroundColor;

  Map<String, Object?> toMap() => {
    'width': size.width.round(),
    'height': size.height.round(),
    'minWidth': minimumSize.width.round(),
    'minHeight': minimumSize.height.round(),
    'title': title,
    'appFolder': ?appFolder,
    'alwaysOnTop': alwaysOnTop,
    'showInTaskbar': showInTaskbar,
    'outsideClick': outsideClick.name,
    'excludeFromCapture': excludeFromCapture,
    'activateOnClick': activateOnClick,
    'resizable': resizable,
    'doubleClickMaximizes': doubleClickMaximizes,
    'sizeMemory': sizeMemory.name,
    'rememberPosition': rememberPosition,
    'placement': placement.name,
    'margin': margin.round(),
    if (clampRect case final rect?)
      'clampRect': [
        rect.left.round(),
        rect.top.round(),
        rect.right.round(),
        rect.bottom.round(),
      ],
    'cornerRadius': cornerRadius.round(),
    'darkFrame': darkFrame,
    'transparent': transparent,
    if (borderColor case final color?) 'borderColor': color.toARGB32(),
    if (backgroundColor case final color?)
      'backgroundColor': color.toARGB32(),
  };
}
