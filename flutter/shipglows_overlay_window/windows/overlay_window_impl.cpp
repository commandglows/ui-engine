#include "overlay_window_impl.h"

#include <dwmapi.h>
#include <flutter/standard_method_codec.h>
#include <flutter_windows.h>

#include <algorithm>
#include <chrono>
#include <cmath>
#include <map>
#include <set>
#include <utility>

#include "overlay_store.h"
#include "window_activation.h"

namespace shipglows_overlay {
namespace {

constexpr wchar_t kWindowClass[] = L"SHIPGLOWS_OVERLAY_WINDOW";
constexpr char kHostChannel[] = "shipglows_overlay_window/host";
// Posted by the engine's next-frame callback to reveal the overlay. Away
// from the low WM_APP range that runner hooks commonly use.
constexpr UINT kRevealMessage = WM_APP + 0x2F0;
// Posted on deactivation: the window clicked is in front only once the
// activation change completes.
constexpr UINT kSendBackMessage = WM_APP + 0x2F1;
// Resource ID of the app icon in Flutter's Windows runner template.
constexpr int kAppIconResource = 101;
// Undocumented: the visual-styles engine sends these to repaint the caption
// and frame (on activation changes, caption hover, text or icon changes).
// DefWindowProc paints them with GDI straight into the window, over a client
// area that covers the whole window here.
constexpr UINT kNcUahDrawCaption = 0x00AE;
constexpr UINT kNcUahDrawFrame = 0x00AF;
// Timer of a programmatic move or resize (resetSize).
constexpr UINT_PTR kAnimationTimer = 1;
constexpr std::chrono::milliseconds kAnimationDuration{180};

std::set<std::string>& ReservedIds() {
  static std::set<std::string> ids;
  return ids;
}

// Sizes kept with SizeMemory::kSession, for the life of the process.
std::map<std::string, SIZE>& SessionSizes() {
  static std::map<std::string, SIZE> sizes;
  return sizes;
}

const flutter::EncodableValue* Field(const flutter::EncodableValue* value,
                                     const char* key) {
  const auto* map =
      value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

std::optional<int64_t> IntOf(const flutter::EncodableValue* value) {
  if (value == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(value)) return *v;
  if (const auto* v = std::get_if<int64_t>(value)) return *v;
  return std::nullopt;
}

int Scale(int logical, UINT dpi) { return MulDiv(logical, dpi, 96); }

}  // namespace

bool ReserveOverlayId(const std::string& id) {
  if (id.empty()) return false;
  return ReservedIds().insert(id).second;
}

OverlayWindowImpl::OverlayWindowImpl(OverlayConfig config)
    : config_(std::move(config)),
      default_width_(config_.width),
      default_height_(config_.height) {}

OverlayWindowImpl::~OverlayWindowImpl() {
  DestroyOverlay();
  ReservedIds().erase(config_.id);
}

bool OverlayWindowImpl::Prepare() {
  if (prepare_failed_) return false;
  if (window_) return controller_ != nullptr;
  if (!CreateOverlay()) {
    prepare_failed_ = true;
    DestroyOverlay();
    return false;
  }
  return true;
}

bool OverlayWindowImpl::CreateOverlay() {
  static const bool class_registered = [] {
    WNDCLASSW window_class{};
    window_class.lpfnWndProc = OverlayWindowImpl::WndProc;
    window_class.hCursor = LoadCursor(nullptr, IDC_ARROW);
    window_class.lpszClassName = kWindowClass;
    window_class.hInstance = GetModuleHandle(nullptr);
    window_class.hIcon =
        LoadIcon(window_class.hInstance, MAKEINTRESOURCE(kAppIconResource));
    return RegisterClassW(&window_class) != 0 ||
           GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
  }();
  if (!class_registered) return false;

  // The remembered size is read once per process; the position at each
  // opening (LoadPosition).
  if (!config_.app_folder.empty() &&
      config_.size_memory == SizeMemory::kPersistent) {
    size_ = LoadStoredBounds(config_.app_folder, config_.id).size;
  }
  if (config_.size_memory == SizeMemory::kSession) {
    const auto found = SessionSizes().find(config_.id);
    if (found != SessionSizes().end()) size_ = found->second;
  }

  POINT cursor{};
  GetCursorPos(&cursor);
  MONITORINFO info{sizeof(info)};
  GetMonitorInfoW(MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST), &info);
  const UINT dpi = FlutterDesktopGetDpiForMonitor(
      MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST));

  const DWORD ex_style =
      (config_.show_in_taskbar ? WS_EX_APPWINDOW : WS_EX_TOOLWINDOW) |
      (config_.always_on_top ? WS_EX_TOPMOST : 0);
  // The caption and frame styles let DWM draw rounded corners, the border
  // and the shadow; WM_NCCALCSIZE keeps the window borderless.
  DWORD style = WS_POPUP | WS_CAPTION | WS_THICKFRAME | WS_CLIPCHILDREN |
                WS_SYSMENU;
  if (config_.show_in_taskbar) style |= WS_MINIMIZEBOX;
  if (config_.double_click_maximizes) style |= WS_MAXIMIZEBOX;
  const HWND created = CreateWindowExW(
      ex_style, kWindowClass, config_.title.c_str(), style, info.rcWork.left,
      info.rcWork.top, Scale(config_.width, dpi), Scale(config_.height, dpi),
      nullptr, nullptr, GetModuleHandle(nullptr), this);
  if (created == nullptr) return false;
  window_ = created;

