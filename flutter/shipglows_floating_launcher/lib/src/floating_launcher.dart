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
/// back there at the next launch (with an `appFolder` in [defaultOptions]).
///
/// Windows only; elsewhere [show] returns false and nothing is shown.
class ShipglowsFloatingLauncher {
  ShipglowsFloatingLauncher({
    required String entrypoint,
    String id = 'shipglows_floating_launcher',
    this.geometry = const ShipglowsFloatingLauncherGeometry(),
    ShipglowsOverlayOptions? options,
  }) : overlay = ShipglowsOverlayWindow(
         id: id,
         entrypoint: entrypoint,
         options: options ?? defaultOptions(geometry: geometry),
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
  late final StreamSubscription<ShipglowsOverlayMessage> _subscription;
  ShipglowsFloatingLauncherSnapshot? _snapshot;

  /// Ids of the actions clicked in the launcher. Run them here, in the
  /// app's engine; the fan has already folded back.
  Stream<String> get selections => _selections.stream;

  /// Clicks on the bubble itself, for the app's primary action (opening its
  /// window, say). Nothing happens when nobody listens.
  Stream<void> get bubbleTaps => _bubbleTaps.stream;

  /// Whether the launcher is on screen.
  ValueListenable<bool> get visible => overlay.visible;

  /// Last snapshot given to [publish].
  ShipglowsFloatingLauncherSnapshot? get snapshot => _snapshot;

  /// Keeps [snapshot] for the next [show], and updates the launcher in place
  /// while it is on screen. Merging a burst of changes into one publish is
  /// up to the app.
  Future<void> publish(ShipglowsFloatingLauncherSnapshot snapshot) async {
    _snapshot = snapshot;
    if (overlay.visible.value) {
      await overlay.send(snapshotMessage, _payload());
    }
  }

  /// Shows the launcher, folded, on the last snapshot (only the bubble
  /// before any), without taking the keyboard. Returns false when it could
  /// not be shown.
  Future<bool> show() => overlay.show(data: _payload(), activate: false);

  /// Hides the launcher; the keyboard stays where it is.
  Future<void> hide() => overlay.hide(focus: OverlayHideFocus.none);

  /// Closes the window and stops the launcher's engine.
  Future<void> dispose() async {
    await _subscription.cancel();
    await _selections.close();
    await _bubbleTaps.close();
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
    }
  }
}
