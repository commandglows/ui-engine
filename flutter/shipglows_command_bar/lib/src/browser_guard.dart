/// Keeps the browser's own Ctrl/⌘+K (address bar search) from running with
/// the bar. Nothing to guard outside the web.
class CommandBarBrowserGuard {
  /// Starts blocking the browser shortcut.
  void install() {}

  /// Stops blocking it.
  void remove() {}
}
