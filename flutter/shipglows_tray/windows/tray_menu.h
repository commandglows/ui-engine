#ifndef SHIPGLOWS_TRAY_TRAY_MENU_H_
#define SHIPGLOWS_TRAY_TRAY_MENU_H_

#include <windows.h>

#include <flutter/encodable_value.h>

#include <string>
#include <vector>

namespace shipglows_tray {

struct MenuItem {
  enum class Type { kAction, kSeparator, kHeader, kSubmenu };

  Type type = Type::kAction;
  std::string id;
  std::wstring label;
  std::wstring shortcut;
  // Segoe Fluent Icons / Segoe MDL2 Assets code point; 0 for none.
  int glyph = 0;
  bool enabled = true;
  bool checked = false;
  bool shows_main_window = false;
  bool is_default = false;
  std::vector<MenuItem> children;
};

// Items from the list Dart sends (ShipglowsTrayItem.toMap).
std::vector<MenuItem> MenuFromValue(const flutter::EncodableValue* value);

// The enabled action |id|, searched in submenus too; nullptr if none.
const MenuItem* FindAction(const std::vector<MenuItem>& items,
                           const std::string& id);

// Shows |items| at |anchor| (screen coordinates) in the light or dark theme
// of Windows apps, and blocks until the menu closes. |owner| becomes the
// foreground window so that a click elsewhere closes the menu; use a hidden
// window to leave the app's windows where they are. Returns the chosen
// action, or nullptr.
const MenuItem* ShowPopupMenu(HWND owner, const std::vector<MenuItem>& items,
                              POINT anchor);

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_TRAY_MENU_H_
