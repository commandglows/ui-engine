#include "tray_menu.h"

#include <ShellScalingApi.h>

#include <cstring>
#include <memory>

#include "encodable_utils.h"

namespace shipglows_tray {
namespace {

DWORD WindowsBuild() {
  using RtlGetVersionFn = LONG(WINAPI*)(OSVERSIONINFOW*);
  static const DWORD build = [] {
    const auto get_version = reinterpret_cast<RtlGetVersionFn>(
        GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "RtlGetVersion"));
    OSVERSIONINFOW info{};
    info.dwOSVersionInfoSize = sizeof(info);
    return get_version && get_version(&info) == 0 ? info.dwBuildNumber : 0UL;
  }();
  return build;
}

bool AppsUseDarkTheme() {
  DWORD light = 1;
  DWORD size = sizeof(light);
  return RegGetValueW(
             HKEY_CURRENT_USER,
             L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
             L"AppsUseLightTheme", RRF_RT_REG_DWORD, nullptr, &light,
             &size) == ERROR_SUCCESS &&
         light == 0;
}

// Popup menus only follow the dark theme through two undocumented uxtheme
// exports (ordinals 135 and 136, Windows 10 1903 and later), the ones
// Windows Terminal and Notepad++ use. Elsewhere menus stay light.
void ApplyMenuTheme(bool dark) {
  enum PreferredAppMode { kDefault, kAllowDark, kForceDark, kForceLight };
  using SetPreferredAppModeFn = PreferredAppMode(WINAPI*)(PreferredAppMode);
  using FlushMenuThemesFn = void(WINAPI*)();
  static SetPreferredAppModeFn set_mode = nullptr;
  static FlushMenuThemesFn flush = nullptr;
  static const bool loaded = [] {
    if (WindowsBuild() < 18362) return false;
    HMODULE uxtheme = LoadLibraryExW(L"uxtheme.dll", nullptr,
                                     LOAD_LIBRARY_SEARCH_SYSTEM32);
    if (uxtheme == nullptr) return false;
    set_mode = reinterpret_cast<SetPreferredAppModeFn>(
        GetProcAddress(uxtheme, MAKEINTRESOURCEA(135)));
    flush = reinterpret_cast<FlushMenuThemesFn>(
        GetProcAddress(uxtheme, MAKEINTRESOURCEA(136)));
    return set_mode != nullptr && flush != nullptr;
  }();
  if (!loaded) return;
  set_mode(dark ? kForceDark : kForceLight);
  flush();
}

const wchar_t* GlyphFontFace() {
  // Segoe Fluent Icons ships with Windows 11 (build 22000).
  return WindowsBuild() >= 22000 ? L"Segoe Fluent Icons" : L"Segoe MDL2 Assets";
}

UINT DpiAt(POINT point) {
  UINT dpi_x = 96;
  UINT dpi_y = 96;
  const HMONITOR monitor = MonitorFromPoint(point, MONITOR_DEFAULTTONEAREST);
  if (FAILED(GetDpiForMonitor(monitor, MDT_EFFECTIVE_DPI, &dpi_x, &dpi_y))) {
    return 96;
  }
  return dpi_x;
}

// |code_point| drawn in |color| on a transparent, premultiplied 32-bit
// bitmap, as menus expect for MIIM_BITMAP.
HBITMAP GlyphBitmap(int code_point, int size, COLORREF color) {
  BITMAPINFO info{};
  info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
  info.bmiHeader.biWidth = size;
  info.bmiHeader.biHeight = -size;  // Top-down.
  info.bmiHeader.biPlanes = 1;
  info.bmiHeader.biBitCount = 32;
  info.bmiHeader.biCompression = BI_RGB;
  void* bits = nullptr;
  HBITMAP bitmap =
      CreateDIBSection(nullptr, &info, DIB_RGB_COLORS, &bits, nullptr, 0);
  if (bitmap == nullptr) return nullptr;
  HDC dc = CreateCompatibleDC(nullptr);
  HGDIOBJ old_bitmap = SelectObject(dc, bitmap);
  // Grayscale antialiasing: white on black gives the coverage in each
  // channel, which becomes the alpha.
  HFONT font = CreateFontW(-size, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
                           DEFAULT_CHARSET, OUT_DEFAULT_PRECIS,
                           CLIP_DEFAULT_PRECIS, ANTIALIASED_QUALITY,
                           DEFAULT_PITCH, GlyphFontFace());
  HGDIOBJ old_font = SelectObject(dc, font);
  std::memset(bits, 0, static_cast<size_t>(size) * size * 4);
  SetBkMode(dc, TRANSPARENT);
  SetTextColor(dc, RGB(255, 255, 255));
  const wchar_t text[2] = {static_cast<wchar_t>(code_point), L'\0'};
  RECT rect{0, 0, size, size};
  DrawTextW(dc, text, 1, &rect,
            DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_NOPREFIX);
  GdiFlush();
  auto* pixels = static_cast<uint32_t*>(bits);
  for (int index = 0; index < size * size; ++index) {
    const uint32_t alpha = (pixels[index] >> 8) & 0xFF;
    const uint32_t red = GetRValue(color) * alpha / 255;
    const uint32_t green = GetGValue(color) * alpha / 255;
    const uint32_t blue = GetBValue(color) * alpha / 255;
    pixels[index] = (alpha << 24) | (red << 16) | (green << 8) | blue;
  }
  SelectObject(dc, old_font);
  DeleteObject(font);
  SelectObject(dc, old_bitmap);
  DeleteDC(dc);
  return bitmap;
}

// Menus treat & as a mnemonic marker; labels are plain text.
std::wstring EscapeMnemonics(const std::wstring& label) {
  std::wstring escaped;
  escaped.reserve(label.size());
  for (const wchar_t character : label) {
    if (character == L'&') escaped.push_back(L'&');
    escaped.push_back(character);
  }
  return escaped;
}

class MenuBuilder {
 public:
  MenuBuilder(int glyph_size, COLORREF glyph_color)
      : glyph_size_(glyph_size), glyph_color_(glyph_color) {}

