#ifndef SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_
#define SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_

#include <windows.h>

#include <optional>
#include <string>

namespace shipglows_overlay {

// What is remembered about one overlay. The position is in physical screen
// pixels; the size in logical pixels, so it survives a DPI change.
struct StoredBounds {
  std::optional<POINT> position;
  std::optional<SIZE> size;
};

// Bounds of every overlay of an app, in
// %APPDATA%\<app_folder>\overlay_windows.json. Unreadable content counts as
// nothing saved; writes replace the file atomically.
StoredBounds LoadStoredBounds(const std::wstring& app_folder,
                              const std::string& id);
bool SaveStoredBounds(const std::wstring& app_folder, const std::string& id,
                      const StoredBounds& bounds);

}  // namespace shipglows_overlay

#endif  // SHIPGLOWS_OVERLAY_WINDOW_OVERLAY_STORE_H_
