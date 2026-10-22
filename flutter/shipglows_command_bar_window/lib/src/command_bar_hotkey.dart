import 'dart:async';

import 'package:shipglows_hotkeys/shipglows_hotkeys.dart';

import 'command_bar_window.dart';

/// Opens the floating bar from a system-wide hotkey.
extension ShipglowsCommandBarHotkey on ShipglowsCommandBarWindow {
  /// Lets the hotkey [id] of [hotkeys] toggle the bar: a press closes it when
  /// open, otherwise opens it over the window in front, which gets the
  /// keyboard back when the bar closes (and receives a paste). The app's own
  /// window in front is no exception: the floating bar opens there too.
  ///
  /// Cancel the returned subscription to unbind.
  StreamSubscription<ShipglowsHotkeyEvent> bindHotkey(
    ShipglowsHotkeys hotkeys,
    String id,
  ) => hotkeys.events
      .where((event) => event.id == id)
      .listen(
        (event) =>
            unawaited(toggle(previousForeground: event.previousForeground)),
      );
}
