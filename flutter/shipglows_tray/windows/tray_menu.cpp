#include "tray_menu.h"

#include <CommCtrl.h>
#include <ShellScalingApi.h>
#include <UIAutomation.h>
#include <oleacc.h>

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

// The standard MSAA object of a menu window, passed through unchanged.
// UiaProviderFromIAccessible refuses oleacc's own objects; this wrapper is
// what lets UI Automation bridge them.
class MenuAccessible : public IAccessible {
 public:
  explicit MenuAccessible(IAccessible* inner) : inner_(inner) {}

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID iid, void** object) override {
    if (object == nullptr) return E_POINTER;
    if (iid == IID_IUnknown || iid == IID_IDispatch || iid == IID_IAccessible) {
      *object = static_cast<IAccessible*>(this);
      AddRef();
      return S_OK;
    }
    *object = nullptr;
    return E_NOINTERFACE;
  }
  STDMETHODIMP_(ULONG) AddRef() override {
    return InterlockedIncrement(&references_);
  }
  STDMETHODIMP_(ULONG) Release() override {
    const ULONG remaining = InterlockedDecrement(&references_);
    if (remaining == 0) delete this;
    return remaining;
  }

  // IDispatch
  STDMETHODIMP GetTypeInfoCount(UINT* count) override {
    return inner_->GetTypeInfoCount(count);
  }
  STDMETHODIMP GetTypeInfo(UINT index, LCID lcid, ITypeInfo** info) override {
    return inner_->GetTypeInfo(index, lcid, info);
  }
  STDMETHODIMP GetIDsOfNames(REFIID iid, LPOLESTR* names, UINT count,
                             LCID lcid, DISPID* ids) override {
    return inner_->GetIDsOfNames(iid, names, count, lcid, ids);
  }
  STDMETHODIMP Invoke(DISPID id, REFIID iid, LCID lcid, WORD flags,
                      DISPPARAMS* params, VARIANT* result, EXCEPINFO* error,
                      UINT* argument) override {
    return inner_->Invoke(id, iid, lcid, flags, params, result, error,
                          argument);
  }

  // IAccessible
  STDMETHODIMP get_accParent(IDispatch** parent) override {
    return inner_->get_accParent(parent);
  }
  STDMETHODIMP get_accChildCount(long* count) override {
    return inner_->get_accChildCount(count);
  }
  STDMETHODIMP get_accChild(VARIANT child, IDispatch** dispatch) override {
    return inner_->get_accChild(child, dispatch);
  }
  STDMETHODIMP get_accName(VARIANT child, BSTR* name) override {
    return inner_->get_accName(child, name);
  }
  STDMETHODIMP get_accValue(VARIANT child, BSTR* value) override {
    return inner_->get_accValue(child, value);
  }
  STDMETHODIMP get_accDescription(VARIANT child, BSTR* description) override {
    return inner_->get_accDescription(child, description);
  }
  STDMETHODIMP get_accRole(VARIANT child, VARIANT* role) override {
    return inner_->get_accRole(child, role);
  }
  STDMETHODIMP get_accState(VARIANT child, VARIANT* state) override {
    return inner_->get_accState(child, state);
  }
  STDMETHODIMP get_accHelp(VARIANT child, BSTR* help) override {
    return inner_->get_accHelp(child, help);
  }
  STDMETHODIMP get_accHelpTopic(BSTR* file, VARIANT child,
                                long* topic) override {
    return inner_->get_accHelpTopic(file, child, topic);
  }
  STDMETHODIMP get_accKeyboardShortcut(VARIANT child, BSTR* shortcut) override {
    return inner_->get_accKeyboardShortcut(child, shortcut);
  }
  STDMETHODIMP get_accFocus(VARIANT* child) override {
    return inner_->get_accFocus(child);
  }
  STDMETHODIMP get_accSelection(VARIANT* children) override {
    return inner_->get_accSelection(children);
  }
  STDMETHODIMP get_accDefaultAction(VARIANT child, BSTR* action) override {
    return inner_->get_accDefaultAction(child, action);
  }
  STDMETHODIMP accSelect(long flags, VARIANT child) override {
    return inner_->accSelect(flags, child);
  }
  STDMETHODIMP accLocation(long* left, long* top, long* width, long* height,
                           VARIANT child) override {
    return inner_->accLocation(left, top, width, height, child);
  }
  STDMETHODIMP accNavigate(long direction, VARIANT start,
                           VARIANT* end) override {
    return inner_->accNavigate(direction, start, end);
  }
  STDMETHODIMP accHitTest(long x, long y, VARIANT* child) override {
    return inner_->accHitTest(x, y, child);
  }
  STDMETHODIMP accDoDefaultAction(VARIANT child) override {
    return inner_->accDoDefaultAction(child);
  }
  STDMETHODIMP put_accName(VARIANT child, BSTR name) override {
    return inner_->put_accName(child, name);
  }
  STDMETHODIMP put_accValue(VARIANT child, BSTR value) override {
    return inner_->put_accValue(child, value);
  }

 private:
  ~MenuAccessible() { inner_->Release(); }

  IAccessible* inner_;
  LONG references_ = 1;
};

