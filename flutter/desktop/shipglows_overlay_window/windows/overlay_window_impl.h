#ifndef SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_
#define SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_

#include <flutter/flutter_view_controller.h>
#include <flutter/method_channel.h>

#include <chrono>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <vector>

#include "include/shipglows_overlay_window/overlay_window.h"
#include "overlay_store.h"

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
  void SetSizedView(const std::string& view) override;
  std::optional<SIZE> ViewSize(const std::string& view) override;
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
  // |anchor| resized to |width| x |height| around its center, moved inside
  // the work area: the whole window, or only |OverlayConfig::clamp_rect|.
  RECT ClampedBounds(const RECT& anchor, int width, int height) const;
  // Screen bounds of |OverlayConfig::clamp_rect| for a window at |bounds|;
  // |bounds| itself without one.
  RECT CoreBounds(const RECT& bounds) const;
  // Moves the window back so its clamp rect is on screen (displays or work
  // area changed). Only with |OverlayConfig::clamp_rect|.
  void Reclamp();
  // Work area of the overlay's monitor in logical pixels, relative to the
  // window's top-left corner: {left, top, right, bottom}. Null if unknown.
  flutter::EncodableValue WorkAreaValue() const;
  // Tells the overlay's Dart side the work area changed (moved, DPI,
  // displays), once it is ready.
  void NotifyPlacement();
  // Host "setShape": a list of [left, top, right, bottom, radius] logical
  // rounded rectangles, or null to drop the shape.
  void SetShape(const flutter::EncodableValue* arguments);
  // Drag of an overlay that does not activate on click: the window follows
  // the cursor while it holds the mouse capture.
  void StartCapturedDrag();
  void StepCapturedDrag();
  void EndCapturedDrag();
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
  // "show" arguments for the host: generation, data, previous foreground
  // window and work area.
  std::unique_ptr<flutter::EncodableValue> ShowArguments(
      const flutter::EncodableValue& data);
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
  // Keeps the current size for |sized_view_|, after the user resized.
  void SaveViewSize();
  // Host "readValue" / "writeValue": small integers the overlay keeps for
  // itself (a splitter position), beside its bounds.
  std::optional<int64_t> ReadValue(const std::string& key);
  void WriteValue(const std::string& key, std::optional<int64_t> value);
  // Fields of this overlay's entry: from the JSON file with an app folder,
  // else from memory until the app quits.
  StoredFields LoadFields();
  void SaveFields(
      const std::map<std::string, std::optional<long long>>& changes);
  void StartResize(const std::string& edge);
  // Second half of a drag that starts on a maximized overlay.
  void DragRestored();
  void ResetSize();
  void ToggleMaximize();
  // Whether the overlay fills its monitor's work area (|restore_bounds_|,
  // or a system maximize).
  bool Maximized() const;
  // Tells the overlay's Dart side when |restore_bounds_| is set or cleared.
  void NotifyMaximized();
  void NotifyVisibility(bool shown);
  void InvokeHost(const std::string& method,
                  std::unique_ptr<flutter::EncodableValue> arguments);

  OverlayConfig config_;
  HWND window_ = nullptr;
  std::unique_ptr<flutter::FlutterViewController> controller_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND previous_foreground_ = nullptr;
  // Bounds before ToggleMaximize filled the work area; set while maximized.
  // The system maximize is not used: on a borderless, possibly transparent
  // window it misplaces the frame (outside the monitor, off the work area).
  std::optional<RECT> restore_bounds_;
  bool notified_maximized_ = false;
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
  // View whose size a user resize keeps (SetSizedView); empty: none.
  std::string sized_view_;
  // Eased move or resize in progress (resetSize), stepped by a timer.
  struct Animation {
    RECT from;
    RECT to;
    std::chrono::steady_clock::time_point start;
  };
  std::optional<Animation> animation_;
  // Window shape set by the overlay (host "setShape"), logical pixels from
  // the window's top-left corner. Replaces the default region while set.
  struct ShapeRect {
    double left;
    double top;
    double right;
    double bottom;
    double radius;
  };
  std::optional<std::vector<ShapeRect>> shape_;
  // Drag in progress without the system move loop: where the cursor holds
  // the window, in logical pixels from its top-left corner (kept across a
  // DPI change between monitors).
  struct CapturedDrag {
    double offset_x;
    double offset_y;
  };
  std::optional<CapturedDrag> captured_drag_;
  // Last opening size requested, used by resetSize.
  int default_width_ = 0;
  int default_height_ = 0;
};

}  // namespace shipglows_overlay

#endif  // SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_IMPL_H_
