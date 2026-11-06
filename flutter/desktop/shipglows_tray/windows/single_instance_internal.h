#ifndef SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_
#define SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_

#include <windows.h>

#include <functional>
#include <string>
#include <vector>

namespace shipglows_tray {

// WM_COPYDATA tag of a forwarded command line ('SGTR').
constexpr ULONG_PTR kCommandLineCopyData = 0x53475452;

using SecondInstanceHandler =
    std::function<void(const std::vector<std::wstring>& arguments)>;

// Creates, once per process, the hidden window a later instance sends its
// command line to. Every engine registers the plugin (overlays included), so
// the window cannot belong to one of them.
void EnsureInstanceReceiver();

// Routes forwarded command lines to |handler| (the engine that started the
// tray). Command lines received before are delivered right after.
void AttachSecondInstanceHandler(const void* owner,
                                 SecondInstanceHandler handler);
void DetachSecondInstanceHandler(const void* owner);

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_SINGLE_INSTANCE_INTERNAL_H_
