import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// `DWMWA_WINDOW_CORNER_PREFERENCE`, Windows 11 build 22000+.
const int _cornerPreference = 33;

/// `DWMWA_BORDER_COLOR`, Windows 11 build 22000+.
const int _borderColor = 34;

/// `DWMWCP_ROUND`: the system radius used by native Windows 11 windows.
const int _round = 2;

/// `DWMWCP_DONOTROUND`: the app draws its own corners.
const int _doNotRound = 1;

/// `DWMWA_COLOR_NONE`: no system border at all.
const int _colorNone = 0xFFFFFFFE;

/// `DWMWA_COLOR_DEFAULT`: lets Windows pick the border color again.
const int _colorDefault = 0xFFFFFFFF;

typedef _SetAttributeNative =
    Int32 Function(IntPtr hwnd, Uint32 attribute, Pointer<Void> value, Uint32 size);
typedef _SetAttribute =
    int Function(int hwnd, int attribute, Pointer<Void> value, int size);

_SetAttribute? _setAttribute;

/// With [systemCorners], asks DWM for rounded corners and a border of
/// [borderColorRef] (`0x00BBGGRR`, null for the system default); otherwise
/// turns both off so the app can draw its own. Older Windows versions reject
/// both attributes and keep their square frame.
void applyDwmFrame(
  int hwnd, {
  required int? borderColorRef,
  required bool systemCorners,
}) {
  final setAttribute = _setAttribute ??= DynamicLibrary.open(
    'dwmapi.dll',
  ).lookupFunction<_SetAttributeNative, _SetAttribute>('DwmSetWindowAttribute');
  final value = calloc<Uint32>();
  try {
    value.value = systemCorners ? _round : _doNotRound;
    setAttribute(hwnd, _cornerPreference, value.cast(), sizeOf<Uint32>());
    value.value = systemCorners
        ? borderColorRef ?? _colorDefault
        : _colorNone;
    setAttribute(hwnd, _borderColor, value.cast(), sizeOf<Uint32>());
  } finally {
    calloc.free(value);
  }
}
