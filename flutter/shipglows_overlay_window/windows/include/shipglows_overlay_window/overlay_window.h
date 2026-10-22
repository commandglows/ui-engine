#ifndef SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_H_
#define SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_H_

#include <windows.h>

#include <flutter/binary_messenger.h>
#include <flutter/encodable_value.h>
#include <flutter/plugin_registry.h>

#include <functional>
#include <memory>
#include <optional>
#include <string>

#ifdef SHIPGLOWS_OVERLAY_WINDOW_IMPL
#define SHIPGLOWS_OVERLAY_EXPORT __declspec(dllexport)
#else
#define SHIPGLOWS_OVERLAY_EXPORT __declspec(dllimport)
#endif

namespace shipglows_overlay {

// How long the size the user gave the overlay by dragging its edges lasts.
enum class SizeMemory {
  kNone,        // Back to the default size at each opening.
  kSession,     // Kept until the app quits.
  kPersistent,  // Kept across launches.
};

// Where an overlay opens when it has no remembered position.
enum class Placement {
  kCursorMonitorCenter,
  // Centered horizontally, about a fifth of the way down (command bars).
  kCursorMonitorUpper,
  // Centered on the monitor of the window that was in front.
  kForegroundMonitorCenter,
};

// What a click outside the overlay (another window becoming active) does.
// Windows the overlay owns, such as a file dialog, never count as outside.
enum class OutsideClick {
  // Goes just behind the window clicked; back on top once reactivated.
  kBackground,
  // Hides (command bars).
  kClose,
  // Nothing: an always-on-top overlay stays above every window.
  kNone,
};

struct OverlayConfig {
  // Unique per process; also the key of the saved position and size.
  std::string id;
  // Dart entry point of the overlay engine (a top-level function annotated
  // with @pragma('vm:entry-point')). The engine receives |id| as its only
  // entry point argument.
  std::string entrypoint;
  std::wstring title;
  // Folder under %APPDATA% where bounds are saved, as in
  // ShipglowsWindowSession. Empty: nothing is saved.
  std::wstring app_folder;

  // Logical pixels, scaled to the monitor's DPI.
  int width = 640;
  int height = 440;
  int min_width = 240;
  int min_height = 120;
  // Space kept between the overlay and the monitor's work area edges.
  int margin = 16;
  // Fallback window region radius where DWM cannot round corners (Windows 10).
  int corner_radius = 12;

  // Stays above every other window, even when another app is active.
  bool always_on_top = true;
  // Own taskbar button and Alt+Tab entry; otherwise a tool window.
  bool show_in_taskbar = false;
  OutsideClick outside_click = OutsideClick::kBackground;
  // Invisible in screenshots and screen recordings.
  bool exclude_from_capture = false;
  // The edges can be dragged (startResize) and resetSize restores the size.
  bool resizable = true;
  // A double-click on the drag area maximizes, or restores.
  bool double_click_maximizes = true;
  SizeMemory size_memory = SizeMemory::kPersistent;
  // The position chosen by dragging is reused at the next opening and after
  // a restart (needs |app_folder|).
  bool remember_position = true;
  Placement placement = Placement::kCursorMonitorCenter;

  // See-through window: no system corners, border, shadow or background;
  // the Flutter view draws the whole shape, transparent pixels included.
  bool transparent = false;

  // Dark DWM frame and 1 px border color (Windows 11).
  bool dark_frame = true;
  std::optional<COLORREF> border_color;
  // Painted under the view: the strip Windows may expose when a resize step
  // outruns the engine's frame. None: left to the system (black).
  std::optional<COLORREF> background_color;

  // Registers the plugins the overlay engine needs. None by default: an
  // engine that registers a process-wide plugin twice can break it.
  std::function<void(flutter::PluginRegistry*)> register_plugins;
  // Where the position lives, for an app that already stores it elsewhere.
  // Both set: they replace the JSON file for the position (read at each
  // opening, written when a move ends).
  std::function<std::optional<POINT>()> load_position;
  std::function<void(POINT)> save_position;

