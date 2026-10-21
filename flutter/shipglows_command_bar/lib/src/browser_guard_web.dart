import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Keeps the browser's own Ctrl/⌘+K (address bar search) from running with
/// the bar.
///
/// Flutter web does not cancel the default action of a modifier shortcut it
/// handles, so Chrome would also move the focus to its address bar. The page
/// cancels it in the capture phase; Flutter still receives the key.
class CommandBarBrowserGuard {
  JSFunction? _listener;

  /// Starts blocking the browser shortcut.
  void install() {
    if (_listener != null) return;
    final listener = _onKeyDown.toJS;
    _listener = listener;
    web.window.addEventListener('keydown', listener, true.toJS);
  }

  /// Stops blocking it.
  void remove() {
    final listener = _listener;
    if (listener == null) return;
    web.window.removeEventListener('keydown', listener, true.toJS);
    _listener = null;
  }

  static void _onKeyDown(web.KeyboardEvent event) {
    if ((event.ctrlKey || event.metaKey) &&
        !event.altKey &&
        !event.shiftKey &&
        event.key.toLowerCase() == 'k') {
      event.preventDefault();
    }
  }
}
