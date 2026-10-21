#include "include/shipglows_overlay_window/shipglows_overlay_window_plugin_c_api.h"

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>
#include <utility>

#include "include/shipglows_overlay_window/overlay_window.h"

namespace shipglows_overlay {
namespace {

constexpr char kChannel[] = "shipglows_overlay_window";

using Registrant =
    std::function<void(const std::string& id, flutter::PluginRegistry*)>;

Registrant& PluginRegistrant() {
  static Registrant registrant;
  return registrant;
}

const flutter::EncodableValue* Field(const flutter::EncodableValue* value,
                                     const char* key) {
  const auto* map =
      value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

std::string StringField(const flutter::EncodableValue* value, const char* key) {
  const auto* field = Field(value, key);
  const auto* text = field ? std::get_if<std::string>(field) : nullptr;
  return text ? *text : std::string();
}

std::optional<int64_t> IntField(const flutter::EncodableValue* value,
                                const char* key) {
  const auto* field = Field(value, key);
  if (field == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(field)) return *v;
  if (const auto* v = std::get_if<int64_t>(field)) return *v;
  return std::nullopt;
}

void ReadBool(const flutter::EncodableValue* value, const char* key,
              bool* out) {
  const auto* field = Field(value, key);
  if (const auto* flag = field ? std::get_if<bool>(field) : nullptr) {
    *out = *flag;
  }
}

void ReadInt(const flutter::EncodableValue* value, const char* key, int* out) {
  if (const auto number = IntField(value, key)) {
    *out = static_cast<int>(*number);
  }
}

std::wstring Wide(const std::string& text) {
  if (text.empty()) return {};
  const int length = MultiByteToWideChar(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      wide.data(), length);
  return wide;
}

OverlayConfig ConfigFrom(const flutter::EncodableValue* arguments) {
  OverlayConfig config;
  config.id = StringField(arguments, "id");
  config.entrypoint = StringField(arguments, "entrypoint");
  const auto* options = Field(arguments, "options");
  config.title = Wide(StringField(options, "title"));
  config.app_folder = Wide(StringField(options, "appFolder"));
  ReadInt(options, "width", &config.width);
  ReadInt(options, "height", &config.height);
  ReadInt(options, "minWidth", &config.min_width);
  ReadInt(options, "minHeight", &config.min_height);
  ReadInt(options, "margin", &config.margin);
  ReadInt(options, "cornerRadius", &config.corner_radius);
  ReadBool(options, "alwaysOnTop", &config.always_on_top);
  ReadBool(options, "showInTaskbar", &config.show_in_taskbar);
  ReadBool(options, "hideOnDeactivate", &config.hide_on_deactivate);
  ReadBool(options, "excludeFromCapture", &config.exclude_from_capture);
  ReadBool(options, "resizable", &config.resizable);
  ReadBool(options, "doubleClickMaximizes", &config.double_click_maximizes);
  ReadBool(options, "rememberPosition", &config.remember_position);
  ReadBool(options, "darkFrame", &config.dark_frame);
  const std::string memory = StringField(options, "sizeMemory");
  if (memory == "none") config.size_memory = SizeMemory::kNone;
  if (memory == "session") config.size_memory = SizeMemory::kSession;
  if (memory == "persistent") config.size_memory = SizeMemory::kPersistent;
  const std::string placement = StringField(options, "placement");
  if (placement == "cursorMonitorCenter") {
    config.placement = Placement::kCursorMonitorCenter;
  } else if (placement == "cursorMonitorUpper") {
    config.placement = Placement::kCursorMonitorUpper;
  } else if (placement == "foregroundMonitorCenter") {
    config.placement = Placement::kForegroundMonitorCenter;
  }
  if (const auto argb = IntField(options, "borderColor")) {
    const auto value = static_cast<uint32_t>(*argb);
    config.border_color = RGB((value >> 16) & 0xFF, (value >> 8) & 0xFF,
                              value & 0xFF);
  }
  if (const auto argb = IntField(options, "backgroundColor")) {
    const auto value = static_cast<uint32_t>(*argb);
    config.background_color = RGB((value >> 16) & 0xFF, (value >> 8) & 0xFF,
                                  value & 0xFF);
  }
  return config;
}

// One instance per engine that registers the plugin. Overlays created from
// that engine's Dart code belong to it and report to it.
class ShipglowsOverlayWindowPlugin : public flutter::Plugin {
 public:
  explicit ShipglowsOverlayWindowPlugin(flutter::PluginRegistrarWindows* registrar)
      : channel_(std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
            registrar->messenger(), kChannel,
            &flutter::StandardMethodCodec::GetInstance())) {
    channel_->SetMethodCallHandler([this](const auto& call, auto result) {
      HandleMethodCall(call, std::move(result));
    });
  }

  ~ShipglowsOverlayWindowPlugin() override { overlays_.clear(); }

 private:
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    const auto* arguments = call.arguments();
    const std::string id = StringField(arguments, "id");
    const std::string& method = call.method_name();
    if (method == "create") {
      if (overlays_.count(id) != 0) {
        result->Success(flutter::EncodableValue(true));
        return;
      }
      OverlayConfig config = ConfigFrom(arguments);
      if (config.id.empty() || config.entrypoint.empty()) {
        result->Error("invalid_overlay", "An overlay needs an id and an entrypoint.");
        return;
      }
      config.register_plugins = [id](flutter::PluginRegistry* registry) {
        if (PluginRegistrant()) PluginRegistrant()(id, registry);
      };
      config.on_message = [this, id](const std::string& name,
                                     const flutter::EncodableValue& value) {
        Report("onMessage", id,
               {{flutter::EncodableValue("method"), flutter::EncodableValue(name)},
                {flutter::EncodableValue("arguments"), value}});
      };
      config.on_visibility = [this, id](bool visible) {
        Report("onVisibility", id,
               {{flutter::EncodableValue("visible"),
                 flutter::EncodableValue(visible)}});
      };
      auto overlay = ShipglowsOverlayWindowCreate(config);
      if (!overlay) {
        result->Error("duplicate_overlay", "Another overlay already uses this id.");
        return;
      }
      overlays_[id] = std::move(overlay);
      result->Success(flutter::EncodableValue(true));
      return;
    }
    const auto found = overlays_.find(id);
    if (found == overlays_.end()) {
      result->Error("unknown_overlay", "No overlay was created with this id.");
      return;
    }
    OverlayWindow* overlay = found->second.get();
    if (method == "prepare") {
      result->Success(flutter::EncodableValue(overlay->Prepare()));
      return;
    }
    if (method == "show") {
      const auto* data = Field(arguments, "data");
      bool activate = true;
      ReadBool(arguments, "activate", &activate);
      result->Success(flutter::EncodableValue(
          overlay->Show(data ? *data : flutter::EncodableValue(), activate)));
      return;
    }
    if (method == "hide") {
      overlay->Hide();
      result->Success();
      return;
    }
    if (method == "isVisible") {
      result->Success(flutter::EncodableValue(overlay->visible()));
      return;
    }
    if (method == "send") {
      const std::string name = StringField(arguments, "method");
      const auto* value = Field(arguments, "arguments");
      overlay->Send(name, value ? *value : flutter::EncodableValue());
      result->Success();
      return;
    }
    if (method == "destroy") {
      overlays_.erase(found);
      result->Success();
      return;
    }
    result->NotImplemented();
  }

  void Report(const char* method, const std::string& id,
              flutter::EncodableMap fields) {
    fields[flutter::EncodableValue("id")] = flutter::EncodableValue(id);
    channel_->InvokeMethod(method,
                           std::make_unique<flutter::EncodableValue>(std::move(fields)));
  }

  std::unique_ptr<flutter::MethodChannel<flutter::EncodableValue>> channel_;
  // Declared after the channel: overlays close before it goes away.
  std::map<std::string, std::unique_ptr<OverlayWindow>> overlays_;
};

}  // namespace
}  // namespace shipglows_overlay

void ShipglowsOverlayWindowPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  auto* windows_registrar =
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);
  windows_registrar->AddPlugin(
      std::make_unique<shipglows_overlay::ShipglowsOverlayWindowPlugin>(
          windows_registrar));
}

void ShipglowsOverlayWindowSetPluginRegistrant(
    std::function<void(const std::string& id, flutter::PluginRegistry* registry)>
        registrant) {
  shipglows_overlay::PluginRegistrant() = std::move(registrant);
}
