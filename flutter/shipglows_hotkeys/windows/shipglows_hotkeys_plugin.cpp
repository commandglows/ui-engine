#include "include/shipglows_hotkeys/shipglows_hotkeys_plugin_c_api.h"

#include <windows.h>
#include <dwmapi.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <cstdlib>
#include <cwctype>
#include <deque>
#include <map>
#include <memory>
#include <optional>
#include <set>
#include <string>
#include <utility>
#include <vector>

extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace shipglows_hotkeys {
namespace {

constexpr char kChannel[] = "shipglows_hotkeys";
constexpr wchar_t kWindowClass[] = L"ShipglowsHotkeysWindow";
// Posted to the plugin's window by the low-level keyboard hook (wParam: slot).
constexpr UINT kHookHotkeyMessage = WM_APP + 0x5B1;
// Posted by the low-level mouse hook: queued trigger events are ready.
constexpr UINT kHookMouseMessage = WM_APP + 0x5B2;
// Timer ids: one for the corner dwell, one per slot for a hold.
constexpr UINT_PTR kTouchTimer = 1;
constexpr UINT_PTR kHoldTimerBase = 0x10000;
// Alt released right after an Alt+key hotkey pressed in the app: within this
// delay the main window ignores the menu-bar request it triggers.
constexpr ULONGLONG kMenuSuppressMs = 500;
constexpr UINT kAllowedModifiers = MOD_ALT | MOD_CONTROL | MOD_SHIFT | MOD_WIN;
// Ids an application may give RegisterHotKey.
constexpr int64_t kMaxSlot = 0xBFFF;
// A held press that moves more than this many pixels is not a hold.
constexpr int kHoldTolerance = 4;
// Width of a screen corner, in pixels.
constexpr int kCornerSize = 6;
// A low-level hook has about 300 ms before Windows drops it: never wait long
// for a window that does not answer.
constexpr UINT kHitTestTimeoutMs = 50;

HINSTANCE ModuleInstance() {
  return reinterpret_cast<HINSTANCE>(&__ImageBase);
}

const flutter::EncodableValue* Field(const flutter::EncodableValue* value,
                                     const char* key) {
  const auto* map =
      value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

std::optional<int64_t> IntField(const flutter::EncodableValue* value,
                                const char* key) {
  const auto* field = Field(value, key);
  if (field == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(field)) return *v;
  if (const auto* v = std::get_if<int64_t>(field)) return *v;
  return std::nullopt;
}

bool BoolField(const flutter::EncodableValue* value, const char* key) {
  const auto* field = Field(value, key);
  const auto* flag = field ? std::get_if<bool>(field) : nullptr;
  return flag != nullptr && *flag;
}

std::string StringField(const flutter::EncodableValue* value,
                        const char* key) {
  const auto* field = Field(value, key);
  const auto* text = field ? std::get_if<std::string>(field) : nullptr;
  return text == nullptr ? std::string() : *text;
}

std::wstring Widen(const std::string& text) {
  if (text.empty()) return std::wstring();
  const int size =
      MultiByteToWideChar(CP_UTF8, 0, text.c_str(),
                          static_cast<int>(text.size()), nullptr, 0);
  if (size <= 0) return std::wstring();
  std::wstring wide(static_cast<size_t>(size), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.c_str(), static_cast<int>(text.size()),
                      wide.data(), size);
  return wide;
}

std::wstring Lower(std::wstring text) {
  std::transform(text.begin(), text.end(), text.begin(),
                 [](wchar_t c) { return static_cast<wchar_t>(std::towlower(c)); });
  return text;
}

bool IsModifierKey(UINT key) {
  switch (key) {
    case VK_SHIFT:
    case VK_CONTROL:
    case VK_MENU:
    case VK_LWIN:
    case VK_RWIN:
    case VK_LSHIFT:
    case VK_RSHIFT:
    case VK_LCONTROL:
    case VK_RCONTROL:
    case VK_LMENU:
    case VK_RMENU:
      return true;
    default:
      return false;
  }
}

bool IsValidHotkey(UINT modifiers, UINT key) {
  return key > 0 && key < 0xFF && !IsModifierKey(key) &&
         (modifiers & ~kAllowedModifiers) == 0;
}

// Modifiers held right now.
UINT HeldModifiers() {
  UINT modifiers = 0;
  if ((GetAsyncKeyState(VK_MENU) & 0x8000) != 0) modifiers |= MOD_ALT;
  if ((GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0) modifiers |= MOD_CONTROL;
  if ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) modifiers |= MOD_SHIFT;
  if ((GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 ||
      (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0) {
    modifiers |= MOD_WIN;
  }
  return modifiers;
}

// Modifiers held while the low-level keyboard hook sees |event|.
UINT HeldModifiers(const KBDLLHOOKSTRUCT& event) {
  UINT modifiers = HeldModifiers();
  if ((event.flags & LLKHF_ALTDOWN) != 0) modifiers |= MOD_ALT;
  return modifiers;
}

flutter::EncodableValue HandleValue(HWND window) {
  return flutter::EncodableValue(
      static_cast<int64_t>(reinterpret_cast<intptr_t>(window)));
}

HWND WindowFromValue(int64_t value) {
  return reinterpret_cast<HWND>(static_cast<intptr_t>(value));
}

std::wstring ClassNameOf(HWND window) {
  wchar_t name[256] = {};
  const int length = GetClassNameW(window, name, 255);
  return std::wstring(name, length > 0 ? static_cast<size_t>(length) : 0);
}

// Lower-case executable name of the process owning |window|, e.g. "code.exe".
std::wstring ProcessNameOf(HWND window) {
  DWORD process = 0;
  GetWindowThreadProcessId(window, &process);
  if (process == 0) return std::wstring();
  HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, process);
  if (handle == nullptr) return std::wstring();
  wchar_t path[MAX_PATH * 2] = {};
  DWORD size = MAX_PATH * 2;
  std::wstring name;
  if (QueryFullProcessImageNameW(handle, 0, path, &size)) {
    name.assign(path, size);
    const size_t slash = name.find_last_of(L"\\/");
    if (slash != std::wstring::npos) name.erase(0, slash + 1);
  }
  CloseHandle(handle);
  return Lower(name);
}

// The desktop, the taskbar and other shell windows: never closed, hidden,
// moved or resized by an action.
bool IsShellWindow(HWND window) {
  const std::wstring name = ClassNameOf(window);
  return name == L"Progman" || name == L"WorkerW" ||
         name == L"Shell_TrayWnd" || name == L"Shell_SecondaryTrayWnd";
}

POINT PointOf(const MSLLHOOKSTRUCT& event) { return event.pt; }

int Distance(POINT a, POINT b) {
  return std::max(std::abs(a.x - b.x), std::abs(a.y - b.y));
}

// 0 top-left, 1 top-right, 2 bottom-left, 3 bottom-right; -1 elsewhere.
int CornerAt(POINT point) {
  const HMONITOR monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
  MONITORINFO info{};
  info.cbSize = sizeof(info);
  if (monitor == nullptr || !GetMonitorInfoW(monitor, &info)) return -1;
  const RECT& r = info.rcMonitor;
  const bool left = point.x < r.left + kCornerSize;
  const bool right = point.x >= r.right - kCornerSize;
  const bool top = point.y < r.top + kCornerSize;
  const bool bottom = point.y >= r.bottom - kCornerSize;
  if (top && left) return 0;
  if (top && right) return 1;
  if (bottom && left) return 2;
  if (bottom && right) return 3;
  return -1;
}

LRESULT HitTest(HWND window, POINT point) {
  DWORD_PTR result = HTNOWHERE;
  const LPARAM position = MAKELPARAM(static_cast<WORD>(point.x & 0xFFFF),
                                     static_cast<WORD>(point.y & 0xFFFF));
  if (SendMessageTimeoutW(window, WM_NCHITTEST, 0, position,
                          SMTO_ABORTIFHUNG | SMTO_BLOCK, kHitTestTimeoutMs,
                          &result) == 0) {
    return HTNOWHERE;
  }
  return static_cast<LRESULT>(result);
}

// Finds out, lazily and once, what is under a point: the window, the taskbar,
// the part of the window frame.
class ZoneProbe {
 public:
  explicit ZoneProbe(POINT point) : point_(point) {}

  HWND Root() {
    if (!resolved_) {
      resolved_ = true;
      const HWND under = WindowFromPoint(point_);
      root_ = under == nullptr ? nullptr : GetAncestor(under, GA_ROOT);
    }
    return root_;
  }

  bool Matches(int zone) {
    switch (zone) {
      case 0:  // anywhere
        return true;
      case 1:  // title bar
        return Hit() == HTCAPTION || FramelessTopStrip();
      case 2: {  // taskbar
        if (Root() == nullptr) return false;
        const std::wstring name = ClassNameOf(Root());
        return name == L"Shell_TrayWnd" || name == L"Shell_SecondaryTrayWnd";
      }
      case 3:
        return Hit() == HTMINBUTTON;
      case 4:
        return Hit() == HTMAXBUTTON;
      case 5:
        return Hit() == HTCLOSE;
      default:  // corners 6..9
        return CornerAt(point_) == zone - 6;
    }
  }

 private:
  LRESULT Hit() {
    if (!hit_) {
      hit_ = Root() == nullptr ? HTNOWHERE : HitTest(Root(), point_);
    }
    return *hit_;
  }

  // An Electron app whose menu bar is hidden (Codex...) declares no title
  // bar: the top 32 pixels of its window stand in for one.
  bool FramelessTopStrip() {
    const HWND root = Root();
    if (root == nullptr || ClassNameOf(root) != L"Chrome_WidgetWin_1") {
      return false;
    }
    if ((GetWindowLongW(root, GWL_STYLE) & WS_MAXIMIZEBOX) == 0) return false;
    RECT rect{};
    if (!GetWindowRect(root, &rect)) return false;
    const int width = rect.right - rect.left;
    if (width < 600 || point_.y - rect.top > 32) return false;
    for (int i = 1; i <= 10; ++i) {
      const POINT probe{rect.left + width * i / 11, rect.top + 14};
      if (HitTest(root, probe) == HTCAPTION) return false;
    }
    return true;
  }

  POINT point_;
  bool resolved_ = false;
  HWND root_ = nullptr;
  std::optional<LRESULT> hit_;
};

class ShipglowsHotkeysPlugin;

// The one plugin of the process whose low-level hooks run, if any.
ShipglowsHotkeysPlugin* hook_owner = nullptr;
HHOOK keyboard_hook = nullptr;
ShipglowsHotkeysPlugin* mouse_owner = nullptr;
HHOOK mouse_hook = nullptr;

enum class Kind { kHotkey, kHookHotkey, kDoubleKey, kMouse };
enum class Gesture { kClick, kHold, kDrag, kWheelUp, kWheelDown, kTouch };
enum class Button { kNone, kLeft, kRight, kMiddle, kX1, kX2 };

// One instance per engine that registers the plugin. Its hotkeys belong to a
// hidden message-only window, so they work whatever the state of the main
// window (hidden in the tray, minimized) and the runner routes nothing.
// Created on the first registration: overlay engines, which register every
// plugin too, never make one.
class ShipglowsHotkeysPlugin : public flutter::Plugin {
 public:
  explicit ShipglowsHotkeysPlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kChannel,
            &flutter::StandardMethodCodec::GetInstance())) {
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      HandleCall(call, std::move(result));
    });
  }

  ~ShipglowsHotkeysPlugin() override {
    UnregisterAll();
    ShowHiddenWindows();
    if (window_proc_id_) {
      registrar_->UnregisterTopLevelWindowProcDelegate(*window_proc_id_);
    }
    if (window_ != nullptr) {
      SetWindowLongPtrW(window_, GWLP_USERDATA, 0);
      DestroyWindow(window_);
    }
    // No SetMethodCallHandler(nullptr): plugins go away with the engine,
    // whose messenger is already released (access violation on quit).
  }

 private:
  struct Binding {
    Kind kind = Kind::kHotkey;
    UINT modifiers = 0;
    UINT key = 0;
    // Double key.
    ULONGLONG within_ms = 400;
    ULONGLONG last_down = 0;
    // Mouse.
    Gesture gesture = Gesture::kClick;
    Button button = Button::kNone;
    int zone = 0;
    int delay_ms = 0;
    int distance = 0;
    // Executable names in which the trigger passes through.
    std::set<std::wstring> excluded;
  };

  // A press waiting for a hold to elapse or a drag to end.
  struct Pending {
    int slot;
    Button button;
    POINT start;
    HWND window;
  };

  struct QueuedEvent {
    int slot;
    POINT point;
    POINT start;
    HWND window;
  };

  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                      result) {
    const std::string& method = call.method_name();
    const auto* arguments = call.arguments();
    if (method == "register") {
      const auto slot = IntField(arguments, "slot");
      const auto modifiers = IntField(arguments, "modifiers");
      const auto key = IntField(arguments, "key");
      if (!slot || *slot <= 0 || *slot > kMaxSlot || !modifiers || !key ||
          !IsValidHotkey(static_cast<UINT>(*modifiers),
                         static_cast<UINT>(*key))) {
        result->Success(flutter::EncodableValue("invalid"));
        return;
      }
      result->Success(flutter::EncodableValue(Register(
          static_cast<int>(*slot), static_cast<UINT>(*modifiers),
          static_cast<UINT>(*key), BoolField(arguments, "hookFallback"))));
    } else if (method == "registerTrigger") {
      result->Success(flutter::EncodableValue(RegisterTrigger(arguments)));
    } else if (method == "unregister") {
      if (const auto slot = IntField(arguments, "slot")) {
        Unregister(static_cast<int>(*slot));
      }
      result->Success();
    } else if (method == "unregisterAll") {
      UnregisterAll();
      result->Success();
    } else if (method == "windowAction") {
      const auto window = IntField(arguments, "window");
      const auto x = IntField(arguments, "x");
      const auto y = IntField(arguments, "y");
      result->Success(flutter::EncodableValue(RunWindowAction(
          StringField(arguments, "action"),
          WindowFromValue(window.value_or(0)), x, y)));
    } else {
      result->NotImplemented();
    }
  }

  // "registered", "hook" (low-level hook fallback), "alreadyRegistered"
  // (another app owns it) or "failed".
  std::string Register(int slot, UINT modifiers, UINT key, bool hook_fallback) {
    Unregister(slot);
    if (!EnsureWindow()) return "failed";
    if (RegisterHotKey(window_, slot, modifiers | MOD_NOREPEAT, key)) {
      Binding binding;
      binding.kind = Kind::kHotkey;
      binding.modifiers = modifiers;
      binding.key = key;
      bindings_[slot] = binding;
      return "registered";
    }
    // Another app owns this hotkey. Report it rather than shadow it with the
    // hook, which would steal the key from that app.
    if (GetLastError() == ERROR_HOTKEY_ALREADY_REGISTERED) {
      return "alreadyRegistered";
    }
    if (hook_fallback && InstallKeyboardHook()) {
      Binding binding;
      binding.kind = Kind::kHookHotkey;
      binding.modifiers = modifiers;
      binding.key = key;
      bindings_[slot] = binding;
      return "hook";
    }
    return "failed";
  }

  // A double key or a mouse trigger: "registered", "invalid" or "failed".
  std::string RegisterTrigger(const flutter::EncodableValue* arguments) {
    const auto slot_value = IntField(arguments, "slot");
    if (!slot_value || *slot_value <= 0 || *slot_value > kMaxSlot) {
      return "invalid";
    }
    const int slot = static_cast<int>(*slot_value);
    const std::string type = StringField(arguments, "type");
    Binding binding;
    if (const auto* list = Field(arguments, "exclude")) {
      if (const auto* names = std::get_if<flutter::EncodableList>(list)) {
        for (const auto& name : *names) {
          if (const auto* text = std::get_if<std::string>(&name)) {
            binding.excluded.insert(Lower(Widen(*text)));
          }
        }
      }
    }
    if (type == "doubleKey") {
      const auto key = IntField(arguments, "key");
      const auto within = IntField(arguments, "withinMs");
      if (!key || !IsValidHotkey(0, static_cast<UINT>(*key))) return "invalid";
      binding.kind = Kind::kDoubleKey;
      binding.key = static_cast<UINT>(*key);
      binding.within_ms =
          static_cast<ULONGLONG>(std::clamp<int64_t>(within.value_or(400), 150, 1500));
    } else if (type == "mouse") {
      if (!ParseMouse(arguments, &binding)) return "invalid";
    } else {
      return "invalid";
    }
    Unregister(slot);
    if (!EnsureWindow()) return "failed";
    const bool installed = binding.kind == Kind::kDoubleKey
                               ? InstallKeyboardHook()
                               : InstallMouseHook();
    if (!installed) return "failed";
    if (binding.kind == Kind::kMouse && binding.gesture == Gesture::kTouch) {
      has_touch_ = true;
    }
    bindings_[slot] = binding;
    return "registered";
  }

  static bool ParseMouse(const flutter::EncodableValue* arguments,
                         Binding* binding) {
    static const std::map<std::string, Gesture> gestures = {
        {"click", Gesture::kClick},       {"hold", Gesture::kHold},
        {"drag", Gesture::kDrag},         {"wheelUp", Gesture::kWheelUp},
        {"wheelDown", Gesture::kWheelDown}, {"touch", Gesture::kTouch}};
    static const std::map<std::string, Button> buttons = {
        {"left", Button::kLeft},   {"right", Button::kRight},
        {"middle", Button::kMiddle}, {"x1", Button::kX1}, {"x2", Button::kX2}};
    static const std::map<std::string, int> zones = {
        {"anywhere", 0},        {"titleBar", 1},
        {"taskbar", 2},         {"minimizeButton", 3},
        {"maximizeButton", 4},  {"closeButton", 5},
        {"cornerTopLeft", 6},   {"cornerTopRight", 7},
        {"cornerBottomLeft", 8}, {"cornerBottomRight", 9}};
    const auto gesture = gestures.find(StringField(arguments, "gesture"));
    const auto zone = zones.find(StringField(arguments, "zone"));
    const auto modifiers = IntField(arguments, "modifiers");
    if (gesture == gestures.end() || zone == zones.end() || !modifiers ||
        (static_cast<UINT>(*modifiers) & ~kAllowedModifiers) != 0) {
      return false;
    }
    const std::string button_name = StringField(arguments, "button");
    Button button = Button::kNone;
    if (!button_name.empty()) {
      const auto found = buttons.find(button_name);
      if (found == buttons.end()) return false;
      button = found->second;
    }
    const bool needs_button = gesture->second == Gesture::kClick ||
                              gesture->second == Gesture::kHold ||
                              gesture->second == Gesture::kDrag;
    if (needs_button != (button != Button::kNone)) return false;
    const bool corner = zone->second >= 6;
    if (corner != (gesture->second == Gesture::kTouch)) return false;
    binding->kind = Kind::kMouse;
    binding->gesture = gesture->second;
    binding->button = button;
    binding->zone = zone->second;
    binding->modifiers = static_cast<UINT>(*modifiers);
    binding->delay_ms = static_cast<int>(std::clamp<int64_t>(
        IntField(arguments, "delayMs")
            .value_or(gesture->second == Gesture::kTouch ? 300 : 1000),
        50, 5000));
    binding->distance = static_cast<int>(
        std::clamp<int64_t>(IntField(arguments, "distance").value_or(60), 20, 2000));
    return true;
  }

  void Unregister(int slot) {
    const auto found = bindings_.find(slot);
    if (found == bindings_.end()) return;
    if (found->second.kind == Kind::kHotkey) UnregisterHotKey(window_, slot);
    bindings_.erase(found);
    DropPending(slot);
    RefreshHooks();
  }

  void UnregisterAll() {
    for (const auto& [slot, binding] : bindings_) {
      if (binding.kind == Kind::kHotkey) UnregisterHotKey(window_, slot);
    }
    bindings_.clear();
    while (!pending_.empty()) DropPending(pending_.front().slot);
    RefreshHooks();
  }

  bool EnsureWindow() {
    if (window_ != nullptr) return true;
    WNDCLASSEXW window_class{};
    window_class.cbSize = sizeof(window_class);
    window_class.lpfnWndProc = WindowProc;
    window_class.hInstance = ModuleInstance();
    window_class.lpszClassName = kWindowClass;
    // Fails harmlessly once another engine of the process registered it.
    RegisterClassExW(&window_class);
    window_ = CreateWindowExW(0, kWindowClass, L"ShipGlows hotkeys", 0, 0, 0,
                              0, 0, HWND_MESSAGE, nullptr, ModuleInstance(),
                              this);
    if (window_ != nullptr && !window_proc_id_) {
      window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
          [this](HWND, UINT message, WPARAM wparam, LPARAM lparam) {
            return HandleTopLevelMessage(message, wparam, lparam);
          });
    }
    return window_ != nullptr;
  }

  bool InstallKeyboardHook() {
    if (hook_owner != nullptr && hook_owner != this) return false;
    if (keyboard_hook == nullptr) {
      keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                        ModuleInstance(), 0);
      if (keyboard_hook == nullptr) return false;
    }
    hook_owner = this;
    return true;
  }

  bool InstallMouseHook() {
    if (mouse_owner != nullptr && mouse_owner != this) return false;
    if (mouse_hook == nullptr) {
      mouse_hook = SetWindowsHookExW(WH_MOUSE_LL, LowLevelMouseProc,
                                     ModuleInstance(), 0);
      if (mouse_hook == nullptr) return false;
    }
    mouse_owner = this;
    return true;
  }

  // Removes the hooks nothing needs any more.
  void RefreshHooks() {
    bool keyboard = false;
    bool mouse = false;
    has_touch_ = false;
    for (const auto& [slot, binding] : bindings_) {
      if (binding.kind == Kind::kHookHotkey ||
          binding.kind == Kind::kDoubleKey) {
        keyboard = true;
      }
      if (binding.kind == Kind::kMouse) {
        mouse = true;
        if (binding.gesture == Gesture::kTouch) has_touch_ = true;
      }
    }
    if (!keyboard && hook_owner == this) {
      if (keyboard_hook != nullptr) UnhookWindowsHookEx(keyboard_hook);
      keyboard_hook = nullptr;
      hook_owner = nullptr;
      held_.clear();
    }
    if (!mouse && mouse_owner == this) {
      if (mouse_hook != nullptr) UnhookWindowsHookEx(mouse_hook);
      mouse_hook = nullptr;
      mouse_owner = nullptr;
      swallowed_up_.clear();
      events_.clear();
    }
    if (!has_touch_) StopTouch();
  }

  // ---- Keyboard hook ----------------------------------------------------

  bool IsWatchedKey(DWORD key) const {
    return std::any_of(bindings_.begin(), bindings_.end(), [&](const auto& e) {
      return (e.second.kind == Kind::kHookHotkey ||
              e.second.kind == Kind::kDoubleKey) &&
             e.second.key == key;
    });
  }

  bool IsExcluded(const Binding& binding, HWND window) const {
    if (binding.excluded.empty() || window == nullptr) return false;
    return binding.excluded.count(ProcessNameOf(window)) > 0;
  }

  // Never swallows the key: the hook only stands in for a hotkey Windows
  // refused for another reason than an owner, and sees a key pressed twice.
  void OnHookKey(WPARAM wparam, const KBDLLHOOKSTRUCT& event) {
    if (wparam == WM_KEYUP || wparam == WM_SYSKEYUP) {
      held_.erase(std::remove(held_.begin(), held_.end(), event.vkCode),
                  held_.end());
      return;
    }
    if (wparam != WM_KEYDOWN && wparam != WM_SYSKEYDOWN) return;
    // Auto-repeat of a key already reported.
    if (std::find(held_.begin(), held_.end(), event.vkCode) != held_.end()) {
      return;
    }
    if (IsWatchedKey(event.vkCode)) held_.push_back(event.vkCode);
    const UINT modifiers = HeldModifiers(event);
    const ULONGLONG now = GetTickCount64();
    int fire = 0;
    for (auto& [slot, binding] : bindings_) {
      if (binding.kind == Kind::kDoubleKey) {
        if (binding.key != event.vkCode || modifiers != 0) {
          binding.last_down = 0;  // another key came between the two presses
        } else if (binding.last_down != 0 &&
                   now - binding.last_down <= binding.within_ms &&
                   !IsExcluded(binding, GetForegroundWindow())) {
          binding.last_down = 0;
          if (fire == 0) fire = slot;
        } else {
          binding.last_down = now;
        }
      } else if (binding.kind == Kind::kHookHotkey &&
                 binding.key == event.vkCode && binding.modifiers == modifiers &&
                 fire == 0) {
        fire = slot;
      }
    }
    if (fire != 0) {
      PostMessageW(window_, kHookHotkeyMessage, static_cast<WPARAM>(fire), 0);
    }
  }

  static LRESULT CALLBACK LowLevelKeyboardProc(int code, WPARAM wparam,
                                               LPARAM lparam) {
    if (code == HC_ACTION && hook_owner != nullptr) {
      hook_owner->OnHookKey(wparam,
                            *reinterpret_cast<const KBDLLHOOKSTRUCT*>(lparam));
    }
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }

  // ---- Mouse hook -------------------------------------------------------

  static LRESULT CALLBACK LowLevelMouseProc(int code, WPARAM wparam,
                                            LPARAM lparam) {
    if (code == HC_ACTION && mouse_owner != nullptr) {
      const auto& event = *reinterpret_cast<const MSLLHOOKSTRUCT*>(lparam);
      // Input sent by another program (or by this one) is never a gesture.
      if ((event.flags & (LLMHF_INJECTED | LLMHF_LOWER_IL_INJECTED)) == 0 &&
          mouse_owner->OnMouse(wparam, event)) {
        return 1;
      }
    }
    return CallNextHookEx(nullptr, code, wparam, lparam);
  }

  // True swallows the event.
  bool OnMouse(WPARAM message, const MSLLHOOKSTRUCT& event) {
    switch (message) {
      case WM_MOUSEMOVE:
        OnMove(PointOf(event));
        return false;
      case WM_LBUTTONDOWN:
        return OnButtonDown(Button::kLeft, PointOf(event));
      case WM_LBUTTONUP:
        return OnButtonUp(Button::kLeft, PointOf(event));
      case WM_RBUTTONDOWN:
        return OnButtonDown(Button::kRight, PointOf(event));
      case WM_RBUTTONUP:
        return OnButtonUp(Button::kRight, PointOf(event));
      case WM_MBUTTONDOWN:
        return OnButtonDown(Button::kMiddle, PointOf(event));
      case WM_MBUTTONUP:
        return OnButtonUp(Button::kMiddle, PointOf(event));
      case WM_XBUTTONDOWN:
        return OnButtonDown(XButton(event), PointOf(event));
      case WM_XBUTTONUP:
        return OnButtonUp(XButton(event), PointOf(event));
      case WM_MOUSEWHEEL:
        return OnWheel(static_cast<short>(HIWORD(event.mouseData)),
                       PointOf(event));
      default:
        return false;
    }
  }

  static Button XButton(const MSLLHOOKSTRUCT& event) {
    return HIWORD(event.mouseData) == XBUTTON1 ? Button::kX1 : Button::kX2;
  }

  bool OnButtonDown(Button button, POINT point) {
    const UINT modifiers = HeldModifiers();
    ZoneProbe probe(point);
    bool swallow = false;
    for (const auto& [slot, binding] : bindings_) {
      if (binding.kind != Kind::kMouse || binding.button != button ||
          binding.modifiers != modifiers ||
          (binding.gesture != Gesture::kClick &&
           binding.gesture != Gesture::kHold &&
           binding.gesture != Gesture::kDrag)) {
        continue;
      }
      if (!probe.Matches(binding.zone)) continue;
      if (IsExcluded(binding, probe.Root())) continue;
      if (binding.gesture == Gesture::kClick) {
        Queue(slot, point, point, probe.Root());
        swallowed_up_.insert(button);
        swallow = true;
      } else {
        pending_.push_back(Pending{slot, button, point, probe.Root()});
        if (binding.gesture == Gesture::kHold) {
          SetTimer(window_, kHoldTimerBase + static_cast<UINT_PTR>(slot),
                   static_cast<UINT>(binding.delay_ms), nullptr);
        }
      }
    }
    return swallow;
  }

  bool OnButtonUp(Button button, POINT point) {
    const bool swallow = swallowed_up_.erase(button) > 0;
    for (auto it = pending_.begin(); it != pending_.end();) {
      if (it->button != button) {
        ++it;
        continue;
      }
      const auto found = bindings_.find(it->slot);
      if (found != bindings_.end()) {
        if (found->second.gesture == Gesture::kHold) {
          KillTimer(window_, kHoldTimerBase + static_cast<UINT_PTR>(it->slot));
        } else if (found->second.gesture == Gesture::kDrag &&
                   Distance(it->start, point) >= found->second.distance) {
          Queue(it->slot, point, it->start, it->window);
        }
      }
      it = pending_.erase(it);
    }
    return swallow;
  }

  bool OnWheel(int delta, POINT point) {
    if (delta == 0) return false;
    const Gesture wanted = delta > 0 ? Gesture::kWheelUp : Gesture::kWheelDown;
    const UINT modifiers = HeldModifiers();
    ZoneProbe probe(point);
    bool swallow = false;
    for (const auto& [slot, binding] : bindings_) {
      if (binding.kind != Kind::kMouse || binding.gesture != wanted ||
          binding.modifiers != modifiers) {
        continue;
      }
      if (!probe.Matches(binding.zone)) continue;
      if (IsExcluded(binding, probe.Root())) continue;
      Queue(slot, point, point, probe.Root());
      swallow = true;
    }
    return swallow;
  }

  void OnMove(POINT point) {
    for (auto it = pending_.begin(); it != pending_.end();) {
      const auto found = bindings_.find(it->slot);
      if (found != bindings_.end() && found->second.gesture == Gesture::kHold &&
          Distance(it->start, point) > kHoldTolerance) {
        KillTimer(window_, kHoldTimerBase + static_cast<UINT_PTR>(it->slot));
        it = pending_.erase(it);
      } else {
        ++it;
      }
    }
    if (!has_touch_) return;
    const int corner = CornerAt(point);
    if (corner == touch_corner_) return;
    StopTouch();
    touch_corner_ = corner;
    if (corner < 0) return;
    for (const auto& [slot, binding] : bindings_) {
      if (binding.kind == Kind::kMouse && binding.gesture == Gesture::kTouch &&
          binding.zone == 6 + corner) {
        SetTimer(window_, kTouchTimer, static_cast<UINT>(binding.delay_ms),
                 nullptr);
        return;
      }
    }
  }

  void StopTouch() {
    if (touch_corner_ >= 0 && window_ != nullptr) KillTimer(window_, kTouchTimer);
    touch_corner_ = -1;
  }

  void DropPending(int slot) {
    if (window_ != nullptr) {
      KillTimer(window_, kHoldTimerBase + static_cast<UINT_PTR>(slot));
    }
    pending_.erase(std::remove_if(pending_.begin(), pending_.end(),
                                  [slot](const Pending& p) {
                                    return p.slot == slot;
                                  }),
                   pending_.end());
  }

  // The hook only queues: Dart is reached from the message loop, not from
  // inside the hook, whose time is limited.
  void Queue(int slot, POINT point, POINT start, HWND window) {
    events_.push_back(QueuedEvent{slot, point, start, window});
    PostMessageW(window_, kHookMouseMessage, 0, 0);
  }

  void OnTimer(UINT_PTR id) {
    if (id == kTouchTimer) {
      KillTimer(window_, kTouchTimer);
      POINT point{};
      if (touch_corner_ < 0 || !GetCursorPos(&point) ||
          CornerAt(point) != touch_corner_) {
        return;
      }
      const UINT modifiers = HeldModifiers();
      ZoneProbe probe(point);
      for (const auto& [slot, binding] : bindings_) {
        if (binding.kind == Kind::kMouse && binding.gesture == Gesture::kTouch &&
            binding.zone == 6 + touch_corner_ && binding.modifiers == modifiers &&
            !IsExcluded(binding, GetForegroundWindow())) {
          OnTrigger(slot, probe.Root(), &point, &point);
          return;
        }
      }
      return;
    }
    if (id < kHoldTimerBase) return;
    const int slot = static_cast<int>(id - kHoldTimerBase);
    KillTimer(window_, id);
    for (auto it = pending_.begin(); it != pending_.end(); ++it) {
      if (it->slot != slot) continue;
      POINT point{};
      // Still down and still: the press is a hold.
      if (GetCursorPos(&point) && Distance(it->start, point) <= kHoldTolerance) {
        const Pending hold = *it;
        pending_.erase(it);
        OnTrigger(slot, hold.window, &point, &hold.start);
      }
      return;
    }
  }

  void DrainEvents() {
    while (!events_.empty()) {
      const QueuedEvent event = events_.front();
      events_.pop_front();
      OnTrigger(event.slot, event.window, &event.point, &event.start);
    }
  }

  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      const auto* create = reinterpret_cast<const CREATESTRUCTW*>(lparam);
      SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
    }
    auto* plugin = reinterpret_cast<ShipglowsHotkeysPlugin*>(
        GetWindowLongPtrW(window, GWLP_USERDATA));
    if (plugin != nullptr) {
      if (message == WM_HOTKEY || message == kHookHotkeyMessage) {
        plugin->OnTrigger(static_cast<int>(wparam), nullptr, nullptr, nullptr);
        return 0;
      }
      if (message == kHookMouseMessage) {
        plugin->DrainEvents();
        return 0;
      }
      if (message == WM_TIMER) {
        plugin->OnTimer(static_cast<UINT_PTR>(wparam));
        return 0;
      }
    }
    return DefWindowProcW(window, message, wparam, lparam);
  }

  // Reads the window in front at once, before any Dart code runs, and tells
  // Dart where it belongs. |point| and |start| are set for mouse triggers.
  void OnTrigger(int slot, HWND target, const POINT* point, const POINT* start) {
    const auto found = bindings_.find(slot);
    if (found == bindings_.end()) return;
    if (found->second.kind != Kind::kMouse) hotkey_tick_ = GetTickCount64();
    const HWND foreground = GetForegroundWindow();
    const char* kind = ForegroundKind(foreground);
    if (target == nullptr && foreground != nullptr) {
      target = GetAncestor(foreground, GA_ROOT);
    }
    flutter::EncodableMap payload{
        {flutter::EncodableValue("slot"), flutter::EncodableValue(slot)},
        {flutter::EncodableValue("foreground"), flutter::EncodableValue(kind)},
        {flutter::EncodableValue("previousForeground"),
         HandleValue(std::string(kind) == "none" ? nullptr : foreground)},
        {flutter::EncodableValue("window"), HandleValue(target)},
    };
    if (point != nullptr) {
      payload[flutter::EncodableValue("x")] = flutter::EncodableValue(
          static_cast<int32_t>(point->x));
      payload[flutter::EncodableValue("y")] = flutter::EncodableValue(
          static_cast<int32_t>(point->y));
    }
    if (start != nullptr) {
      payload[flutter::EncodableValue("startX")] = flutter::EncodableValue(
          static_cast<int32_t>(start->x));
      payload[flutter::EncodableValue("startY")] = flutter::EncodableValue(
          static_cast<int32_t>(start->y));
    }
    channel_->InvokeMethod(
        "onHotkey",
        std::make_unique<flutter::EncodableValue>(std::move(payload)));
  }

  // "app" (the main window, shown), "ownWindow" (another window of this
  // process, such as an overlay), "otherApp" or "none".
  const char* ForegroundKind(HWND foreground) const {
    if (foreground == nullptr) return "none";
    const HWND root = GetAncestor(foreground, GA_ROOT);
    const HWND main = MainWindow();
    if (main != nullptr && root == main) {
      return IsWindowVisible(main) && !IsIconic(main) ? "app" : "none";
    }
    DWORD process = 0;
    GetWindowThreadProcessId(root, &process);
    return process == GetCurrentProcessId() ? "ownWindow" : "otherApp";
  }

  HWND MainWindow() const {
    flutter::FlutterView* view = registrar_->GetView();
    const HWND child = view ? view->GetNativeWindow() : nullptr;
    return child ? GetAncestor(child, GA_ROOT) : nullptr;
  }

  // Alt released right after an Alt+key hotkey pressed in the app: Windows
  // would enter menu mode and swallow the first key typed in what the hotkey
  // opened.
  std::optional<LRESULT> HandleTopLevelMessage(UINT message, WPARAM wparam,
                                               LPARAM lparam) const {
    if (message == WM_SYSCOMMAND && (wparam & 0xFFF0) == SC_KEYMENU &&
        lparam == 0 && GetTickCount64() - hotkey_tick_ < kMenuSuppressMs) {
      return 0;
    }
    return std::nullopt;
  }

  // ---- Window actions ---------------------------------------------------

  // "ok", "topmostOn", "topmostOff", "noWindow" or "failed".
  std::string RunWindowAction(const std::string& action, HWND window,
                              std::optional<int64_t> x,
                              std::optional<int64_t> y) {
    if (action == "volumeUp") return Key(VK_VOLUME_UP);
    if (action == "volumeDown") return Key(VK_VOLUME_DOWN);
    if (action == "volumeMute") return Key(VK_VOLUME_MUTE);
    if (action == "restoreHidden") return RestoreHidden();
    if (window == nullptr || !IsWindow(window) || IsShellWindow(window)) {
      return "noWindow";
    }
    window = GetAncestor(window, GA_ROOT);
    if (action == "minimize") return Post(window, SC_MINIMIZE);
    if (action == "maximize") return Post(window, SC_MAXIMIZE);
    if (action == "restore") return Post(window, SC_RESTORE);
    if (action == "toggleMaximize") {
      return Post(window, IsZoomed(window) ? SC_RESTORE : SC_MAXIMIZE);
    }
    if (action == "close") {
      return PostMessageW(window, WM_CLOSE, 0, 0) ? "ok" : "failed";
    }
    if (action == "toggleAlwaysOnTop") return ToggleTopmost(window);
    if (action == "hide") return Hide(window);
    if (action == "restoreSize") return RestoreSize(window);
    if (action == "snapToPointer") {
      if (!x || !y) return "failed";
      return SnapToPointer(window, POINT{static_cast<LONG>(*x), static_cast<LONG>(*y)});
    }
    static const std::map<std::string, std::pair<int, int>> snaps = {
        // column (0 left, 1 whole, 2 right), row (0 top, 1 whole, 2 bottom)
        {"snapLeft", {0, 1}},     {"snapRight", {2, 1}},
        {"snapTop", {1, 0}},      {"snapBottom", {1, 2}},
        {"snapTopLeft", {0, 0}},  {"snapTopRight", {2, 0}},
        {"snapBottomLeft", {0, 2}}, {"snapBottomRight", {2, 2}}};
    const auto snap = snaps.find(action);
    if (snap == snaps.end()) return "failed";
    return Snap(window, snap->second.first, snap->second.second);
  }

  static std::string Post(HWND window, WPARAM command) {
    return PostMessageW(window, WM_SYSCOMMAND, command, 0) ? "ok" : "failed";
  }

  static std::string Key(WORD key) {
    INPUT inputs[2] = {};
    inputs[0].type = INPUT_KEYBOARD;
    inputs[0].ki.wVk = key;
    inputs[1] = inputs[0];
    inputs[1].ki.dwFlags = KEYEVENTF_KEYUP;
    return SendInput(2, inputs, sizeof(INPUT)) == 2 ? "ok" : "failed";
  }

  static std::string ToggleTopmost(HWND window) {
    const bool on = (GetWindowLongW(window, GWL_EXSTYLE) & WS_EX_TOPMOST) != 0;
    if (!SetWindowPos(window, on ? HWND_NOTOPMOST : HWND_TOPMOST, 0, 0, 0, 0,
                      SWP_NOMOVE | SWP_NOSIZE | SWP_NOACTIVATE)) {
      return "failed";
    }
    return on ? "topmostOff" : "topmostOn";
  }

  std::string Hide(HWND window) {
    if (!IsWindowVisible(window)) return "noWindow";
    ShowWindow(window, SW_HIDE);
    hidden_.push_back(window);
    return "ok";
  }

  std::string RestoreHidden() {
    while (!hidden_.empty()) {
      const HWND window = hidden_.back();
      hidden_.pop_back();
      if (!IsWindow(window)) continue;
      ShowWindow(window, SW_SHOW);
      SetForegroundWindow(window);
      return "ok";
    }
    return "noWindow";
  }

  void ShowHiddenWindows() {
    for (const HWND window : hidden_) {
      if (IsWindow(window)) ShowWindow(window, SW_SHOW);
    }
    hidden_.clear();
  }

  // Invisible resize borders Windows 10/11 add around a window.
  static RECT FrameMargins(HWND window) {
    RECT outer{};
    RECT frame{};
    RECT margins{};
    if (GetWindowRect(window, &outer) &&
        SUCCEEDED(DwmGetWindowAttribute(window, DWMWA_EXTENDED_FRAME_BOUNDS,
                                        &frame, sizeof(frame)))) {
      margins.left = frame.left - outer.left;
      margins.top = frame.top - outer.top;
      margins.right = outer.right - frame.right;
      margins.bottom = outer.bottom - frame.bottom;
    }
    return margins;
  }

  std::string Snap(HWND window, int column, int row) {
    if (column == 1 && row == 0) {
      return Post(window, SC_MAXIMIZE);
    }
    if (IsZoomed(window)) ShowWindow(window, SW_RESTORE);
    if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
    const HMONITOR monitor = MonitorFromWindow(window, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    if (monitor == nullptr || !GetMonitorInfoW(monitor, &info)) return "failed";
    const RECT work = info.rcWork;
    const int width = work.right - work.left;
    const int height = work.bottom - work.top;
    RECT target = work;
    if (column == 0) target.right = work.left + width / 2;
    if (column == 2) target.left = work.left + width / 2;
    if (row == 0) target.bottom = work.top + height / 2;
    if (row == 2) target.top = work.top + height / 2;
    if (snapped_.count(window) == 0) {
      RECT before{};
      if (GetWindowRect(window, &before)) snapped_[window] = before;
    }
    const RECT margins = FrameMargins(window);
    return SetWindowPos(window, nullptr, target.left - margins.left,
                        target.top - margins.top,
                        target.right - target.left + margins.left + margins.right,
                        target.bottom - target.top + margins.top + margins.bottom,
                        SWP_NOZORDER | SWP_NOACTIVATE)
               ? "ok"
               : "failed";
  }

  // The part of the screen the pointer ended in; the middle maximizes.
  std::string SnapToPointer(HWND window, POINT point) {
    const HMONITOR monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
    MONITORINFO info{};
    info.cbSize = sizeof(info);
    if (monitor == nullptr || !GetMonitorInfoW(monitor, &info)) return "failed";
    const RECT& r = info.rcMonitor;
    const double fx = static_cast<double>(point.x - r.left) / (r.right - r.left);
    const double fy = static_cast<double>(point.y - r.top) / (r.bottom - r.top);
    const int column = fx < 0.25 ? 0 : (fx > 0.75 ? 2 : 1);
    const int row = fy < 0.25 ? 0 : (fy > 0.75 ? 2 : 1);
    if (column == 1 && row == 1) return Post(window, SC_MAXIMIZE);
    return Snap(window, column, row);
  }

  std::string RestoreSize(HWND window) {
    const auto found = snapped_.find(window);
    if (found == snapped_.end()) {
      return IsZoomed(window) ? Post(window, SC_RESTORE) : "noWindow";
    }
    const RECT before = found->second;
    snapped_.erase(found);
    return SetWindowPos(window, nullptr, before.left, before.top,
                        before.right - before.left, before.bottom - before.top,
                        SWP_NOZORDER | SWP_NOACTIVATE)
               ? "ok"
               : "failed";
  }

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_ = nullptr;
  std::optional<int> window_proc_id_;
  std::map<int, Binding> bindings_;
  std::vector<DWORD> held_;
  ULONGLONG hotkey_tick_ = 0;
  // Mouse state.
  std::vector<Pending> pending_;
  std::deque<QueuedEvent> events_;
  std::set<Button> swallowed_up_;
  bool has_touch_ = false;
  int touch_corner_ = -1;
  // Window actions.
  std::vector<HWND> hidden_;
  std::map<HWND, RECT> snapped_;
};

}  // namespace
}  // namespace shipglows_hotkeys

void ShipglowsHotkeysPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows_registrar->AddPlugin(
      std::make_unique<shipglows_hotkeys::ShipglowsHotkeysPlugin>(
          windows_registrar));
}
