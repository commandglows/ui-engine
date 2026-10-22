import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// `DWMWA_USE_IMMERSIVE_DARK_MODE`, Windows 10 20H1+ and Windows 11.
const int _immersiveDarkMode = 20;

/// Same attribute before Windows 10 20H1 (builds 17763 to 18362).
const int _immersiveDarkModeLegacy = 19;

/// `DWMWA_WINDOW_CORNER_PREFERENCE`, Windows 11 build 22000+.
const int _cornerPreference = 33;

/// `DWMWA_BORDER_COLOR`, Windows 11 build 22000+.
const int _borderColor = 34;

/// `DWMWA_CAPTION_COLOR`, Windows 11 build 22000+.
const int _captionColor = 35;

/// `DWMWA_TEXT_COLOR`, Windows 11 build 22000+.
const int _textColor = 36;

/// `DWMWCP_ROUND`: the system radius used by native Windows 11 windows.
const int _round = 2;

/// `DWMWCP_DONOTROUND`: the app draws its own corners.
const int _doNotRound = 1;

/// `DWMWA_COLOR_NONE`: no system border at all.
const int _colorNone = 0xFFFFFFFE;

/// `DWMWA_COLOR_DEFAULT`: lets Windows pick the border color again.
const int _colorDefault = 0xFFFFFFFF;

typedef _SetAttributeNative = Int32 Function(
  IntPtr hwnd,
  Uint32 attribute,
  Pointer<Void> value,
  Uint32 size,
);
typedef _SetAttribute = int Function(
  int hwnd,
  int attribute,
  Pointer<Void> value,
  int size,
);

_SetAttribute? _setAttribute;

/// With [systemCorners], asks DWM for rounded corners and a border of
/// [borderColorRef] (`0x00BBGGRR`, null for the system default); otherwise
/// turns both off so the app can draw its own. Older Windows versions reject
/// both attributes and keep their square frame.
///
/// A non-null [darkMode] overrides the system light/dark frame, and the
/// caption and its text take [captionColorRef] and [textColorRef] (system
/// colors when null). A null [darkMode] leaves all three to the runner.
void applyDwmFrame(
  int hwnd, {
  required int? borderColorRef,
  required bool systemCorners,
  required bool? darkMode,
  required int? captionColorRef,
  required int? textColorRef,
}) {
  final setAttribute = _setAttribute ??= DynamicLibrary.open(
    'dwmapi.dll',
  ).lookupFunction<_SetAttributeNative, _SetAttribute>('DwmSetWindowAttribute');
  final value = calloc<Uint32>();
  int set(int attribute, int newValue) {
    value.value = newValue;
    return setAttribute(hwnd, attribute, value.cast(), sizeOf<Uint32>());
  }

  try {
    set(_cornerPreference, systemCorners ? _round : _doNotRound);
    set(_borderColor, systemCorners ? borderColorRef ?? _colorDefault : _colorNone);
    if (darkMode == null) return;
    // S_OK is 0; builds before 20H1 only know the legacy attribute.
    if (set(_immersiveDarkMode, darkMode ? 1 : 0) != 0) {
      set(_immersiveDarkModeLegacy, darkMode ? 1 : 0);
    }
    set(_captionColor, captionColorRef ?? _colorDefault);
    set(_textColor, textColorRef ?? _colorDefault);
  } finally {
    calloc.free(value);
  }
}
