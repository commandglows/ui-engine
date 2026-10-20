import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:window_manager/window_manager.dart';

import 'dwm/dwm_frame_stub.dart'
    if (dart.library.ffi) 'dwm/dwm_frame_windows.dart';

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

  static bool _frameApplied = false;
  static Color? _frameBorderColor;

  /// Rounds the window corners like native Windows 11 windows and draws a
  /// 1 px border of [borderColor] around them (system color when null).
  ///
  /// The radius is the system one (~8 px); Windows 10 keeps square corners.
  /// No-op off Windows.
  static Future<void> setFrame({Color? borderColor}) async {
    if (!isSupported || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    if (_frameApplied && borderColor == _frameBorderColor) return;
    _frameApplied = true;
    _frameBorderColor = borderColor;
    final hwnd = await windowManager.getId();
    applyDwmFrame(
      hwnd,
      borderColorRef: borderColor == null ? null : _colorRef(borderColor),
    );
  }

  /// Win32 `COLORREF` (`0x00BBGGRR`); DWM borders have no alpha.
  static int _colorRef(Color color) {
    int channel(double value) => (value * 255).round() & 0xFF;
    return channel(color.b) << 16 | channel(color.g) << 8 | channel(color.r);
  }
}
