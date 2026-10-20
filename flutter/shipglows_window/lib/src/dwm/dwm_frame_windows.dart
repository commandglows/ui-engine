import 'dart:ffi';

import 'package:ffi/ffi.dart';

/// `DWMWA_WINDOW_CORNER_PREFERENCE`, Windows 11 build 22000+.
const int _cornerPreference = 33;

/// `DWMWA_BORDER_COLOR`, Windows 11 build 22000+.
const int _borderColor = 34;

/// `DWMWCP_ROUND`: the system radius used by native Windows 11 windows.
const int _round = 2;

/// `DWMWA_COLOR_DEFAULT`: lets Windows pick the border color again.
const int _colorDefault = 0xFFFFFFFF;

typedef _SetAttributeNative =
    Int32 Function(IntPtr hwnd, Uint32 attribute, Pointer<Void> value, Uint32 size);
typedef _SetAttribute =
    int Function(int hwnd, int attribute, Pointer<Void> value, int size);

_SetAttribute? _setAttribute;

/// Asks DWM for rounded corners and a border of [borderColorRef]
/// (`0x00BBGGRR`, null for the system default). Older Windows versions
/// reject both attributes: the window simply keeps its square frame.
void applyDwmFrame(int hwnd, {required int? borderColorRef}) {
  final setAttribute = _setAttribute ??= DynamicLibrary.open(
    'dwmapi.dll',
  ).lookupFunction<_SetAttributeNative, _SetAttribute>('DwmSetWindowAttribute');
  final value = calloc<Uint32>();
  try {
    value.value = _round;
    setAttribute(hwnd, _cornerPreference, value.cast(), sizeOf<Uint32>());
    value.value = borderColorRef ?? _colorDefault;
    setAttribute(hwnd, _borderColor, value.cast(), sizeOf<Uint32>());
  } finally {
    calloc.free(value);
  }
}
