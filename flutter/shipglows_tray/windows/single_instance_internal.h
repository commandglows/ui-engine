#ifndef SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_
#define SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_

#include <windows.h>

#include <string>

namespace shipglows_tray {

// WM_COPYDATA tag of a forwarded command line ('SGTR').
constexpr ULONG_PTR kCommandLineCopyData = 0x53475452;

// Class of the hidden tray window, the one a later instance looks for:
// derived from the app id given to ShipglowsTrayForwardToPrimary, else
// unique to this process.
std::wstring HostWindowClass();

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_