  const DWM_WINDOW_CORNER_PREFERENCE corners = DWMWCP_ROUND;
  native_corners_ = SUCCEEDED(DwmSetWindowAttribute(
      window_, DWMWA_WINDOW_CORNER_PREFERENCE, &corners, sizeof(corners)));
  const BOOL dark = config_.dark_frame ? TRUE : FALSE;
  DwmSetWindowAttribute(window_, DWMWA_USE_IMMERSIVE_DARK_MODE, &dark,
                        sizeof(dark));
  if (config_.border_color) {
    const COLORREF border = *config_.border_color;
    DwmSetWindowAttribute(window_, DWMWA_BORDER_COLOR, &border,
                          sizeof(border));
  }
  const MARGINS frame{1, 1, 1, 1};  // DWM needs a one-pixel frame.
  DwmExtendFrameIntoClientArea(window_, &frame);
  SetWindowPos(window_, nullptr, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE |
                   SWP_FRAMECHANGED);
  // Only now is it known whether DWM rounds the corners; the WM_SIZE sent
  // during CreateWindowExW must not have set a region (a region turns DWM
  // frame rendering off, bringing the legacy caption painter back).
  frame_ready_ = true;
  UpdateRegion();
  if (config_.exclude_from_capture) {
    SetWindowDisplayAffinity(window_, WDA_EXCLUDEFROMCAPTURE);
  }

  flutter::DartProject project(L"data");
  project.set_dart_entrypoint(config_.entrypoint);
  project.set_dart_entrypoint_arguments({config_.id});
  RECT client{};
  GetClientRect(window_, &client);
  controller_ = std::make_unique<flutter::FlutterViewController>(
      client.right - client.left, client.bottom - client.top, project);
  if (!controller_->engine() || !controller_->view()) return false;
  const HWND view_window = view();
  // Flutter may ask for focus during its first hidden frame: a preloaded
  // view cannot take the keyboard until the overlay is shown.
  EnableWindow(view_window, FALSE);
  ShowWindow(view_window, SW_HIDE);
  SetParent(view_window, window_);
  MoveWindow(view_window, 0, 0, client.right - client.left,
             client.bottom - client.top, FALSE);
  if (config_.register_plugins) config_.register_plugins(controller_->engine());

  channel_ = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
      controller_->engine()->messenger(), kHostChannel,
      &flutter::StandardMethodCodec::GetInstance());
  channel_->SetMethodCallHandler([this](const auto& call, auto result) {
    HandleHostCall(call, std::move(result));
  });
  if (config_.on_created) config_.on_created(window_);
  controller_->ForceRedraw();
  return true;
}

void OverlayWindowImpl::DestroyOverlay() {
  StopAnimation();
  ready_ = false;
  frame_ready_ = false;
  visible_ = false;
  view_visible_ = false;
  reveal_pending_ = false;
  ++generation_;
  channel_.reset();
  controller_.reset();
  if (window_) {
    const HWND hwnd = window_;
    window_ = nullptr;
    DestroyWindow(hwnd);
  }
}

void OverlayWindowImpl::HandleHostCall(
    const flutter::MethodCall<flutter::EncodableValue>& call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const std::string& method = call.method_name();
  if (method == "ready") {
    ready_ = true;
    result->Success(flutter::EncodableValue(flutter::EncodableMap{
        {flutter::EncodableValue("id"), flutter::EncodableValue(config_.id)},
        {flutter::EncodableValue("resizable"),
         flutter::EncodableValue(config_.resizable)},
        {flutter::EncodableValue("doubleClickMaximizes"),
         flutter::EncodableValue(config_.double_click_maximizes)},
    }));
    if (reveal_pending_) StartPresentation();
    return;
  }
  if (method == "presented") {
    const auto generation = IntOf(call.arguments());
    result->Success();
    if (reveal_pending_ && generation && *generation == generation_) {
      const HWND hwnd = window_;
      const int64_t pending = generation_;
      SetNextFrameCallback([hwnd, pending]() {
        PostMessageW(hwnd, kRevealMessage, static_cast<WPARAM>(pending), 0);
      });
      ForceRedraw();
    }
    return;
  }
  if (method == "hide") {
    result->Success();
    Hide();
    return;
  }
  if (method == "startDrag") {
    // Reply before the native move loop, which runs until the button is up.
    result->Success();
    StartDrag();
    return;
  }
  if (method == "startResize") {
    const auto* edge = call.arguments()
                           ? std::get_if<std::string>(call.arguments())
                           : nullptr;
    result->Success();
    if (edge) StartResize(*edge);
    return;
  }
  if (method == "resetSize") {
    result->Success();
    ResetSize();
    return;
  }
  if (method == "toggleMaximize") {
    result->Success();
    ToggleMaximize();
    return;
  }
  if (method == "send") {
    const auto* name = Field(call.arguments(), "method");
    const auto* text = name ? std::get_if<std::string>(name) : nullptr;
    if (text == nullptr || text->empty()) {
      result->Error("invalid_message", "A message needs a method name.");
      return;
    }
    const auto* arguments = Field(call.arguments(), "arguments");
    result->Success();
    if (config_.on_message) {
      config_.on_message(*text,
                         arguments ? *arguments : flutter::EncodableValue());
    }
    return;
  }
  result->NotImplemented();
}

