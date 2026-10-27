#include "include/shipglows_window/shipglows_window_plugin_c_api.h"

#include <windows.h>

#include <flutter/plugin_registrar_windows.h>

#include <memory>
#include <optional>

namespace shipglows_window {
namespace {

// Timer ids on the app window; distinct from the runner's own timers.
constexpr UINT_PTR kSettleTimer = 0x5B60;
constexpr UINT_PTR kRestoreTimer = 0x5B61;
// Quiet time after the last size change before the surface is rebuilt, so
// the snap animation and a drag resize are over.
constexpr UINT kSettleDelayMs = 300;
// Time left to the engine to present the shrunk frame before the view gets
// its real size back.
constexpr UINT kRestoreDelayMs = 250;

// The Windows engine resizes its render surface only for a frame of the
// size it is waiting for. When two sizes arrive back to back (a Win + arrow
// snap, from a quarter to a half especially), the second one can match the
// old surface: the engine then stops waiting, the surface keeps the first
// size and every later frame is stretched and cropped into it until the
// window size changes again.
//
// Once the size settles, the Flutter view is shrunk by one pixel and then
// given its size back: two real size changes that force the surface to
// match the window.
class ShipglowsWindowPlugin : public flutter::Plugin {
 public:
  explicit ShipglowsWindowPlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar) {
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleTopLevelMessage(hwnd, message, wparam, lparam);
        });
  }

  ~ShipglowsWindowPlugin() override {
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
    if (window_ != nullptr) {
      KillTimer(window_, kSettleTimer);
      KillTimer(window_, kRestoreTimer);
    }
  }

 private:
  std::optional<LRESULT> HandleTopLevelMessage(HWND hwnd, UINT message,
                                               WPARAM wparam, LPARAM) {
    if (message == WM_SIZE && wparam != SIZE_MINIMIZED) {
      window_ = hwnd;
      KillTimer(hwnd, kRestoreTimer);
      SetTimer(hwnd, kSettleTimer, kSettleDelayMs, nullptr);
    } else if (message == WM_TIMER && wparam == kSettleTimer) {
      KillTimer(hwnd, kSettleTimer);
      if (ResizeView(hwnd, -1)) {
        SetTimer(hwnd, kRestoreTimer, kRestoreDelayMs, nullptr);
      }
      return 0;
    } else if (message == WM_TIMER && wparam == kRestoreTimer) {
      KillTimer(hwnd, kRestoreTimer);
      ResizeView(hwnd, 0);
      return 0;
    }
    return std::nullopt;
  }

  // Sizes the Flutter view to the app window's client area, its height
  // changed by [delta] pixels; false when there is no view to size.
  bool ResizeView(HWND hwnd, int delta) {
    flutter::FlutterView* view = registrar_->GetView();
    HWND child = view ? view->GetNativeWindow() : nullptr;
    RECT client;
    if (child == nullptr || IsIconic(hwnd) || !GetClientRect(hwnd, &client)) {
      return false;
    }
    const int width = client.right - client.left;
    const int height = client.bottom - client.top + delta;
    if (width <= 0 || height <= 0) return false;
    SetWindowPos(child, nullptr, 0, 0, width, height,
                 SWP_NOMOVE | SWP_NOZORDER | SWP_NOACTIVATE);
    return true;
  }

  flutter::PluginRegistrarWindows* registrar_;
  int window_proc_id_ = 0;
  HWND window_ = nullptr;
};

}  // namespace
}  // namespace shipglows_window

void ShipglowsWindowPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows_registrar->AddPlugin(
      std::make_unique<shipglows_window::ShipglowsWindowPlugin>(
          windows_registrar));
}
