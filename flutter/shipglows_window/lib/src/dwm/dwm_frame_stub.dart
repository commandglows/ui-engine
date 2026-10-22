/// No DWM off Windows desktop builds (web has no `dart:ffi`).
void applyDwmFrame(
  int hwnd, {
  required int? borderColorRef,
  required bool systemCorners,
  required bool? darkMode,
  required int? captionColorRef,
  required int? textColorRef,
}) {}