  ~MenuBuilder() {
    for (HBITMAP bitmap : bitmaps_) DeleteObject(bitmap);
  }

  HMENU Build(const std::vector<MenuItem>& items) {
    HMENU menu = CreatePopupMenu();
    if (menu == nullptr) return nullptr;
    // One column for both: a check mark replaces the glyph.
    MENUINFO info{};
    info.cbSize = sizeof(info);
    info.fMask = MIM_STYLE;
    info.dwStyle = MNS_CHECKORBMP;
    SetMenuInfo(menu, &info);
    for (const MenuItem& item : items) Append(menu, item);
    return menu;
  }

  const MenuItem* Chosen(UINT command) const {
    return command > 0 && command <= actions_.size() ? actions_[command - 1]
                                                     : nullptr;
  }

 private:
  void Append(HMENU menu, const MenuItem& item) {
    if (item.type == MenuItem::Type::kSeparator) {
      AppendMenuW(menu, MF_SEPARATOR, 0, nullptr);
      return;
    }
    std::wstring text = EscapeMnemonics(item.label);
    if (!item.shortcut.empty()) text += L"\t" + item.shortcut;

    MENUITEMINFOW info{};
    info.cbSize = sizeof(info);
    info.fMask = MIIM_STRING | MIIM_STATE | MIIM_FTYPE;
    info.fType = MFT_STRING;
    info.dwTypeData = text.data();
    const bool enabled =
        item.type != MenuItem::Type::kHeader && item.enabled;
    info.fState = (enabled ? MFS_ENABLED : MFS_DISABLED) |
                  (item.checked ? MFS_CHECKED : MFS_UNCHECKED) |
                  (item.is_default ? MFS_DEFAULT : 0);
    if (item.glyph != 0 && !item.checked) {
      if (HBITMAP bitmap = GlyphBitmap(item.glyph, glyph_size_, glyph_color_)) {
        bitmaps_.push_back(bitmap);
        info.fMask |= MIIM_BITMAP;
        info.hbmpItem = bitmap;
      }
    }
    if (item.type == MenuItem::Type::kSubmenu) {
      info.fMask |= MIIM_SUBMENU;
      info.hSubMenu = Build(item.children);
    } else if (item.type == MenuItem::Type::kAction) {
      actions_.push_back(&item);
      info.fMask |= MIIM_ID;
      info.wID = static_cast<UINT>(actions_.size());
    }
    InsertMenuItemW(menu, GetMenuItemCount(menu), TRUE, &info);
  }

