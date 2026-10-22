import 'dart:async';
import 'dart:ui' show Color, Size;

import 'package:flutter/foundation.dart';
import 'package:shipglows_overlay_window/shipglows_overlay_window.dart';

import 'protocol.dart';
import 'snapshot.dart';

/// The entry the user chose in the floating bar. The bar is already hidden
/// when the app receives it.
@immutable
class ShipglowsCommandBarSelection {
  const ShipglowsCommandBarSelection({
    required this.id,
    this.secondary = false,
    this.previousForeground,
  });

  /// Id of the chosen entry, as in `CommandBarEntry.id`.
  final String id;

  /// Whether the secondary action (Shift+Enter) was chosen.
  final bool secondary;

  /// Handle (HWND) of the window that was in front before the bar opened,
  /// which has the keyboard again unless the entry is one of
  /// [ShipglowsCommandBarSnapshot.appWindowIds]: the target of a paste.
  final int? previousForeground;
}

/// The floating command bar, seen from the app's engine.
///
/// The app publishes what the bar lists ([publish]), opens it ([open], from
/// a hotkey or a tray menu) and runs the entries chosen in it
/// ([selections]). The bar itself runs in its own engine, at [entrypoint]
/// (see [runShipglowsCommandBarOverlay]).
///
/// Windows only; elsewhere [open] returns false and nothing is shown.
class ShipglowsCommandBarWindow {
  ShipglowsCommandBarWindow({
    required String entrypoint,
    String id = 'shipglows_command_bar',
    ShipglowsOverlayOptions? options,
  }) : overlay = ShipglowsOverlayWindow(
         id: id,
         entrypoint: entrypoint,
         options: options ?? defaultOptions(),
       ) {
    _subscription = overlay.messages.listen(_onMessage);
  }

  /// Window options of a command bar: always on top, no taskbar button,
  /// opened in the upper part of the cursor's monitor, hidden by a click
  /// outside, resizable, position and size remembered (across launches with
  /// [appFolder]).
  ///
  /// [backgroundColor] should be the bar's surface color; the bar sets the
  /// frame colors from its theme once it runs. [transparent] removes the
  /// window's own background, corners and shadow, for a bar that draws its
  /// whole surface (`surfaceBuilder`).
  static ShipglowsOverlayOptions defaultOptions({
    String? appFolder,
    String title = '',
    Size size = const Size(640, 440),
    Size minimumSize = const Size(320, 220),
    bool excludeFromCapture = false,
    OverlaySizeMemory sizeMemory = OverlaySizeMemory.persistent,
    bool rememberPosition = true,
    bool doubleClickMaximizes = true,
    bool darkFrame = true,
    bool transparent = false,
    Color? borderColor,
    Color? backgroundColor,
  }) => ShipglowsOverlayOptions(
    size: size,
    minimumSize: minimumSize,
    title: title,
    appFolder: appFolder,
    alwaysOnTop: true,
    showInTaskbar: false,
    outsideClick: OverlayOutsideClick.close,
    excludeFromCapture: excludeFromCapture,
    resizable: true,
    doubleClickMaximizes: doubleClickMaximizes,
    sizeMemory: sizeMemory,
    rememberPosition: rememberPosition,
    placement: OverlayPlacement.cursorMonitorUpper,
    cornerRadius: 8,
    darkFrame: darkFrame,
    transparent: transparent,
    borderColor: borderColor,
    backgroundColor: backgroundColor,
  );

  /// The overlay window that hosts the bar.
  final ShipglowsOverlayWindow overlay;

  final _selections =
      StreamController<ShipglowsCommandBarSelection>.broadcast();
  late final StreamSubscription<ShipglowsOverlayMessage> _subscription;
  ShipglowsCommandBarSnapshot? _snapshot;

  /// Entries chosen in the bar. Run them here, in the app's engine.
  Stream<ShipglowsCommandBarSelection> get selections => _selections.stream;

  /// Whether the bar is on screen.
  ValueListenable<bool> get visible => overlay.visible;

  /// Last snapshot given to [publish].
  ShipglowsCommandBarSnapshot? get snapshot => _snapshot;

  /// Handle (HWND) of the window that was in front when the bar last opened.
  /// Also carried by each [ShipglowsCommandBarSelection].
  int? get previousForeground => overlay.previousForeground;

  /// Starts the bar's engine hidden, so the first [open] is instant.
  /// Optional; best called once the app is idle after startup.
  Future<bool> prepare() => overlay.prepare();

  /// Keeps [snapshot] for the next opening, and updates the bar in place
  /// while it is open. Merging a burst of changes into one publish is up to
  /// the app.
  Future<void> publish(ShipglowsCommandBarSnapshot snapshot) async {
    _snapshot = snapshot;
    if (overlay.visible.value) {
      await overlay.send(snapshotMessage, snapshot.toJson());
    }
  }

  /// Opens the bar with the keyboard, on the last snapshot (the overlay's
  /// initial entries before any). [previousForeground] (an HWND) replaces
  /// the window in front now as the one focus returns to, for an app that
  /// activated its own window first (a tray menu). Returns false when the
  /// bar could not be shown.
  Future<bool> open({int? previousForeground}) => overlay.show(
    data: _snapshot?.toJson(),
    previousForeground: previousForeground,
  );

  /// Hides the bar; [focus] says which window gets the keyboard.
  Future<void> close({OverlayHideFocus focus = OverlayHideFocus.previous}) =>
      overlay.hide(focus: focus);

  /// Closes the bar when it is open, opens it otherwise (one hotkey for
  /// both).
  Future<bool> toggle({int? previousForeground}) async {
    if (overlay.visible.value) {
      await close();
      return false;
    }
    return open(previousForeground: previousForeground);
  }

  /// Closes the window and stops the bar's engine.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _selections.close();
    await overlay.dispose();
  }

  void _onMessage(ShipglowsOverlayMessage message) {
    if (message.method != selectMessage || _selections.isClosed) return;
    final arguments = message.arguments;
    if (arguments is! Map) return;
    final id = arguments['id'];
    if (id is! String) return;
    final previous = arguments['previousForeground'];
    _selections.add(
      ShipglowsCommandBarSelection(
        id: id,
        secondary: arguments['secondary'] == true,
        previousForeground: previous is int ? previous : null,
      ),
    );
  }
}
