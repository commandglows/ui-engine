#include "include/shipglows_tray/shipglows_tray_plugin_c_api.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <cwchar>
#include <memory>
#include <optional>
#include <string>
#include <utility>
#include <vector>

#include "encodable_utils.h"
#include "tray_host.h"
#include "tray_menu.h"
#include "window_activation.h"

namespace shipglows_tray {
namespace {

constexpr char kChannel[] = "shipglows_tray";
// IDI_APP_ICON of the Flutter Windows runner template.
constexpr int kAppIconResource = 101;

enum class CloseBehavior { kHideToTray, kMinimize, kQuit };
enum class PrimaryClick { kOpenMainWindow, kMenu, kEvent, kItem };

CloseBehavior CloseBehaviorFrom(const std::string& name) {
  if (name == "minimize") return CloseBehavior::kMinimize;
  if (name == "quit") return CloseBehavior::kQuit;
  return CloseBehavior::kHideToTray;
}

std::wstring ExecutableDirectory() {
  std::wstring path(MAX_PATH, L'\0');
  const DWORD length =
      GetModuleFileNameW(nullptr, path.data(), static_cast<DWORD>(path.size()));
  path.resize(length);
  const size_t separator = path.find_last_of(L"\\/");
  return separator == std::wstring::npos ? std::wstring()
                                         : path.substr(0, separator);
}

// The icon |image| describes (ShipglowsTrayImage.toMap), at the small icon
// size; the executable's icon when it cannot be loaded.
HICON LoadTrayIcon(const flutter::EncodableValue* image) {
  const int width = GetSystemMetrics(SM_CXSMICON);
  const int height = GetSystemMetrics(SM_CYSMICON);
  const std::string kind = StringField(image, "kind");
  std::wstring path = Wide(StringField(image, "path"));
  if (kind == "asset" && !path.empty()) {
    for (wchar_t& character : path) {
      if (character == L'/') character = L'\\';
    }
    path = ExecutableDirectory() + L"\\data\\flutter_assets\\" + path;
  }
  if ((kind == "asset" || kind == "file") && !path.empty()) {
    if (auto* icon = static_cast<HICON>(LoadImageW(
            nullptr, path.c_str(), IMAGE_ICON, width, height,
            LR_LOADFROMFILE))) {
      return icon;
    }
  }
  return static_cast<HICON>(LoadImageW(
      GetModuleHandleW(nullptr), MAKEINTRESOURCEW(kAppIconResource),
      IMAGE_ICON, width, height, LR_DEFAULTCOLOR));
}

// The executable's ProductVersion (Flutter writes the pubspec version,
// "1.2.3+4"); empty if missing.
std::string ProductVersion() {
  std::wstring path(MAX_PATH, L'\0');
  path.resize(GetModuleFileNameW(nullptr, path.data(),
                                 static_cast<DWORD>(path.size())));
  DWORD handle = 0;
  const DWORD size = GetFileVersionInfoSizeW(path.c_str(), &handle);
  if (size == 0) return {};
  std::vector<BYTE> data(size);
  if (!GetFileVersionInfoW(path.c_str(), 0, size, data.data())) return {};
  struct Translation {
    WORD language;
    WORD code_page;
  };
  Translation* translations = nullptr;
  UINT length = 0;
  if (!VerQueryValueW(data.data(), L"\\VarFileInfo\\Translation",
                      reinterpret_cast<LPVOID*>(&translations), &length) ||
      length < sizeof(Translation)) {
    return {};
  }
  wchar_t key[64];
  swprintf_s(key, L"\\StringFileInfo\\%04x%04x\\ProductVersion",
             translations[0].language, translations[0].code_page);
  wchar_t* value = nullptr;
  UINT characters = 0;
  if (!VerQueryValueW(data.data(), key, reinterpret_cast<LPVOID*>(&value),
                      &characters) ||
      value == nullptr) {
    return {};
  }
  return Utf8(value);
}

class ShipglowsTrayPlugin : public flutter::Plugin {
 public:
  explicit ShipglowsTrayPlugin(flutter::PluginRegistrarWindows* registrar)
      : registrar_(registrar),
        channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kChannel,
            &flutter::StandardMethodCodec::GetInstance())),
        host_(TrayHost::Callbacks{
            [this](TrayHost::IconAction action, POINT anchor) {
              OnIcon(action, anchor);
            },
            [this](const std::vector<std::wstring>& arguments) {
              OnSecondInstance(arguments);
            },
            [this](bool visible) {
              if (started_) {
                Emit({{flutter::EncodableValue("type"),
                       flutter::EncodableValue("iconVisible")},
                      {flutter::EncodableValue("visible"),
                       flutter::EncodableValue(visible)}});
              }
            },
        }) {
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      HandleCall(call, std::move(result));
    });
    window_proc_id_ = registrar_->RegisterTopLevelWindowProcDelegate(
        [this](HWND window, UINT message, WPARAM wparam, LPARAM lparam) {
          return HandleTopLevelMessage(window, message, wparam, lparam);
        });
  }

  ~ShipglowsTrayPlugin() override {
    // The engine is going away: removing the icon must not message Dart.
    started_ = false;
    registrar_->UnregisterTopLevelWindowProcDelegate(window_proc_id_);
    channel_->SetMethodCallHandler(nullptr);
  }

 private:
  void HandleCall(const flutter::MethodCall<flutter::EncodableValue>& call,
                  std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>
                      result) {
    const std::string& method = call.method_name();
    const auto* arguments = call.arguments();
    if (method == "version") {
      result->Success(flutter::EncodableValue(ProductVersion()));
    } else if (method == "start") {
      close_behavior_ =
          CloseBehaviorFrom(StringField(arguments, "closeBehavior"));
      second_instance_shows_main_window_ =
          BoolField(arguments, "secondInstanceShowsMainWindow", true);
      has_quit_handler_ = BoolField(arguments, "hasQuitHandler", false);
      const std::string click = StringField(arguments, "primaryClick");
      primary_click_ = click == "menu"    ? PrimaryClick::kMenu
                       : click == "event" ? PrimaryClick::kEvent
                       : click == "item"  ? PrimaryClick::kItem
                                          : PrimaryClick::kOpenMainWindow;
      primary_item_ = StringField(arguments, "primaryItem");
      ApplyAppearance(arguments);
      quitting_ = false;
      started_ = true;
      const bool visible = host_.Show();
      result->Success(flutter::EncodableValue(visible));
      FlushPendingSecondInstances();
    } else if (method == "update") {
      ApplyAppearance(arguments);
      result->Success();
    } else if (method == "setCloseBehavior") {
      close_behavior_ =
          CloseBehaviorFrom(StringField(arguments, "closeBehavior"));
      result->Success();
    } else if (method == "showMainWindow") {
      ShowMainWindow();
      result->Success();
    } else if (method == "quit") {
      result->Success();
      Quit();
    } else if (method == "dispose") {
      started_ = false;
      host_.Hide();
      items_.clear();
      result->Success();
    } else {
      result->NotImplemented();
    }
  }

  void ApplyAppearance(const flutter::EncodableValue* arguments) {
    if (Field(arguments, "tooltip") != nullptr) {
      host_.SetTooltip(Wide(StringField(arguments, "tooltip")));
    }
    if (const auto* icon = Field(arguments, "icon")) {
      host_.SetIcon(LoadTrayIcon(icon));
    }
    if (const auto* items = Field(arguments, "items")) {
      items_ = MenuFromValue(items);
    }
  }

  HWND MainWindow() const {
    flutter::FlutterView* view = registrar_->GetView();
    const HWND child = view ? view->GetNativeWindow() : nullptr;
    return child ? GetAncestor(child, GA_ROOT) : nullptr;
  }

  void ShowMainWindow() {
    const HWND window = MainWindow();
    if (window == nullptr) return;
    ActivateWindowForUser(window, window);
  }

  void Quit() {
    const HWND window = MainWindow();
    quitting_ = true;
    host_.Hide();
    if (window != nullptr) PostMessageW(window, WM_CLOSE, 0, 0);
  }

  // Closing the main window while the tray runs.
  std::optional<LRESULT> HandleTopLevelMessage(HWND window, UINT message,
                                               WPARAM, LPARAM) {
    if (message != WM_CLOSE || !started_ || quitting_) return std::nullopt;
    switch (close_behavior_) {
      case CloseBehavior::kHideToTray:
        if (host_.visible()) {
          ShowWindow(window, SW_HIDE);
          return 0;
        }
        // No icon to come back through: minimizing keeps the app reachable.
        ShowWindow(window, SW_MINIMIZE);
        return 0;
      case CloseBehavior::kMinimize:
        ShowWindow(window, SW_MINIMIZE);
        return 0;
      case CloseBehavior::kQuit:
        if (has_quit_handler_) {
          Emit({{flutter::EncodableValue("type"),
                 flutter::EncodableValue("quitRequested")}});
          return 0;
        }
        quitting_ = true;
        host_.Hide();
        return std::nullopt;
    }
    return std::nullopt;
  }

  void OnIcon(TrayHost::IconAction action, POINT anchor) {
    if (!started_) return;
    // Read before the menu or the main window takes the foreground.
    const HWND previous = host_.previous_foreground();
    if (action == TrayHost::IconAction::kMenu) {
      ShowMenu(anchor, previous);
      return;
    }
    switch (primary_click_) {
      case PrimaryClick::kOpenMainWindow:
        ShowMainWindow();
        EmitClicked(previous);
        break;
      case PrimaryClick::kMenu:
        ShowMenu(anchor, previous);
        break;
      case PrimaryClick::kEvent:
        EmitClicked(previous);
        break;
      case PrimaryClick::kItem:
        if (const MenuItem* item = FindAction(items_, primary_item_)) {
          Select(*item, previous);
        }
        break;
    }
  }

  void ShowMenu(POINT anchor, HWND previous) {
    // A copy: Dart can replace the items while the menu is open.
    const std::vector<MenuItem> items = items_;
    if (const MenuItem* chosen =
            ShowPopupMenu(host_.window(), items, anchor)) {
      Select(*chosen, previous);
    }
  }

  void Select(const MenuItem& item, HWND previous) {
    // Windows lets the app come to the front only during the user's click.
    if (item.shows_main_window) ShowMainWindow();
    Emit({{flutter::EncodableValue("type"), flutter::EncodableValue("selected")},
          {flutter::EncodableValue("id"), flutter::EncodableValue(item.id)},
          {flutter::EncodableValue("previousForeground"),
           WindowValue(previous)}});
  }

  void EmitClicked(HWND previous) {
    Emit({{flutter::EncodableValue("type"), flutter::EncodableValue("clicked")},
          {flutter::EncodableValue("previousForeground"),
           WindowValue(previous)}});
  }

  void OnSecondInstance(const std::vector<std::wstring>& arguments) {
    if (second_instance_shows_main_window_) ShowMainWindow();
    flutter::EncodableList list;
    for (const auto& argument : arguments) {
      list.emplace_back(Utf8(argument));
    }
    if (!started_) {
      pending_second_instances_.push_back(std::move(list));
      return;
    }
    EmitSecondInstance(std::move(list));
  }

  void FlushPendingSecondInstances() {
    auto pending = std::move(pending_second_instances_);
    pending_second_instances_.clear();
    for (auto& list : pending) EmitSecondInstance(std::move(list));
  }

  void EmitSecondInstance(flutter::EncodableList arguments) {
    Emit({{flutter::EncodableValue("type"),
           flutter::EncodableValue("secondInstance")},
          {flutter::EncodableValue("arguments"),
           flutter::EncodableValue(std::move(arguments))}});
  }

  static flutter::EncodableValue WindowValue(HWND window) {
    if (window == nullptr) return flutter::EncodableValue();
    return flutter::EncodableValue(
        static_cast<int64_t>(reinterpret_cast<intptr_t>(window)));
  }

  void Emit(flutter::EncodableMap event) {
    channel_->InvokeMethod(
        "event", std::make_unique<flutter::EncodableValue>(std::move(event)));
  }

  flutter::PluginRegistrarWindows* registrar_;
  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  TrayHost host_;
  int window_proc_id_ = -1;
  std::vector<MenuItem> items_;
  std::vector<flutter::EncodableList> pending_second_instances_;
  CloseBehavior close_behavior_ = CloseBehavior::kHideToTray;
  PrimaryClick primary_click_ = PrimaryClick::kOpenMainWindow;
  std::string primary_item_;
  bool second_instance_shows_main_window_ = true;
  bool has_quit_handler_ = false;
  bool started_ = false;
  bool quitting_ = false;
};

}  // namespace
}  // namespace shipglows_tray

void ShipglowsTrayPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows_registrar->AddPlugin(
      std::make_unique<shipglows_tray::ShipglowsTrayPlugin>(windows_registrar));
}
