#ifndef FLUTTER_PLUGIN_SHIPGLOWS_HOTKEYS_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_SHIPGLOWS_HOTKEYS_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef SHIPGLOWS_HOTKEYS_IMPL
#define SHIPGLOWS_HOTKEYS_PLUGIN_EXPORT __declspec(dllexport)
#else
#define SHIPGLOWS_HOTKEYS_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

SHIPGLOWS_HOTKEYS_PLUGIN_EXPORT void
ShipglowsHotkeysPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_SHIPGLOWS_HOTKEYS_PLUGIN_C_API_H_