bool OverlayWindowImpl::Show(const flutter::EncodableValue& data,
                             bool activate) {
  if (!Prepare()) return false;
  if (visible_ && view_visible_) {
    // Already on screen: hand over the new data, no new reveal.
    ++generation_;
    InvokeHost("show", std::make_unique<flutter::EncodableValue>(
                           flutter::EncodableMap{
                               {flutter::EncodableValue("generation"),
                                flutter::EncodableValue(generation_)},
                               {flutter::EncodableValue("data"), data},
                           }));
    return !activate || Activate();
  }
  pending_data_ = data;
  activate_on_reveal_ = activate_on_reveal_ || activate;
  if (!reveal_pending_) {
    previous_foreground_ = GetForegroundWindow();
    if (!visible_) Place(config_.width, config_.height);
    FitViewToClient();
    reveal_pending_ = true;
  }
  // Before "ready" Dart cannot draw yet; the reveal starts when it comes.
  if (ready_) StartPresentation();
  return true;
}

void OverlayWindowImpl::StartPresentation() {
  ++generation_;
  InvokeHost("show", std::make_unique<flutter::EncodableValue>(
                         flutter::EncodableMap{
                             {flutter::EncodableValue("generation"),
                              flutter::EncodableValue(generation_)},
                             {flutter::EncodableValue("data"), pending_data_},
                         }));
}

