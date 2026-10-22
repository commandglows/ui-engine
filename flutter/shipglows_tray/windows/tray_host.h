#ifndef SHIPGLOWS_TRAY_TRAY_HOST_H_
#define SHIPGLOWS_TRAY_TRAY_HOST_H_

#include <windows.h>

#include <functional>
#include <string>
#include <vector>

namespace shipglows_tray {

// The notification area icon and the hidden window receiving its messages,
// the taskbar's restarts and the command lines of later instances.
//
// The window is top level (not message-only), as only those receive the
// "TaskbarCreated" broadcast.
class TrayHost {
 public:
  enum class IconAction {
    // Click, or Enter / Space on the focused icon.
    kPrimary,
    // Right click, or Shift+F10 / the menu key.
    kMenu,
  };

  struct Callbacks {
    std::function<void(IconAction action, POINT anchor)> on_icon;
    std::function<void(const std::vector<std::wstring>& arguments)>
        on_second_instance;
    std::function<void(bool visible)> on_visibility;
  };

  explicit TrayHost(Callbacks callbacks);
  ~TrayHost();

  TrayHost(const TrayHost&) = delete;
  TrayHost& operator=(const TrayHost&) = delete;

  HWND window() const { return window_; }
  bool visible() const { return visible_; }

  // Takes ownership of |icon|.
  void SetIcon(HICON icon);
  void SetTooltip(const std::wstring& tooltip);

  // Adds the icon, or updates it when shown. Retries for a minute when the
  // taskbar is not ready yet (launch at sign-in) and re-adds it after every
  // taskbar restart until Hide.
  bool Show();
  void Hide();

  // Last top-level window in front, ignoring the taskbar, its overflow and
  // menus; can be one of the app's windows. nullptr if unknown or gone.
  HWND previous_foreground() const;

 private:
  static LRESULT CALLBACK WindowProc(HWND window, UINT message, WPARAM wparam,
                                     LPARAM lparam);
  static void CALLBACK ForegroundChanged(HWINEVENTHOOK hook, DWORD event,
                                         HWND window, LONG object,
                                         LONG child, DWORD thread,
                                         DWORD time);
  LRESULT HandleMessage(UINT message, WPARAM wparam, LPARAM lparam);
  void OnIconMessage(WPARAM wparam, LPARAM lparam);
  bool Add();
  void SetVisible(bool visible);
  bool IsCandidateForeground(HWND window) const;
  NOTIFYICONDATAW IconData(UINT flags) const;

  Callbacks callbacks_;
  std::wstring class_name_;
  HWND window_ = nullptr;
  UINT taskbar_created_message_ = 0;
  HICON icon_ = nullptr;
  std::wstring tooltip_;
  bool wanted_ = false;
  bool visible_ = false;
  bool version4_ = false;
  int add_attempts_ = 0;
  HWINEVENTHOOK foreground_hook_ = nullptr;
  HWND last_foreground_ = nullptr;
  std::vector<std::vector<std::wstring>> pending_command_lines_;
};

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_TRAY_HOST_H_
