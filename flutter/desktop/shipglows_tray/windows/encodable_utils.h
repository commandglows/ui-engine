#ifndef SHIPGLOWS_TRAY_ENCODABLE_UTILS_H_
#define SHIPGLOWS_TRAY_ENCODABLE_UTILS_H_

#include <windows.h>

#include <flutter/encodable_value.h>

#include <optional>
#include <string>

namespace shipglows_tray {

inline const flutter::EncodableValue* Field(
    const flutter::EncodableValue* value, const char* key) {
  const auto* map =
      value ? std::get_if<flutter::EncodableMap>(value) : nullptr;
  if (map == nullptr) return nullptr;
  const auto found = map->find(flutter::EncodableValue(key));
  return found == map->end() ? nullptr : &found->second;
}

inline std::string StringField(const flutter::EncodableValue* value,
                               const char* key) {
  const auto* field = Field(value, key);
  const auto* text = field ? std::get_if<std::string>(field) : nullptr;
  return text ? *text : std::string();
}

inline bool BoolField(const flutter::EncodableValue* value, const char* key,
                      bool fallback) {
  const auto* field = Field(value, key);
  const auto* flag = field ? std::get_if<bool>(field) : nullptr;
  return flag ? *flag : fallback;
}

inline std::optional<int64_t> IntField(const flutter::EncodableValue* value,
                                       const char* key) {
  const auto* field = Field(value, key);
  if (field == nullptr) return std::nullopt;
  if (const auto* v = std::get_if<int32_t>(field)) return *v;
  if (const auto* v = std::get_if<int64_t>(field)) return *v;
  return std::nullopt;
}

inline std::wstring Wide(const std::string& text) {
  if (text.empty()) return {};
  const int length = MultiByteToWideChar(
      CP_UTF8, 0, text.data(), static_cast<int>(text.size()), nullptr, 0);
  std::wstring wide(static_cast<size_t>(length), L'\0');
  MultiByteToWideChar(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      wide.data(), length);
  return wide;
}

inline std::string Utf8(const std::wstring& text) {
  if (text.empty()) return {};
  const int length =
      WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                          nullptr, 0, nullptr, nullptr);
  std::string narrow(static_cast<size_t>(length), '\0');
  WideCharToMultiByte(CP_UTF8, 0, text.data(), static_cast<int>(text.size()),
                      narrow.data(), length, nullptr, nullptr);
  return narrow;
}

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_ENCODABLE_UTILS_H_
