import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'hotkey.dart';

/// Keeps the browser's own action for the bar's hotkey (Ctrl/⌘+K moves to
/// the address bar, for instance) from running with the bar.
///
/// Flutter web does not cancel the default action of a modifier shortcut it
/// handles. The page cancels it in the capture phase; Flutter still receives
/// the key.
class CommandBarBrowserGuard {
  JSFunction? _listener;
  CommandBarHotkey? _hotkey;

  /// Starts blocking the browser's action for [hotkey].
  void install(CommandBarHotkey hotkey) {
    _hotkey = hotkey;
    if (_listener != null) return;
    final listener = _onKeyDown.toJS;
    _listener = listener;
    web.window.addEventListener('keydown', listener, true.toJS);
  }

  /// Stops blocking it.
  void remove() {
    _hotkey = null;
    final listener = _listener;
    if (listener == null) return;
    web.window.removeEventListener('keydown', listener, true.toJS);
    _listener = null;
  }

  void _onKeyDown(web.KeyboardEvent event) {
    final hotkey = _hotkey;
    if (hotkey == null) return;
    if (event.ctrlKey == hotkey.control &&
        event.altKey == hotkey.alt &&
        event.shiftKey == hotkey.shift &&
        event.metaKey == hotkey.meta &&
        commandBarVirtualKeyOfBrowserKey(event.key) == hotkey.key) {
      event.preventDefault();
    }
  }
}
