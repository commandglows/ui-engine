#ifndef SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_
#define SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_

#include <windows.h>

#include <map>
#include <optional>
#include <string>

namespace shipglows_overlay {

// What is remembered about one overlay. The position is in physical screen
// pixels; the size in logical pixels, so it survives a DPI change.
struct StoredBounds {
  std::optional<POINT> position;
  std::optional<SIZE> size;
};

// The integer fields of one overlay's entry: its bounds, the sizes of its
// views ("<view>:width") and the values it keeps ("value:<key>").
using StoredFields = std::map<std::string, long long>;

StoredFields LoadStoredFields(const std::wstring& app_folder,
                              const std::string& id);
// Sets the fields given, removes those given without a value, and keeps the
// others. Names may not hold quotes, backslashes or control characters.
bool SaveStoredFields(
    const std::wstring& app_folder, const std::string& id,
    const std::map<std::string, std::optional<long long>>& changes);
// The size saved as "<prefix>width" and "<prefix>height", if valid.
std::optional<SIZE> StoredSize(const StoredFields& fields,
                               const std::string& prefix);

// Bounds of every overlay of an app, in
// %APPDATA%\<app_folder>\overlay_windows.json. Unreadable content counts as
// nothing saved; writes replace the file atomically.
StoredBounds LoadStoredBounds(const std::wstring& app_folder,
                              const std::string& id);
bool SaveStoredBounds(const std::wstring& app_folder, const std::string& id,
                      const StoredBounds& bounds);

}  // namespace shipglows_overlay

#endif  // SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_
