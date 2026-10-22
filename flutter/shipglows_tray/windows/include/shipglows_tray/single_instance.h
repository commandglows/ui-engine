#ifndef SHIPGLOWS_TRAY_SINGLE_INSTANCE_H_
#define SHIPGLOWS_TRAY_SINGLE_INSTANCE_H_

#include <windows.h>

#ifdef SHIPGLOWS_TRAY_IMPL
#define SHIPGLOWS_TRAY_EXPORT __declspec(dllexport)
#else
#define SHIPGLOWS_TRAY_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

// Keeps the app to one instance per Windows session. Call it in wWinMain,
// before creating the Flutter window:
//
//   if (ShipglowsTrayForwardToPrimary(L"contentglows")) return EXIT_SUCCESS;
//
// |app_id| is a stable name unique to the app (letters, digits, dots,
// dashes). Returns false in the first instance, which goes on starting.
// Returns true in a later one, which must exit: its command line went to the
// first instance (ShipglowsTraySecondInstance in Dart, which by default also
// brings the main window to the front). Also true when the first instance
// did not answer within about 5 seconds (still starting or hung): starting a
// second one would be worse.
SHIPGLOWS_TRAY_EXPORT bool ShipglowsTrayForwardToPrimary(const wchar_t* app_id);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // SHIPGLOWS_TRAY_SINGLE_INSTANCE_H_
