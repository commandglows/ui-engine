#include "tray_host.h"

#include <shellapi.h>
#include <windowsx.h>

#include <array>
#include <cwchar>
#include <iterator>
#include <utility>

extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace shipglows_tray {
namespace {

constexpr UINT kIconMessage = WM_APP + 0x5A1;
constexpr wchar_t kWindowClass[] = L"ShipGlowsTrayIcon";
constexpr UINT kIconId = 1;
constexpr UINT_PTR kAddRetryTimer = 1;
constexpr UINT kAddRetryMs = 1000;
constexpr int kMaxAddAttempts = 60;

// Windows a click on the icon or its menu brings to the front; never the
// window the user was working in.
constexpr std::array<const wchar_t*, 6> kShellClasses{
    L"Shell_TrayWnd",
    L"Shell_SecondaryTrayWnd",
    L"NotifyIconOverflowWindow",
    L"TopLevelWindowForOverflowXamlIsland",
    L"XamlExplorerHostIslandWindow",
    L"#32768",  // Menus.
};

// The one host of the process, for the foreground hook.
TrayHost* foreground_owner = nullptr;

HINSTANCE ModuleInstance() {
  return reinterpret_cast<HINSTANCE>(&__ImageBase);
}

}  // namespace

TrayHost::TrayHost(Callbacks callbacks) : callbacks_(std::move(callbacks)) {
  // Registered once per process; later hosts reuse it.
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = WindowProc;
  window_class.hInstance = ModuleInstance();
  window_class.lpszClassName = kWindowClass;
  RegisterClassExW(&window_class);
  window_ = CreateWindowExW(WS_EX_TOOLWINDOW, kWindowClass,
                            L"ShipGlows tray", WS_POPUP, 0, 0, 0, 0, nullptr,
                            nullptr, ModuleInstance(), this);
  taskbar_created_message_ = RegisterWindowMessageW(L"TaskbarCreated");
  if (window_ != nullptr && taskbar_created_message_ != 0) {
    // Explorer runs unelevated; let its broadcast reach an elevated app.
    ChangeWindowMessageFilterEx(window_, taskbar_created_message_,
                                MSGFLT_ALLOW, nullptr);
  }
  if (foreground_owner == nullptr) {
    foreground_owner = this;
    const HWND current = GetForegroundWindow();
    if (IsCandidateForeground(current)) last_foreground_ = current;
    foreground_hook_ = SetWinEventHook(
        EVENT_SYSTEM_FOREGROUND, EVENT_SYSTEM_FOREGROUND, nullptr,
        ForegroundChanged, 0, 0, WINEVENT_OUTOFCONTEXT);
  }
}

TrayHost::~TrayHost() {
  Hide();
  if (foreground_hook_ != nullptr) UnhookWinEvent(foreground_hook_);
  if (foreground_owner == this) foreground_owner = nullptr;
  if (window_ != nullptr) DestroyWindow(window_);
  if (icon_ != nullptr) DestroyIcon(icon_);
}

void TrayHost::SetIcon(HICON icon) {
  const HICON previous = icon_;
  icon_ = icon;
  if (visible_) {
    NOTIFYICONDATAW data = IconData(NIF_ICON);
    Shell_NotifyIconW(NIM_MODIFY, &data);
  }
  if (previous != nullptr && previous != icon) DestroyIcon(previous);
}

void TrayHost::SetTooltip(const std::wstring& tooltip) {
  tooltip_ = tooltip;
  if (visible_) {
    NOTIFYICONDATAW data = IconData(NIF_TIP | NIF_SHOWTIP);
    Shell_NotifyIconW(NIM_MODIFY, &data);
  }
}

bool TrayHost::Show() {
  wanted_ = true;
  if (visible_) {
    NOTIFYICONDATAW data = IconData(NIF_ICON | NIF_TIP | NIF_SHOWTIP);
    Shell_NotifyIconW(NIM_MODIFY, &data);
    return true;
  }
  if (!Add() && window_ != nullptr) {
    add_attempts_ = 0;
    SetTimer(window_, kAddRetryTimer, kAddRetryMs, nullptr);
  }
  return visible_;
}

void TrayHost::Hide() {
  wanted_ = false;
  if (window_ != nullptr) KillTimer(window_, kAddRetryTimer);
  if (visible_) {
    NOTIFYICONDATAW data = IconData(0);
    Shell_NotifyIconW(NIM_DELETE, &data);
  }
  version4_ = false;
  SetVisible(false);
}

HWND TrayHost::previous_foreground() const {
  return IsWindow(last_foreground_) ? last_foreground_ : nullptr;
}

bool TrayHost::Add() {
  if (window_ == nullptr) return false;
  NOTIFYICONDATAW data =
      IconData(NIF_MESSAGE | NIF_ICON | NIF_TIP | NIF_SHOWTIP);
  if (Shell_NotifyIconW(NIM_ADD, &data) != TRUE) return false;
  // Version 4: keyboard selection and the icon's position come with each
  // message.
  data.uVersion = NOTIFYICON_VERSION_4;
  version4_ = Shell_NotifyIconW(NIM_SETVERSION, &data) == TRUE;
  SetVisible(true);
  return true;
}

void TrayHost::SetVisible(bool visible) {
  if (visible_ == visible) return;
  visible_ = visible;
  if (callbacks_.on_visibility) callbacks_.on_visibility(visible);
}

bool TrayHost::IsCandidateForeground(HWND window) const {
  if (window == nullptr) return false;
  window = GetAncestor(window, GA_ROOT);
  if (window == nullptr || window == window_) return false;
  wchar_t class_name[64]{};
  GetClassNameW(window, class_name, static_cast<int>(std::size(class_name)));
  for (const wchar_t* shell_class : kShellClasses) {
    if (wcscmp(class_name, shell_class) == 0) return false;
  }
  return true;
}

NOTIFYICONDATAW TrayHost::IconData(UINT flags) const {
  NOTIFYICONDATAW data{};
  data.cbSize = sizeof(data);
  data.hWnd = window_;
  data.uID = kIconId;
  data.uFlags = flags;
  data.uCallbackMessage = kIconMessage;
  data.hIcon = icon_;
  wcsncpy_s(data.szTip, tooltip_.c_str(), _TRUNCATE);
  return data;
}

void TrayHost::OnIconMessage(WPARAM wparam, LPARAM lparam) {
  if (!callbacks_.on_icon) return;
  POINT anchor{};
  UINT event = 0;
  if (version4_) {
    if (HIWORD(lparam) != kIconId) return;
    event = LOWORD(lparam);
    anchor = {GET_X_LPARAM(wparam), GET_Y_LPARAM(wparam)};
  } else {
    if (wparam != kIconId) return;
    event = static_cast<UINT>(lparam);
    GetCursorPos(&anchor);
  }
  switch (event) {
    case NIN_SELECT:
    case NIN_KEYSELECT:
      callbacks_.on_icon(IconAction::kPrimary, anchor);
      break;
    case WM_LBUTTONUP:
      if (!version4_) callbacks_.on_icon(IconAction::kPrimary, anchor);
      break;
    case WM_CONTEXTMENU:
      callbacks_.on_icon(IconAction::kMenu, anchor);
      break;
    case WM_RBUTTONUP:
      if (!version4_) callbacks_.on_icon(IconAction::kMenu, anchor);
      break;
  }
}

LRESULT TrayHost::HandleMessage(UINT message, WPARAM wparam, LPARAM lparam) {
  if (message == kIconMessage) {
    OnIconMessage(wparam, lparam);
    return 0;
  }
  if (message == taskbar_created_message_ && taskbar_created_message_ != 0) {
    // The new taskbar starts empty.
    version4_ = false;
    SetVisible(false);
    if (wanted_ && !Add()) {
      add_attempts_ = 0;
      SetTimer(window_, kAddRetryTimer, kAddRetryMs, nullptr);
    }
    return 0;
  }
  if (message == WM_TIMER && wparam == kAddRetryTimer) {
    if (!wanted_ || visible_ || Add() || ++add_attempts_ >= kMaxAddAttempts) {
      KillTimer(window_, kAddRetryTimer);
    }
    return 0;
  }
  return DefWindowProcW(window_, message, wparam, lparam);
}

LRESULT CALLBACK TrayHost::WindowProc(HWND window, UINT message,
                                      WPARAM wparam, LPARAM lparam) {
  if (message == WM_NCCREATE) {
    const auto* create = reinterpret_cast<const CREATESTRUCTW*>(lparam);
    SetWindowLongPtrW(window, GWLP_USERDATA,
                      reinterpret_cast<LONG_PTR>(create->lpCreateParams));
  }
  auto* host =
      reinterpret_cast<TrayHost*>(GetWindowLongPtrW(window, GWLP_USERDATA));
  if (host == nullptr || host->window_ != window) {
    return DefWindowProcW(window, message, wparam, lparam);
  }
  return host->HandleMessage(message, wparam, lparam);
}

void CALLBACK TrayHost::ForegroundChanged(HWINEVENTHOOK, DWORD event,
                                          HWND window, LONG object, LONG,
                                          DWORD, DWORD) {
  if (event != EVENT_SYSTEM_FOREGROUND || object != OBJID_WINDOW ||
      foreground_owner == nullptr ||
      !foreground_owner->IsCandidateForeground(window)) {
    return;
  }
  foreground_owner->last_foreground_ = GetAncestor(window, GA_ROOT);
}

}  // namespace shipglows_tray
