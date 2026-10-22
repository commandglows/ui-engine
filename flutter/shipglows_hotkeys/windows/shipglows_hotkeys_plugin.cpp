#include "include/shipglows_hotkeys/shipglows_hotkeys_plugin_c_api.h"

#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <algorithm>
#include <map>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace shipglows_hotkeys {
namespace {

constexpr char kChannel[] = "shipglows_hotkeys";
constexpr wchar_t kWindowClass[] = L"ShipglowsHotkeysWindow";
// Posted to the plugin's window by the low-level hook (wParam: slot).
constexpr UINT kHookHotkeyMessage = WM_APP + 0x5B1;
// Alt released right after an Alt+key hotkey pressed in the app: within this
// delay the main window ignores the menu-bar request it triggers.
constexpr ULONGLONG kMenuSuppressMs = 500;
constexpr UINT kAllowedModifiers = MOD_ALT | MOD_CONTROL | MOD_SHIFT | MOD_WIN;
// Ids an application may give RegisterHotKey.
constexpr int64_t kMaxSlot = 0xBFFF;

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

// Modifiers held while the low-level hook sees |event|.
UINT HeldModifiers(const KBDLLHOOKSTRUCT& event) {
  UINT modifiers = 0;
  if ((event.flags & LLKHF_ALTDOWN) != 0 ||
      (GetAsyncKeyState(VK_MENU) & 0x8000) != 0) {
    modifiers |= MOD_ALT;
  }
  if ((GetAsyncKeyState(VK_CONTROL) & 0x8000) != 0) modifiers |= MOD_CONTROL;
  if ((GetAsyncKeyState(VK_SHIFT) & 0x8000) != 0) modifiers |= MOD_SHIFT;
  if ((GetAsyncKeyState(VK_LWIN) & 0x8000) != 0 ||
      (GetAsyncKeyState(VK_RWIN) & 0x8000) != 0) {
    modifiers |= MOD_WIN;
  }
  return modifiers;
}

flutter::EncodableValue HandleValue(HWND window) {
  return flutter::EncodableValue(
      static_cast<int64_t>(reinterpret_cast<intptr_t>(window)));
}

class ShipglowsHotkeysPlugin;

// The one plugin of the process whose low-level hook runs, if any.
ShipglowsHotkeysPlugin* hook_owner = nullptr;
HHOOK keyboard_hook = nullptr;

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
    if (window_proc_id_) {
      registrar_->UnregisterTopLevelWindowProcDelegate(*window_proc_id_);
    }
    if (window_ != nullptr) {
      SetWindowLongPtrW(window_, GWLP_USERDATA, 0);
      DestroyWindow(window_);
    }
    channel_->SetMethodCallHandler(nullptr);
  }

 private:
  struct Binding {
    UINT modifiers;
    UINT key;
    // Matched by the low-level hook instead of RegisterHotKey.
    bool hook;
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
    } else if (method == "unregister") {
      if (const auto slot = IntField(arguments, "slot")) {
        Unregister(static_cast<int>(*slot));
      }
      result->Success();
    } else if (method == "unregisterAll") {
      UnregisterAll();
      result->Success();
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
      bindings_[slot] = Binding{modifiers, key, false};
      return "registered";
    }
    // Another app owns this hotkey. Report it rather than shadow it with the
    // hook, which would steal the key from that app.
    if (GetLastError() == ERROR_HOTKEY_ALREADY_REGISTERED) {
      return "alreadyRegistered";
    }
    if (hook_fallback && InstallHook()) {
      bindings_[slot] = Binding{modifiers, key, true};
      return "hook";
    }
    return "failed";
  }

  void Unregister(int slot) {
    const auto found = bindings_.find(slot);
    if (found == bindings_.end()) return;
    if (!found->second.hook) UnregisterHotKey(window_, slot);
    bindings_.erase(found);
    ReleaseHookIfUnused();
  }

  void UnregisterAll() {
    for (const auto& [slot, binding] : bindings_) {
      if (!binding.hook) UnregisterHotKey(window_, slot);
    }
    bindings_.clear();
    ReleaseHookIfUnused();
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

  bool InstallHook() {
    if (hook_owner != nullptr && hook_owner != this) return false;
    if (keyboard_hook == nullptr) {
      keyboard_hook = SetWindowsHookExW(WH_KEYBOARD_LL, LowLevelKeyboardProc,
                                        ModuleInstance(), 0);
      if (keyboard_hook == nullptr) return false;
    }
    hook_owner = this;
    return true;
  }

  void ReleaseHookIfUnused() {
    if (hook_owner != this) return;
    const bool used = std::any_of(
        bindings_.begin(), bindings_.end(),
        [](const auto& entry) { return entry.second.hook; });
    if (used) return;
    if (keyboard_hook != nullptr) UnhookWindowsHookEx(keyboard_hook);
    keyboard_hook = nullptr;
    hook_owner = nullptr;
    keys_down_.clear();
  }

  // Never swallows the key: the hook only stands in for a hotkey Windows
  // refused for another reason than an owner.
  void OnHookKey(WPARAM wparam, const KBDLLHOOKSTRUCT& event) {
    if (wparam == WM_KEYUP || wparam == WM_SYSKEYUP) {
      keys_down_.erase(
          std::remove(keys_down_.begin(), keys_down_.end(), event.vkCode),
          keys_down_.end());
      return;
    }
    if (wparam != WM_KEYDOWN && wparam != WM_SYSKEYDOWN) return;
    // Auto-repeat of a key already reported.
    if (std::find(keys_down_.begin(), keys_down_.end(), event.vkCode) !=
        keys_down_.end()) {
      return;
    }
    const UINT modifiers = HeldModifiers(event);
    for (const auto& [slot, binding] : bindings_) {
      if (binding.hook && binding.key == event.vkCode &&
          binding.modifiers == modifiers) {
        keys_down_.push_back(event.vkCode);
        PostMessageW(window_, kHookHotkeyMessage, static_cast<WPARAM>(slot), 0);
        return;
      }
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

  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam) {
    if (message == WM_NCCREATE) {
      const auto* create = reinterpret_cast<const CREATESTRUCTW*>(lparam);
      SetWindowLongPtrW(window, GWLP_USERDATA,
                        reinterpret_cast<LONG_PTR>(create->lpCreateParams));
    }
    auto* plugin = reinterpret_cast<ShipglowsHotkeysPlugin*>(
        GetWindowLongPtrW(window, GWLP_USERDATA));
    if (plugin != nullptr &&
        (message == WM_HOTKEY || message == kHookHotkeyMessage)) {
      plugin->OnHotkey(static_cast<int>(wparam));
      return 0;
    }
    return DefWindowProcW(window, message, wparam, lparam);
  }

  // Reads the window in front at once, before any Dart code runs, and tells
  // Dart where it belongs.
  void OnHotkey(int slot) {
    if (bindings_.count(slot) == 0) return;
    hotkey_tick_ = GetTickCount64();
    const HWND foreground = GetForegroundWindow();
    const char* kind = ForegroundKind(foreground);
    channel_->InvokeMethod(
        "onHotkey",
        std::make_unique<flutter::EncodableValue>(flutter::EncodableMap{
            {flutter::EncodableValue("slot"), flutter::EncodableValue(slot)},
            {flutter::EncodableValue("foreground"),
             flutter::EncodableValue(kind)},
            {flutter::EncodableValue("previousForeground"),
             HandleValue(std::string(kind) == "none" ? nullptr : foreground)},
        }));
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

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  HWND window_ = nullptr;
  std::optional<int> window_proc_id_;
  std::map<int, Binding> bindings_;
  std::vector<DWORD> keys_down_;
  ULONGLONG hotkey_tick_ = 0;
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
