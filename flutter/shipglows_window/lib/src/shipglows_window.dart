import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

/// Entry point that swaps the native title bar for the ShipGlows one.
abstract final class ShipglowsWindow {
  /// Whether the current host is a desktop target with custom window chrome.
  static bool get isSupported {
    if (kIsWeb) return false;
    return switch (defaultTargetPlatform) {
      TargetPlatform.windows ||
      TargetPlatform.linux ||
      TargetPlatform.macOS => true,
      _ => false,
    };
  }

  /// Whether this host draws its own minimize/maximize/close buttons.
  ///
  /// macOS keeps the native traffic lights; Windows and Linux use ours.
  static bool get drawsCaptionButtons =>
      isSupported && defaultTargetPlatform != TargetPlatform.macOS;

  /// Hides the native title bar before the first frame.
  ///
  /// Call after the Flutter binding is initialized and before `runApp`; the
  /// standard runner only shows the window once the first frame is ready, so
  /// the native bar never flashes. No-op on mobile and web.
  static Future<void> ensureInitialized({Size? minimumSize}) async {
    if (!isSupported) return;
    await windowManager.ensureInitialized();
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: !drawsCaptionButtons,
    );
    if (minimumSize != null) {
      await windowManager.setMinimumSize(minimumSize);
    }
  }
}