  // Runner extension points. |on_created| runs once the window and its
  // engine exist, before any message from Dart. |message_hook| sees the
  // messages of the top-level window before the overlay's own handling;
  // returning a value consumes it. The borderless frame messages
  // (WM_NCCALCSIZE, WM_NCACTIVATE, WM_NCPAINT, caption repaints, WM_SETTEXT,
  // WM_SETICON, and the menu mode of Alt alone) are handled before it and
  // never reach it.
  std::function<void(HWND window)> on_created;
  std::function<std::optional<LRESULT>(HWND, UINT, WPARAM, LPARAM)>
      message_hook;
  // Messages the overlay sends with ShipglowsOverlayHost.send and visibility
  // changes, for an overlay created natively. An overlay created from Dart
  // reports them to its Dart owner instead.
  std::function<void(const std::string& method,
                     const flutter::EncodableValue& arguments)>
      on_message;
  std::function<void(bool visible)> on_visibility;
};

// An independent top-level window hosting its own Flutter engine. It is not
// owned by the main window: showing it never shows, raises or activates the
// main window.
class OverlayWindow {
 public:
  virtual ~OverlayWindow() = default;

  // Creates the window and starts its engine, hidden and unable to take the
  // keyboard. A failure is latched. Returns true when ready to show.
  virtual bool Prepare() = 0;

  // Sends |data| to the overlay's onShow handler and reveals the window once
  // Dart has drawn it, so stale content never flashes. With |activate| the
  // overlay takes the keyboard (focus returns to the previous window when it
  // hides); otherwise it shows without taking focus.
  virtual bool Show(const flutter::EncodableValue& data, bool activate) = 0;
  // Hides the overlay. Focus goes back to the window that was in front
  // before it, if the overlay still had focus.
  virtual void Hide() = 0;
  virtual bool visible() const = 0;
  // Whether the overlay's Dart code called ShipglowsOverlayHost.ready.
  virtual bool ready() const = 0;

  // Sends a message to ShipglowsOverlayHost.messages.
  virtual void Send(const std::string& method,
                    const flutter::EncodableValue& arguments) = 0;

  // Lower-level presentation for runners that draw native content in the
  // window before the Flutter view (ContentGlows' capture chooser).
  //
  // Places the window (remembered position, else |placement|) at |width| x
  // |height| logical pixels and shows the frame only, without the Flutter
  // view. Returns whether it is visible (and active, with |activate|).
  virtual bool ShowFrame(int width, int height, bool activate) = 0;
  // Shows or hides the Flutter view inside the visible frame.
  virtual void SetViewVisible(bool shown, bool focus) = 0;
  // Bounds of a |width| x |height| logical window centered on the current
  // one, kept inside the monitor's work area.
  virtual RECT BoundsAround(int width, int height) = 0;
  // Brings the visible overlay to the front with the keyboard.
  virtual bool Activate() = 0;
  virtual void StartDrag() = 0;

  virtual HWND window() const = 0;
  virtual HWND view() const = 0;
  virtual flutter::BinaryMessenger* messenger() const = 0;
  virtual void SetNextFrameCallback(std::function<void()> callback) = 0;
  virtual void ForceRedraw() = 0;
};

}  // namespace shipglows_overlay

// Creates a native overlay. Owned by the caller; the window closes when it is
// deleted. Returns null if another overlay already uses |config.id|.
extern "C++" SHIPGLOWS_OVERLAY_EXPORT std::unique_ptr<shipglows_overlay::OverlayWindow>
ShipglowsOverlayWindowCreate(const shipglows_overlay::OverlayConfig& config);

// Registers the plugins of overlays created from Dart. Call it once in the
// runner, before the first overlay is prepared. Without it those engines
// register no plugin.
extern "C++" SHIPGLOWS_OVERLAY_EXPORT void ShipglowsOverlayWindowSetPluginRegistrant(
    std::function<void(const std::string& id, flutter::PluginRegistry* registry)>
        registrant);

#endif  // SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_WINDOW_H_
