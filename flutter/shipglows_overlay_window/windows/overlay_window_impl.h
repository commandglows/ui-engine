#ifndef SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_
#define SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <chrono>
#include <memory>
#include <optional>
#include <string>

#include "include/shipglows_overlay_window/overlay_window.h"

namespace shipglows_overlay {

// Reports whether |id| is free and reserves it; released by the overlay.
bool ReserveOverlayId(const std::string& id);

// What gets the keyboard when the overlay hides.
enum class FocusReturn {
  // The window that was in front before the overlay, if the overlay still
  // had focus.
  kPrevious,
  // Nothing is activated; the app activates a window itself.
  kNone,
  // The app's main window (|set_app_window|), shown if hidden.
  kApp,
};

// "previous", "none" or "app"; anything else is kPrevious.
FocusReturn FocusReturnFrom(const std::string& name);

class OverlayWindowImpl : public OverlayWindow {
 public:
  explicit OverlayWindowImpl(OverlayConfig config);
  ~OverlayWindowImpl() override;

  OverlayWindowImpl(const OverlayWindowImpl&) = delete;
  OverlayWindowImpl& operator=(const OverlayWindowImpl&) = delete;

  // OverlayWindow:
  bool Prepare() override;
  bool Show(const flutter::EncodableValue& data, bool activate) override;
  void Hide() override;
  bool visible() const override;
  bool ready() const override { return ready_; }
  void Send(const std::string& method,
            const flutter::EncodableValue& arguments) override;
  bool ShowFrame(int width, int height, bool activate) override;
  void SetViewVisible(bool shown, bool focus) override;
  RECT BoundsAround(int width, int height) override;
  bool Activate() override;
  void StartDrag() override;
  HWND window() const override { return window_; }
  HWND view() const override;
  flutter::BinaryMessenger* messenger() const override;
  void SetNextFrameCallback(std::function<void()> callback) override;
  void ForceRedraw() override;

  // Show with the window focus returns to on hide. Null: the window in
  // front now.
  bool ShowFrom(const flutter::EncodableValue& data, bool activate,
                HWND previous_foreground);
  void HideWithFocus(FocusReturn focus);
  // Window in front before the overlay opened; null once it hid.
  HWND previous_foreground() const { return previous_foreground_; }
  // Main window of the app that created the overlay, for FocusReturn::kApp.
  void set_app_window(HWND window) { app_window_ = window; }

 private:
  static LRESULT CALLBACK WndProc(HWND hwnd, UINT message, WPARAM wparam,
                                  LPARAM lparam) noexcept;
  LRESULT HandleMessage(HWND hwnd, UINT message, WPARAM wparam,
                        LPARAM lparam);
  // Keeps the window borderless; runs before |message_hook|.
  std::optional<LRESULT> HandleFrameMessage(HWND hwnd, UINT message,
                                            WPARAM wparam, LPARAM lparam);
  bool CreateOverlay();
  void DestroyOverlay();
  void HandleHostCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

  // Moves and sizes the hidden or visible window for an opening.
  void Place(int width, int height);
  // Logical size of the next opening: remembered, else |width| x |height|.
  SIZE OpeningSize(int width, int height) const;
  std::optional<POINT> LoadPosition() const;
  RECT ClampedBounds(const RECT& anchor, int width, int height) const;
  void FitViewToClient();
  // Sizes the view; blocks until the engine drew a frame of that size.
  void FitView(int width, int height);
  // Programmatic bounds change, eased like a system animation.
  void MoveTo(const RECT& bounds);
  void StepAnimation();
  void StopAnimation();
  void UpdateRegion();
  void StartPresentation();
  void Reveal(int64_t generation);
  void HideWindow(FocusReturn focus);
  // Dark frame and border color (DWM) from |config_|.
  void ApplyFrameStyle();
  // Lets the view's transparent pixels show through (|config_.transparent|).
  void MakeTransparent();
  // Host "setFrame": darkFrame, borderColor, backgroundColor (ARGB).
  void SetFrameStyle(const flutter::EncodableValue* arguments);
  // Applies |OverlayConfig::outside_click| when another window becomes
  // active, and puts a backgrounded overlay back on top when it is active
  // again. Runs before the runner's message hook, which cannot skip it.
  void OnActivate(WPARAM wparam);
  // Places the overlay just behind the window now in front.
  void SendBehindForeground();
  // Alt+F4, Escape or the system close command: the overlay decides once it
  // is ready, otherwise the window just hides.
  void RequestClose();
  void SaveBounds(bool size_changed);
  void StartResize(const std::string& edge);
  void ResetSize();
  void ToggleMaximize();
  void NotifyVisibility(bool shown);
  void InvokeHost(const std::string& method,
                  std::unique_ptr<flutter::EncodableValue> arguments);

  OverlayConfig config_;
  HWND window_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND previous_foreground_ = nullptr;
  HWND app_window_ = nullptr;
  bool prepare_failed_ = false;
  bool native_corners_ = false;
  // True once the DWM frame attributes are set; before that, no region.
  bool frame_ready_ = false;
  bool ready_ = false;
  // The window is shown (frame, view, or both).
  bool visible_ = false;
  bool view_visible_ = false;
  // Show was called; the window appears once Dart has drawn the data.
  bool reveal_pending_ = false;
  bool activate_on_reveal_ = false;
  // True while the overlay activates itself; its own focus changes are not a
  // deactivation.
  bool activating_ = false;
  // Lost its topmost place after a click outside (OutsideClick::kBackground).
  bool sent_back_ = false;
  int64_t generation_ = 0;
  flutter::EncodableValue pending_data_;
  // Remembered position (physical) and size (logical) of the next opening.
  std::optional<POINT> position_;
  std::optional<SIZE> size_;
  SIZE size_before_move_{};
  // Eased move or resize in progress (resetSize), stepped by a timer.
  struct Animation {
    RECT from;
    RECT to;
    std::chrono::steady_clock::time_point start;
  };
  std::optional<Animation> animation_;
  // Last opening size requested, used by resetSize.
  int default_width_ = 0;
  int default_height_ = 0;
};

}  // namespace shipglows_overlay

#endif  // SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_
