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
  static bool _frameSystemCorners = true;
  static Brightness? _frameBrightness;
  static Color? _frameCaptionColor;
  static Color? _frameCaptionTextColor;

  /// Shapes the window frame on Windows 11; no-op elsewhere.
  ///
  /// With [systemCorners] the window gets the native rounded corners (~8 px)
  /// and a 1 px DWM border of [borderColor] (system color when null).
  /// Without it the window turns transparent and the native corners and
  /// border are removed, so the app can clip its own radius (see
  /// [ShipglowsWindowFrame.cornerRadius]). Windows 10 keeps square corners.
  ///
  /// A non-null [brightness] makes the native frame follow the app theme
  /// instead of the Windows one: dark or light frame, caption filled with
  /// [captionColor] and its text drawn in [captionTextColor] (system colors
  /// when null). Null leaves the frame to the runner. [force] reapplies
  /// even unchanged values, after something else (the Flutter runner
  /// template on a Windows theme change) has overwritten them.
  static Future<void> setFrame({
    Color? borderColor,
    bool systemCorners = true,
    Brightness? brightness,
    Color? captionColor,
    Color? captionTextColor,
    bool force = false,
  }) async {
    if (!isSupported || defaultTargetPlatform != TargetPlatform.windows) {
      return;
    }
    if (!force &&
        _frameApplied &&
        borderColor == _frameBorderColor &&
        systemCorners == _frameSystemCorners &&
        brightness == _frameBrightness &&
        captionColor == _frameCaptionColor &&
        captionTextColor == _frameCaptionTextColor) {
      return;
    }
    final wasSystemCorners = !_frameApplied || _frameSystemCorners;
    _frameApplied = true;
    _frameBorderColor = borderColor;
    _frameSystemCorners = systemCorners;
    _frameBrightness = brightness;
    _frameCaptionColor = captionColor;
    _frameCaptionTextColor = captionTextColor;
    final hwnd = await windowManager.getId();
    applyDwmFrame(
      hwnd,
      borderColorRef: borderColor == null ? null : _colorRef(borderColor),
      systemCorners: systemCorners,
      darkMode: brightness == null ? null : brightness == Brightness.dark,
      captionColorRef: captionColor == null ? null : _colorRef(captionColor),
      textColorRef: captionTextColor == null
          ? null
          : _colorRef(captionTextColor),
    );
    if (!systemCorners) {
      if (!wasSystemCorners) return;
      // Frameless: no DWM border left to draw a straight line past the
      // rounded corners; ShipglowsWindowFrame brings the resize edges back.
      await windowManager.setAsFrameless();
      await windowManager.setBackgroundColor(const Color(0x00000000));
    } else if (!wasSystemCorners) {
      await windowManager.setBackgroundColor(const Color(0xFF000000));
    }
  }

  /// Win32 `COLORREF` (`0x00BBGGRR`); DWM colors have no alpha.
  static int _colorRef(Color color) {
    int channel(double value) => (value * 255).round() & 0xFF;
    return channel(color.b) << 16 | channel(color.g) << 8 | channel(color.r);
  }
}
