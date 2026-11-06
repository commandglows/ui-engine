import 'hotkey.dart';

/// Keeps the browser's own action for the bar's hotkey from running with the
/// bar. Nothing to guard outside the web.
class CommandBarBrowserGuard {
  /// Starts blocking the browser's action for [hotkey].
  void install(CommandBarHotkey hotkey) {}

  /// Stops blocking it.
  void remove() {}
}
