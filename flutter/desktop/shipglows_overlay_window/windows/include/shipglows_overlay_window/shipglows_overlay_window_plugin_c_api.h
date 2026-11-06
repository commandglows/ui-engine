#ifndef FLUTTER_PLUGIN_SHIPGLOWS_OVERLAY_WINDOW_PLUGIN_C_API_H_
#define FLUTTER_PLUGIN_SHIPGLOWS_OVERLAY_WINDOW_PLUGIN_C_API_H_

#include <flutter_plugin_registrar.h>

#ifdef SHIPGLOWS_OVERLAY_WINDOW_IMPL
#define SHIPGLOWS_OVERLAY_PLUGIN_EXPORT __declspec(dllexport)
#else
#define SHIPGLOWS_OVERLAY_PLUGIN_EXPORT __declspec(dllimport)
#endif

#if defined(__cplusplus)
extern "C" {
#endif

SHIPGLOWS_OVERLAY_PLUGIN_EXPORT void
ShipglowsOverlayWindowPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar);

#if defined(__cplusplus)
}  // extern "C"
#endif

#endif  // FLUTTER_PLUGIN_SHIPGLOWS_OVERLAY_WINDOW_PLUGIN_C_API_H_