// Popup menu windows (#32768) leave WM_GETOBJECT unanswered, and UI
// Automation's own menu proxy then sees an empty pane: Narrator and test
// tools find no items, although MSAA lists them. Answering UI Automation
// with that MSAA object, bridged, gives each item its text (shortcut
// included), state and the separators.
constexpr UINT_PTR kMenuAccessibilitySubclass = 1;

LRESULT CALLBACK MenuWindowProc(HWND window, UINT message, WPARAM wparam,
                                LPARAM lparam, UINT_PTR, DWORD_PTR) {
  if (message == WM_GETOBJECT &&
      static_cast<DWORD>(lparam) == static_cast<DWORD>(UiaRootObjectId)) {
    IAccessible* standard = nullptr;
    if (SUCCEEDED(CreateStdAccessibleObject(
            window, OBJID_CLIENT, IID_IAccessible,
            reinterpret_cast<void**>(&standard)))) {
      auto* accessible = new MenuAccessible(standard);
      IRawElementProviderSimple* provider = nullptr;
      const HRESULT bridged = UiaProviderFromIAccessible(
          accessible, CHILDID_SELF, UIA_PFIA_DEFAULT, &provider);
      accessible->Release();
      if (SUCCEEDED(bridged)) {
        const LRESULT result =
            UiaReturnRawElementProvider(window, wparam, lparam, provider);
        provider->Release();
        return result;
      }
    }
  }
  if (message == WM_NCDESTROY) {
    RemoveWindowSubclass(window, MenuWindowProc, kMenuAccessibilitySubclass);
  }
  return DefSubclassProc(window, message, wparam, lparam);
}

// Subclasses each menu window, submenus included, as the menu loop creates
// it on this thread, before any client can query it.
LRESULT CALLBACK MenuCreationHook(int code, WPARAM wparam, LPARAM lparam) {
  if (code == HCBT_CREATEWND) {
    const HWND window = reinterpret_cast<HWND>(wparam);
    wchar_t class_name[8] = {};
    if (GetClassNameW(window, class_name, 8) > 0 &&
        std::wcscmp(class_name, L"#32768") == 0) {
      SetWindowSubclass(window, MenuWindowProc, kMenuAccessibilitySubclass, 0);
    }
  }
  return CallNextHookEx(nullptr, code, wparam, lparam);
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
  HHOOK hook = SetWindowsHookExW(WH_CBT, MenuCreationHook, nullptr,
                                 GetCurrentThreadId());
  const UINT command = static_cast<UINT>(TrackPopupMenuEx(
      menu, TPM_RETURNCMD | TPM_NONOTIFY | TPM_RIGHTBUTTON | alignment,
      anchor.x, anchor.y, owner, nullptr));
  if (hook != nullptr) UnhookWindowsHookEx(hook);
  PostMessageW(owner, WM_NULL, 0, 0);
  DestroyMenu(menu);
  return builder.Chosen(command);
}

}  // namespace shipglows_tray