void OverlayWindowImpl::Reveal(int64_t generation) {
  if (!reveal_pending_ || generation != generation_ || !window_) return;
  reveal_pending_ = false;
  visible_ = true;
  pending_data_ = flutter::EncodableValue();
  SetViewVisible(true, false);
  if (activate_on_reveal_) {
    activating_ = true;
    ActivateWindowForUser(window_, view());
    activating_ = false;
  } else {
    ShowWindow(window_, SW_SHOWNA);
  }
  activate_on_reveal_ = false;
  if (config_.always_on_top) {
    SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
  NotifyVisibility(true);
}

void OverlayWindowImpl::Hide() { HideWindow(true); }

void OverlayWindowImpl::RequestClose() {
  if (ready_) {
    InvokeHost("requestClose", nullptr);
  } else {
    Hide();
  }
}

void OverlayWindowImpl::OnActivate(WPARAM wparam) {
  if (LOWORD(wparam) != WA_INACTIVE) {
    if (sent_back_ && config_.always_on_top) {
      SetWindowPos(window_, HWND_TOPMOST, 0, 0, 0, 0,
                   SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
    }
    sent_back_ = false;
    return;
  }
  if (!visible_ || activating_) return;
  switch (config_.outside_click) {
    case OutsideClick::kClose:
      HideWindow(false);
      break;
    case OutsideClick::kBackground:
      PostMessageW(window_, kSendBackMessage, 0, 0);
      break;
    case OutsideClick::kNone:
      break;
  }
}

void OverlayWindowImpl::SendBehindForeground() {
  if (!window_ || !visible_ || GetActiveWindow() == window_) return;
  const HWND foreground = GetForegroundWindow();
  // A window the overlay owns (a file dialog) belongs to it.
  if (foreground &&
      (foreground == window_ ||
       GetAncestor(foreground, GA_ROOTOWNER) == window_)) {
    return;
  }
  sent_back_ = true;
  SetWindowPos(window_, HWND_NOTOPMOST, 0, 0, 0, 0,
               SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  // Inserting after a topmost window would make the overlay topmost again:
  // leaving the topmost band is then enough.
  if (foreground &&
      !(GetWindowLongPtrW(foreground, GWL_EXSTYLE) & WS_EX_TOPMOST)) {
    SetWindowPos(window_, GetAncestor(foreground, GA_ROOT), 0, 0, 0, 0,
                 SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE);
  }
}

void OverlayWindowImpl::HideWindow(bool restore_focus) {
  if (!window_) return;
  if (!visible_ && !reveal_pending_ && !IsWindowVisible(window_)) return;
  const bool was_visible = visible_;
  StopAnimation();
  visible_ = false;
  reveal_pending_ = false;
  activate_on_reveal_ = false;
  ++generation_;
  InvokeHost("hidden", nullptr);
  const HWND previous = previous_foreground_;
  previous_foreground_ = nullptr;
  // Give focus back only while the overlay still held it: a user who has
  // moved to another window keeps it.
  if (restore_focus && GetForegroundWindow() == window_ && previous &&
      previous != window_ && IsWindow(previous) && IsWindowVisible(previous)) {
    SetForegroundWindow(previous);
  }
  // Hide the window before its view: a window without its view shows, for a
  // frame, the caption buttons DWM draws under it.
  ShowWindow(window_, SW_HIDE);
  SetViewVisible(false, false);
  if (was_visible) NotifyVisibility(false);
}

bool OverlayWindowImpl::visible() const {
  return visible_ && window_ && IsWindowVisible(window_);
}

void OverlayWindowImpl::Send(const std::string& method,
                             const flutter::EncodableValue& arguments) {
  InvokeHost("message", std::make_unique<flutter::EncodableValue>(
                            flutter::EncodableMap{
                                {flutter::EncodableValue("method"),
                                 flutter::EncodableValue(method)},
                                {flutter::EncodableValue("arguments"),
                                 arguments},
                            }));
}

bool OverlayWindowImpl::ShowFrame(int width, int height, bool activate) {
  if (!Prepare()) return false;
  if (IsWindowVisible(window_)) return !activate || Activate();
  previous_foreground_ = GetForegroundWindow();
  reveal_pending_ = false;
  ++generation_;
  SetViewVisible(false, false);
  Place(width, height);
  visible_ = true;
  bool shown = true;
  if (activate) {
    activating_ = true;
    shown = ActivateWindowForUser(window_, window_);
    activating_ = false;
  } else {
    ShowWindow(window_, SW_SHOWNA);
  }
  NotifyVisibility(true);
  return shown;
}

void OverlayWindowImpl::SetViewVisible(bool shown, bool focus) {
  const HWND view_window = view();
  if (view_window == nullptr) return;
  view_visible_ = shown;
  if (!shown) {
    EnableWindow(view_window, FALSE);
    ShowWindow(view_window, SW_HIDE);
    return;
  }
  EnableWindow(view_window, TRUE);
  ShowWindow(view_window, SW_SHOWNOACTIVATE);
  // Readiness is asynchronous: never take focus back from another app.
  if (focus && GetForegroundWindow() == window_) SetFocus(view_window);
}

bool OverlayWindowImpl::Activate() {
  if (!window_ || !IsWindowVisible(window_)) return false;
  activating_ = true;
  const bool activated =
      ActivateWindowForUser(window_, view_visible_ ? view() : window_);
  activating_ = false;
  return activated;
}

void OverlayWindowImpl::StartDrag() {
  if (!window_) return;
  ReleaseCapture();
  POINT cursor{};
  GetCursorPos(&cursor);
  SendMessageW(window_, WM_NCLBUTTONDOWN, HTCAPTION,
               MAKELPARAM(cursor.x, cursor.y));
}

void OverlayWindowImpl::StartResize(const std::string& edge) {
  if (!window_ || !config_.resizable || IsZoomed(window_)) return;
  static const std::map<std::string, WPARAM> kHits = {
      {"left", HTLEFT},         {"right", HTRIGHT},
      {"top", HTTOP},           {"bottom", HTBOTTOM},
      {"topLeft", HTTOPLEFT},   {"topRight", HTTOPRIGHT},
      {"bottomLeft", HTBOTTOMLEFT}, {"bottomRight", HTBOTTOMRIGHT},
  };
  const auto hit = kHits.find(edge);
  if (hit == kHits.end()) return;
  ReleaseCapture();
  POINT cursor{};
  GetCursorPos(&cursor);
  SendMessageW(window_, WM_NCLBUTTONDOWN, hit->second,
               MAKELPARAM(cursor.x, cursor.y));
}

void OverlayWindowImpl::ResetSize() {
  if (!window_ || !config_.resizable) return;
  size_.reset();
  SessionSizes().erase(config_.id);
  if (IsZoomed(window_)) ShowWindow(window_, SW_RESTORE);
  MoveTo(BoundsAround(default_width_, default_height_));
}

void OverlayWindowImpl::MoveTo(const RECT& bounds) {
  StopAnimation();
  RECT from{};
  GetWindowRect(window_, &from);
  BOOL animate = TRUE;
  SystemParametersInfoW(SPI_GETCLIENTAREAANIMATION, 0, &animate, 0);
  // Immediate when the user turned animations off, or when nothing shows.
  if (!animate || !IsWindowVisible(window_) || EqualRect(&from, &bounds)) {
    SetWindowPos(window_, nullptr, bounds.left, bounds.top,
                 bounds.right - bounds.left, bounds.bottom - bounds.top,
                 SWP_NOZORDER | SWP_NOACTIVATE);
    SaveBounds(false);
    return;
  }
  animation_ = Animation{from, bounds, std::chrono::steady_clock::now()};
  SetTimer(window_, kAnimationTimer, USER_TIMER_MINIMUM, nullptr);
  StepAnimation();
}

void OverlayWindowImpl::StepAnimation() {
  if (!animation_ || !window_) return;
  const std::chrono::duration<double, std::milli> elapsed =
      std::chrono::steady_clock::now() - animation_->start;
  const double t = std::clamp(elapsed.count() / kAnimationDuration.count(),
                              0.0, 1.0);
  // Ease-out cubic: fast start, soft landing.
  const double eased = 1 - (1 - t) * (1 - t) * (1 - t);
  const auto lerp = [eased](LONG a, LONG b) {
    return a + static_cast<LONG>(std::lround((b - a) * eased));
  };
  const RECT& from = animation_->from;
  const RECT& to = animation_->to;
  const RECT now{lerp(from.left, to.left), lerp(from.top, to.top),
                 lerp(from.right, to.right), lerp(from.bottom, to.bottom)};
  // Each step draws the view at its new size before the window changes
  // (WM_NCCALCSIZE), so the animation stays whole.
  SetWindowPos(window_, nullptr, now.left, now.top, now.right - now.left,
               now.bottom - now.top, SWP_NOZORDER | SWP_NOACTIVATE);
  if (t >= 1.0) {
    StopAnimation();
    SaveBounds(false);
  }
}

void OverlayWindowImpl::StopAnimation() {
  if (!animation_) return;
  animation_.reset();
  if (window_) KillTimer(window_, kAnimationTimer);
}

void OverlayWindowImpl::ToggleMaximize() {
  if (!window_ || !config_.double_click_maximizes) return;
  ShowWindow(window_, IsZoomed(window_) ? SW_RESTORE : SW_MAXIMIZE);
}

SIZE OverlayWindowImpl::OpeningSize(int width, int height) const {
  if (config_.resizable && config_.size_memory != SizeMemory::kNone && size_) {
    return SIZE{std::max<LONG>(size_->cx, config_.min_width),
                std::max<LONG>(size_->cy, config_.min_height)};
  }
  return SIZE{width, height};
}

void OverlayWindowImpl::Place(int width, int height) {
  default_width_ = width;
  default_height_ = height;
  if (IsZoomed(window_)) return;
  const SIZE size = OpeningSize(width, height);
  RECT anchor{};
  if (const auto position = LoadPosition()) {
    // Move first so Windows applies the destination monitor's DPI before
    // the physical size is computed. The window is still hidden.
    SetWindowPos(window_, nullptr, position->x, position->y, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    const UINT dpi = GetDpiForWindow(window_);
    anchor = {position->x, position->y, position->x + Scale(size.cx, dpi),
              position->y + Scale(size.cy, dpi)};
  } else {
    POINT cursor{};
    GetCursorPos(&cursor);
    const HWND foreground =
        previous_foreground_ ? previous_foreground_ : GetForegroundWindow();
    const HMONITOR monitor =
        config_.placement == Placement::kForegroundMonitorCenter && foreground
            ? MonitorFromWindow(foreground, MONITOR_DEFAULTTONEAREST)
            : MonitorFromPoint(cursor, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{sizeof(info)};
    if (!GetMonitorInfoW(monitor, &info)) return;
    const RECT work = info.rcWork;
    SetWindowPos(window_, nullptr, work.left, work.top, 0, 0,
                 SWP_NOSIZE | SWP_NOZORDER | SWP_NOACTIVATE);
    const UINT dpi = GetDpiForWindow(window_);
    const int physical_width = Scale(size.cx, dpi);
    const int physical_height = Scale(size.cy, dpi);
    const int left = work.left + (work.right - work.left - physical_width) / 2;
    const int top =
        config_.placement == Placement::kCursorMonitorUpper
            ? work.top + (work.bottom - work.top) / 5
            : work.top + (work.bottom - work.top - physical_height) / 2;
    anchor = {left, top, left + physical_width, top + physical_height};
  }
  const UINT dpi = GetDpiForWindow(window_);
  const RECT bounds =
      ClampedBounds(anchor, Scale(size.cx, dpi), Scale(size.cy, dpi));
  SetWindowPos(window_, config_.always_on_top ? HWND_TOPMOST : nullptr,
               bounds.left, bounds.top, bounds.right - bounds.left,
               bounds.bottom - bounds.top,
               SWP_NOACTIVATE | (config_.always_on_top ? 0 : SWP_NOZORDER));
  UpdateRegion();
}

RECT OverlayWindowImpl::BoundsAround(int width, int height) {
  RECT anchor{};
  if (!window_ || !GetWindowRect(window_, &anchor)) return anchor;
  const UINT dpi = GetDpiForWindow(window_);
  return ClampedBounds(anchor, Scale(width, dpi), Scale(height, dpi));
}

RECT OverlayWindowImpl::ClampedBounds(const RECT& anchor, int width,
                                      int height) const {
  // Keeps the anchor's center, moving only as much as needed to stay inside
  // the work area of the monitor it is on (or nearest to, when unplugged).
  MONITORINFO info{sizeof(info)};
  if (!GetMonitorInfoW(MonitorFromRect(&anchor, MONITOR_DEFAULTTONEAREST),
                       &info)) {
    return {anchor.left, anchor.top, anchor.left + width, anchor.top + height};
  }
  const RECT& work = info.rcWork;
  const int margin = Scale(config_.margin, GetDpiForWindow(window_));
  const int available_width = std::max(1, static_cast<int>(work.right - work.left));
  const int available_height =
      std::max(1, static_cast<int>(work.bottom - work.top));
  const int inset_x = std::clamp(margin, 0, (available_width - 1) / 2);
  const int inset_y = std::clamp(margin, 0, (available_height - 1) / 2);
  width = std::clamp(width, 1, available_width - 2 * inset_x);
  height = std::clamp(height, 1, available_height - 2 * inset_y);
  const int x = std::clamp(
      static_cast<int>(anchor.left + (anchor.right - anchor.left - width) / 2),
      static_cast<int>(work.left) + inset_x,
      static_cast<int>(work.right) - inset_x - width);
  const int y = std::clamp(
      static_cast<int>(anchor.top + (anchor.bottom - anchor.top - height) / 2),
      static_cast<int>(work.top) + inset_y,
      static_cast<int>(work.bottom) - inset_y - height);
  return {x, y, x + width, y + height};
}

void OverlayWindowImpl::FitViewToClient() {
  RECT client{};
  if (!window_ || !GetClientRect(window_, &client)) return;
  FitView(client.right - client.left, client.bottom - client.top);
}

void OverlayWindowImpl::FitView(int width, int height) {
  const HWND view_window = view();
  if (view_window == nullptr) return;
  RECT current{};
  if (GetClientRect(view_window, &current) && current.right == width &&
      current.bottom == height) {
    return;
  }
  // The engine blocks here until a frame of the new size is on screen (up to
  // a hundred milliseconds): the window is only ever seen with content that
  // matches its size.
  MoveWindow(view_window, 0, 0, width, height, FALSE);
}

void OverlayWindowImpl::UpdateRegion() {
  if (!window_ || !frame_ready_) return;
  // DWM already rounds the corners on Windows 11: no region at all.
  if (native_corners_ || IsZoomed(window_)) {
    const HRGN probe = CreateRectRgn(0, 0, 0, 0);
    const bool has_region = probe && GetWindowRgn(window_, probe) != ERROR;
    if (probe) DeleteObject(probe);
    if (has_region) SetWindowRgn(window_, nullptr, FALSE);
    return;
  }
  RECT rect{};
  if (!GetClientRect(window_, &rect)) return;
  const int diameter =
      Scale(config_.corner_radius * 2, GetDpiForWindow(window_));
  HRGN region = CreateRoundRectRgn(0, 0, rect.right + 1, rect.bottom + 1,
                                   diameter, diameter);
  // Windows owns the region only after a successful assignment.
  if (region && !SetWindowRgn(window_, region, FALSE)) DeleteObject(region);
}

void OverlayWindowImpl::SaveBounds(bool size_changed) {
  if (!window_ || !IsWindowVisible(window_) || IsIconic(window_) ||
      IsZoomed(window_)) {
    return;
  }
  RECT bounds{};
  if (!GetWindowRect(window_, &bounds)) return;
  if (config_.remember_position) position_ = POINT{bounds.left, bounds.top};
  if (size_changed && config_.resizable &&
      config_.size_memory != SizeMemory::kNone) {
    const UINT dpi = GetDpiForWindow(window_);
    size_ = SIZE{MulDiv(bounds.right - bounds.left, 96, dpi),
                 MulDiv(bounds.bottom - bounds.top, 96, dpi)};
    if (config_.size_memory == SizeMemory::kSession) {
      SessionSizes()[config_.id] = *size_;
    }
  }
  const bool custom_position = config_.load_position && config_.save_position;
  if (config_.remember_position && custom_position && position_) {
    config_.save_position(*position_);
  }
  if (config_.app_folder.empty()) return;
  StoredBounds stored;
  if (config_.remember_position && !custom_position) stored.position = position_;
  if (config_.size_memory == SizeMemory::kPersistent) stored.size = size_;
  SaveStoredBounds(config_.app_folder, config_.id, stored);
}

std::optional<POINT> OverlayWindowImpl::LoadPosition() const {
  if (!config_.remember_position) return std::nullopt;
  if (config_.load_position && config_.save_position) {
    return config_.load_position();
  }
  if (!config_.app_folder.empty()) {
    return LoadStoredBounds(config_.app_folder, config_.id).position;
  }
  // Nothing durable: the position lasts until the app quits.
  return position_;
}

void OverlayWindowImpl::NotifyVisibility(bool shown) {
  if (config_.on_visibility) config_.on_visibility(shown);
}

void OverlayWindowImpl::InvokeHost(
    const std::string& method,
    std::unique_ptr<flutter::EncodableValue> arguments) {
  if (channel_) channel_->InvokeMethod(method, std::move(arguments));
}

HWND OverlayWindowImpl::view() const {
  return controller_ && controller_->view()
             ? controller_->view()->GetNativeWindow()
             : nullptr;
}

flutter::BinaryMessenger* OverlayWindowImpl::messenger() const {
  return controller_ && controller_->engine()
             ? controller_->engine()->messenger()
             : nullptr;
}

void OverlayWindowImpl::SetNextFrameCallback(std::function<void()> callback) {
  if (controller_ && controller_->engine()) {
    controller_->engine()->SetNextFrameCallback(std::move(callback));
  }
}

void OverlayWindowImpl::ForceRedraw() {
  if (controller_) controller_->ForceRedraw();
}

// static
LRESULT CALLBACK OverlayWindowImpl::WndProc(HWND hwnd, UINT message,
                                            WPARAM wparam,
                                            LPARAM lparam) noexcept {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(hwnd, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  } else if (auto* that = reinterpret_cast<OverlayWindowImpl*>(
                 GetWindowLongPtrW(hwnd, GWLP_USERDATA))) {
    if (message == WM_NCDESTROY) {
      SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
    } else {
      return that->HandleMessage(hwnd, message, wparam, lparam);
    }
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

std::optional<LRESULT> OverlayWindowImpl::HandleFrameMessage(HWND hwnd,
                                                             UINT message,
                                                             WPARAM wparam,
                                                             LPARAM lparam) {
  switch (message) {
    case WM_SYSCOMMAND:
      // Alt alone (lParam 0) asks for the menu bar. An overlay has none, yet
      // the invisible menu mode would swallow the next key: releasing Alt
      // after an Alt+key hotkey that opened the overlay made the first Tab
      // or Escape do nothing. Alt+Space (system menu) is unchanged.
      if ((wparam & 0xFFF0) == SC_KEYMENU && lparam == 0) return 0;
      return std::nullopt;
    case WM_NCCALCSIZE: {
      // Borderless: the client area is the whole window.
      if (!wparam) return 0;
      auto* params = reinterpret_cast<NCCALCSIZE_PARAMS*>(lparam);
      const RECT old_client = params->rgrc[2];
      RECT& client = params->rgrc[0];
      // Maximized, Windows places the frame outside the monitor: keep the
      // content inside.
      if (IsZoomed(hwnd)) {
        const UINT dpi = GetDpiForWindow(hwnd);
        const int padding = GetSystemMetricsForDpi(SM_CXPADDEDBORDER, dpi);
        const int frame_x = GetSystemMetricsForDpi(SM_CXFRAME, dpi) + padding;
        const int frame_y = GetSystemMetricsForDpi(SM_CYFRAME, dpi) + padding;
        client.left += frame_x;
        client.right -= frame_x;
        client.top += frame_y;
        client.bottom -= frame_y;
      }
      // Live resizing the professional way: the view draws its frame at the
      // new size now, before Windows touches the window, so every step shows
      // finished content at the right place (never the old frame stretched,
      // never a bare strip).
      if (view_visible_) {
        FitView(client.right - client.left, client.bottom - client.top);
      }
      // Nothing of the old client area is copied into the new one. Left to
      // itself, Windows blits it to the top-left corner, which makes the
      // content jump when the left or top edge is dragged: one pixel copied
      // onto itself instead.
      RECT keep{};
      if (IntersectRect(&keep, &old_client, &client)) {
        keep.right = keep.left + 1;
        keep.bottom = keep.top + 1;
      }
      params->rgrc[1] = keep;
      params->rgrc[2] = keep;
      return WVR_VALIDRECTS;
    }
    case WM_ERASEBKGND:
      // The view covers the client area. What Windows may still expose for a
      // frame (a resize step the engine could not follow in time) takes the
      // overlay's background rather than black.
      if (config_.background_color) {
        RECT client{};
        if (GetClientRect(hwnd, &client)) {
          if (const HBRUSH brush =
                  CreateSolidBrush(*config_.background_color)) {
            FillRect(reinterpret_cast<HDC>(wparam), &client, brush);
            DeleteObject(brush);
          }
        }
      }
      return 1;
    case WM_NCACTIVATE:
      // Never DefWindowProc: it paints the legacy caption over the client
      // area whenever DWM is not rendering this window's frame, even with
      // lParam -1. TRUE lets the activation change proceed.
      return TRUE;
    case WM_NCPAINT:
      // DefWindowProc, always: a window that swallows WM_NCPAINT is handled
      // by Windows 11 as a legacy-framed window (DWM frame rendering off, a
      // rounded region installed, the classic caption painted on
      // activation). With an empty non-client area it paints nothing.
      return DefWindowProcW(hwnd, message, wparam, lparam);
    case kNcUahDrawCaption:
    case kNcUahDrawFrame:
      return 0;
    case WM_SETTEXT:
    case WM_SETICON: {
      // The default handling stores the text or icon, then paints the
      // caption: hide the window from it for the call.
      const LONG_PTR style = GetWindowLongPtrW(hwnd, GWL_STYLE);
      if (!(style & WS_VISIBLE)) return std::nullopt;
      SetWindowLongPtrW(hwnd, GWL_STYLE, style & ~WS_VISIBLE);
      const LRESULT result = DefWindowProcW(hwnd, message, wparam, lparam);
      SetWindowLongPtrW(hwnd, GWL_STYLE, style);
      return result;
    }
  }
  return std::nullopt;
}

LRESULT OverlayWindowImpl::HandleMessage(HWND hwnd, UINT message,
                                         WPARAM wparam, LPARAM lparam) {
  // The borderless frame comes first: a host hook can neither replace it nor
  // send these messages on to DefWindowProc.
  if (const auto handled = HandleFrameMessage(hwnd, message, wparam, lparam)) {
    return *handled;
  }
  if (message == WM_ACTIVATE) OnActivate(wparam);
  if (message == kSendBackMessage) {
    SendBehindForeground();
    return 0;
  }
  if (config_.message_hook) {
    if (const auto handled =
            config_.message_hook(hwnd, message, wparam, lparam)) {
      return *handled;
    }
  }
  switch (message) {
    case WM_NCLBUTTONDBLCLK:
      if (!config_.double_click_maximizes) return 0;
      break;
    case WM_GETMINMAXINFO:
      if (config_.resizable) {
        auto* info = reinterpret_cast<MINMAXINFO*>(lparam);
        const UINT dpi = GetDpiForWindow(hwnd);
        info->ptMinTrackSize = {Scale(config_.min_width, dpi),
                                Scale(config_.min_height, dpi)};
        return 0;
      }
      break;
    case WM_TIMER:
      if (wparam == kAnimationTimer) {
        StepAnimation();
        return 0;
      }
      break;
    case WM_ENTERSIZEMOVE: {
      // The user took over from a programmatic move.
      StopAnimation();
      RECT bounds{};
      GetWindowRect(hwnd, &bounds);
      size_before_move_ = {bounds.right - bounds.left,
                           bounds.bottom - bounds.top};
      break;
    }
    case WM_EXITSIZEMOVE: {
      RECT bounds{};
      GetWindowRect(hwnd, &bounds);
      SaveBounds(bounds.right - bounds.left != size_before_move_.cx ||
                 bounds.bottom - bounds.top != size_before_move_.cy);
      break;
    }
    case WM_DPICHANGED: {
      const auto* suggested = reinterpret_cast<RECT*>(lparam);
      SetWindowPos(hwnd, nullptr, suggested->left, suggested->top,
                   suggested->right - suggested->left,
                   suggested->bottom - suggested->top,
                   SWP_NOZORDER | SWP_NOACTIVATE);
      return 0;
    }
    case WM_SIZE:
      UpdateRegion();
      // A hidden view keeps the size its runner gave it.
      if (view_visible_) FitViewToClient();
      return 0;
    case WM_ACTIVATE: {
      // Flutter sees the activation change first; a result from it is still
      // returned.
      std::optional<LRESULT> flutter_result;
      if (controller_) {
        flutter_result = controller_->HandleTopLevelWindowProc(
            hwnd, message, wparam, lparam);
      }
      if (LOWORD(wparam) != WA_INACTIVE && view_visible_ &&
          HIWORD(wparam) == 0) {
        SetFocus(view());
      }
      return flutter_result ? *flutter_result : 0;
    }
    case WM_KEYDOWN:
      // A plain Escape closes like Alt+F4. It reaches the frame only while
      // the frame itself holds the keyboard (before the view took it, or
      // after Windows gave it back): the view handles its own keys through
      // ShipglowsOverlayHost.
      if (wparam == VK_ESCAPE && !(lparam & (1 << 30)) &&
          !(GetKeyState(VK_CONTROL) & 0x8000) &&
          !(GetKeyState(VK_SHIFT) & 0x8000) &&
          !(GetKeyState(VK_MENU) & 0x8000)) {
        RequestClose();
        return 0;
      }
      break;
    case WM_CLOSE:
      // Alt+F4: the overlay decides (it may confirm); it stays alive for the
      // next opening.
      RequestClose();
      return 0;
    default:
      if (message == kRevealMessage) {
        Reveal(static_cast<int64_t>(wparam));
        return 0;
      }
      break;
  }
  if (controller_) {
    const auto result =
        controller_->HandleTopLevelWindowProc(hwnd, message, wparam, lparam);
    if (result) return *result;
    if (message == WM_FONTCHANGE) controller_->engine()->ReloadSystemFonts();
  }
  return DefWindowProcW(hwnd, message, wparam, lparam);
}

}  // namespace shipglows_overlay

std::unique_ptr<shipglows_overlay::OverlayWindow> ShipglowsOverlayWindowCreate(
    const shipglows_overlay::OverlayConfig& config) {
  if (!shipglows_overlay::ReserveOverlayId(config.id)) return nullptr;
  return std::make_unique<shipglows_overlay::OverlayWindowImpl>(config);
}