  int glyph_size_;
  COLORREF glyph_color_;
  std::vector<HBITMAP> bitmaps_;
  std::vector<const MenuItem*> actions_;
};

MenuItem ItemFromValue(const flutter::EncodableValue& value) {
  MenuItem item;
  const std::string type = StringField(&value, "type");
  if (type == "separator") item.type = MenuItem::Type::kSeparator;
  if (type == "header") item.type = MenuItem::Type::kHeader;
  if (type == "submenu") item.type = MenuItem::Type::kSubmenu;
  item.id = StringField(&value, "id");
  item.label = Wide(StringField(&value, "label"));
  item.shortcut = Wide(StringField(&value, "shortcut"));
  if (const auto glyph = IntField(&value, "glyph")) {
    item.glyph = static_cast<int>(*glyph);
  }
  item.enabled = BoolField(&value, "enabled", true);
  item.checked = BoolField(&value, "checked", false);
  item.shows_main_window = BoolField(&value, "showsMainWindow", false);
  item.is_default = BoolField(&value, "isDefault", false);
  item.children = MenuFromValue(Field(&value, "items"));
  return item;
}

}  // namespace

std::vector<MenuItem> MenuFromValue(const flutter::EncodableValue* value) {
  std::vector<MenuItem> items;
  const auto* list =
      value ? std::get_if<flutter::EncodableList>(value) : nullptr;
  if (list == nullptr) return items;
  for (const auto& entry : *list) items.push_back(ItemFromValue(entry));
  return items;
}

const MenuItem* FindAction(const std::vector<MenuItem>& items,
                           const std::string& id) {
  for (const MenuItem& item : items) {
    if (item.type == MenuItem::Type::kAction && item.enabled && item.id == id) {
      return &item;
    }
    if (item.type == MenuItem::Type::kSubmenu) {
      if (const MenuItem* found = FindAction(item.children, id)) return found;
    }
  }
  return nullptr;
}

const MenuItem* ShowPopupMenu(HWND owner, const std::vector<MenuItem>& items,
                              POINT anchor) {
  if (items.empty()) return nullptr;
  const bool dark = AppsUseDarkTheme();
  ApplyMenuTheme(dark);
  const int glyph_size =
      GetSystemMetricsForDpi(SM_CXSMICON, DpiAt(anchor));
  MenuBuilder builder(glyph_size,
                      dark ? RGB(0xFF, 0xFF, 0xFF) : RGB(0x1A, 0x1A, 0x1A));
  HMENU menu = builder.Build(items);
  if (menu == nullptr) return nullptr;

  // Without this a click outside does not close the menu (KB135788).
  SetForegroundWindow(owner);
  const UINT alignment = GetSystemMetrics(SM_MENUDROPALIGNMENT) != 0
                             ? TPM_RIGHTALIGN
                             : TPM_LEFTALIGN;
  const UINT command = static_cast<UINT>(TrackPopupMenuEx(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | alignment,
      anchor.x, anchor.y, owner, nullptr));
  PostMessageW(owner, WM_NULL, 0, 0);
  DestroyMenu(menu);
  return builder.Chosen(command);
}

}  // namespace shipglows_tray
