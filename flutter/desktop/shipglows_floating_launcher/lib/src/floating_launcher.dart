import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shipglows_overlay_window/shipglows_overlay_window.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'geometry.dart';
import 'protocol.dart';
import 'snapshot.dart';

/// The floating launcher, seen from the app's engine.
///
/// A round bubble always on top of every window, in its own engine at
/// [entrypoint] (see `runShipglowsFloatingLauncherOverlay`). Hovering it
/// fans the actions out toward the free side of the screen; a click on one
/// is reported in [selections] and the app runs it. The launcher never
/// takes the keyboard from the window in front, has no taskbar button and
/// stays out of screenshots by default.
///
/// The app publishes the actions ([publish]) and shows the launcher
/// ([show]); the user drags the bubble where they want it, and it comes
/// back there at the next launch (with an `appFolder`).
///
/// Windows only; elsewhere [show] returns false and nothing is shown.
class ShipglowsFloatingLauncher {
  /// [appFolder] (usually the app's name) keeps the bubble's place across
  /// launches, under `%APPDATA%`. Custom [options] replace
  /// [defaultOptions]; build them from it with the same [geometry], since
  /// the window's size and kept-on-screen part must match it.
  ShipglowsFloatingLauncher({
    required String entrypoint,
    String id = 'shipglows_floating_launcher',
    String? appFolder,
    this.geometry = const ShipglowsFloatingLauncherGeometry(),
    ShipglowsOverlayOptions? options,
  }) : assert(
         options == null ||
             (options.size == geometry.windowSize &&
                 options.clampRect == geometry.bubbleRect),
         'options must come from defaultOptions(geometry:) with this geometry',
       ),
       overlay = ShipglowsOverlayWindow(
         id: id,
         entrypoint: entrypoint,
         options:
             options ??
             defaultOptions(appFolder: appFolder, geometry: geometry),
       ) {
    _subscription = overlay.messages.listen(_onMessage);
  }

  /// Window options of a floating launcher: a transparent window of
  /// [ShipglowsFloatingLauncherGeometry.windowSize], always on top, not in
  /// the taskbar, never activated by a click, invisible in screenshots and
  /// recordings ([excludeFromCapture]), docked against the right edge of
  /// the cursor's monitor the first time, then where the user dragged it
  /// (across launches with [appFolder]). Only the bubble is kept inside the
  /// work area, [margin] away from its edges.
  ///
  /// Pass the same [geometry] as the launcher's.
  static ShipglowsOverlayOptions defaultOptions({
    String? appFolder,
    ShipglowsFloatingLauncherGeometry geometry =
        const ShipglowsFloatingLauncherGeometry(),
    String title = '',
    bool excludeFromCapture = true,
    OverlayPlacement placement = OverlayPlacement.cursorMonitorRight,
    double margin = ShipglowsScale.spaceLg,
  }) => ShipglowsOverlayOptions(
    size: geometry.windowSize,
    minimumSize: geometry.windowSize,
    title: title,
    appFolder: appFolder,
    alwaysOnTop: true,
    showInTaskbar: false,
    outsideClick: OverlayOutsideClick.none,
    excludeFromCapture: excludeFromCapture,
    activateOnClick: false,
    resizable: false,
    doubleClickMaximizes: false,
    sizeMemory: OverlaySizeMemory.none,
    rememberPosition: true,
    placement: placement,
    margin: margin,
    clampRect: geometry.bubbleRect,
    darkFrame: false,
    transparent: true,
  );

  /// The overlay window that hosts the launcher.
  final ShipglowsOverlayWindow overlay;

  /// Sizes of the bubble, the actions and the window; sent to the
  /// launcher's engine with each snapshot.
  final ShipglowsFloatingLauncherGeometry geometry;

  final _selections = StreamController<String>.broadcast();
  final _bubbleTaps = StreamController<void>.broadcast();
  final _hideRequests = StreamController<void>.broadcast();
  late final StreamSubscription<ShipglowsOverlayMessage> _subscription;
  ShipglowsFloatingLauncherSnapshot? _snapshot;
  // show() was called and hide() not since: the launcher is on screen or
  // about to be.
  bool _shown = false;

  /// Ids of the actions clicked in the launcher. Run them here, in the
  /// app's engine; the fan has already folded back.
  Stream<String> get selections => _selections.stream;

  /// Clicks on the bubble itself, for the app's primary action (opening its
  /// window, say). Nothing happens when nobody listens.
  Stream<void> get bubbleTaps => _bubbleTaps.stream;

  /// The user chose the `hideLabel` row of the bubble's right-click menu. The
  /// launcher stays until the app calls [hide], usually after saving the
  /// choice; the app keeps a way to show it again (a tray entry, a setting).
  Stream<void> get hideRequests => _hideRequests.stream;

  /// Whether the launcher is on screen.
  ValueListenable<bool> get visible => overlay.visible;

  /// Last snapshot given to [publish].
  ShipglowsFloatingLauncherSnapshot? get snapshot => _snapshot;

  /// Keeps [snapshot] for the next [show], and updates the launcher in place
  /// while it is on screen, or about to appear. Merging a burst of changes
  /// into one publish is up to the app.
  Future<void> publish(ShipglowsFloatingLauncherSnapshot snapshot) async {
    _snapshot = snapshot;
    if (overlay.visible.value) {
      await overlay.send(snapshotMessage, _payload());
    } else if (_shown) {
      // Still appearing (its engine starting): the pending opening takes
      // the new snapshot instead of the one show() carried.
      await overlay.show(data: _payload(), activate: false);
    }
  }

  /// Shows the launcher, folded, on the last snapshot (only the bubble
  /// before any), without taking the keyboard. Returns false when it could
  /// not be shown.
  Future<bool> show() {
    _shown = true;
    return overlay.show(data: _payload(), activate: false);
  }

  /// Hides the launcher; the keyboard stays where it is.
  Future<void> hide() {
    _shown = false;
    return overlay.hide(focus: OverlayHideFocus.none);
  }

  /// Closes the window and stops the launcher's engine.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _selections.close();
    await _bubbleTaps.close();
    await _hideRequests.close();
    await overlay.dispose();
  }

  Map<String, Object?> _payload() => <String, Object?>{
    ...?_snapshot?.toJson(),
    'geometry': geometry.toJson(),
  };

  void _onMessage(ShipglowsOverlayMessage message) {
    switch (message.method) {
      case selectMessage:
        final arguments = message.arguments;
        final id = arguments is Map ? arguments['id'] : null;
        if (id is String && !_selections.isClosed) _selections.add(id);
      case bubbleMessage:
        if (!_bubbleTaps.isClosed) _bubbleTaps.add(null);
      case hideMessage:
        if (!_hideRequests.isClosed) _hideRequests.add(null);
    }
  }
}
