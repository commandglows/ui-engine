import 'dart:async';

import 'package:shipglows_hotkeys/shipglows_hotkeys.dart';

import 'command_bar_window.dart';

/// Opens the floating bar from a system-wide hotkey.
extension ShipglowsCommandBarHotkey on ShipglowsCommandBarWindow {
  /// Lets the hotkey [id] of [hotkeys] toggle the bar: a press closes it when
  /// open, otherwise opens it over the window in front, which gets the
  /// keyboard back when the bar closes (and receives a paste).
  ///
  /// With the app's own window in front, [openInApp] runs instead when given
  /// (the in-app palette, for example); without it the floating bar opens
  /// there too and gives the keyboard back to the app.
  ///
  /// Cancel the returned subscription to unbind.
  StreamSubscription<ShipglowsHotkeyEvent> bindHotkey(
    ShipglowsHotkeys hotkeys,
    String id, {
    FutureOr<void> Function()? openInApp,
  }) => hotkeys.events
      .where((event) => event.id == id)
      .listen((event) => unawaited(_onHotkey(event, openInApp)));

  Future<void> _onHotkey(
    ShipglowsHotkeyEvent event,
    FutureOr<void> Function()? openInApp,
  ) async {
    if (visible.value) {
      await close();
      return;
    }
    if (event.foreground == ShipglowsHotkeyForeground.app &&
        openInApp != null) {
      await openInApp();
      return;
    }
    await open(previousForeground: event.previousForeground);
  }
}
