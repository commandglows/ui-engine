#ifndef SHIPGLOWS_TRAY_WINDOW_ACTIVATION_H_
#define SHIPGLOWS_TRAY_WINDOW_ACTIVATION_H_

#include <windows.h>

namespace shipglows_tray {

// Shows |window| and gives it the keyboard, focusing |focus| (the window or
// one of its children). Use only from an explicit user action, on the
// window's UI thread: Windows can still refuse activation, for example while
// another app owns a menu. Never raises any other window.
inline bool ActivateWindowForUser(HWND window, HWND focus) {
  if (!IsWindow(window) ||
      GetWindowThreadProcessId(window, nullptr) != GetCurrentThreadId()) {
    return false;
  }
  if (IsIconic(window)) ShowWindow(window, SW_RESTORE);
  // SW_SHOWNA keeps a maximized overlay maximized.
  ShowWindow(window, SW_SHOWNA);
  SetForegroundWindow(window);

  if (GetForegroundWindow() != window) {
    const HWND foreground = GetForegroundWindow();
    const DWORD current_thread = GetCurrentThreadId();
    const DWORD foreground_thread =
        foreground ? GetWindowThreadProcessId(foreground, nullptr) : 0;
    // Attach only when needed, and never join an unresponsive app's input
    // queue.
    if (foreground_thread != 0 && foreground_thread != current_thread &&
        !IsHungAppWindow(foreground) &&
        AttachThreadInput(current_thread, foreground_thread, TRUE)) {
      SetForegroundWindow(window);
      AttachThreadInput(current_thread, foreground_thread, FALSE);
    }
  }

  const bool activated = GetForegroundWindow() == window;
  if (activated) {
    BringWindowToTop(window);
    SetFocus(IsWindow(focus) && (focus == window || IsChild(window, focus))
                 ? focus
                 : window);
  }
  return activated;
}

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_WINDOW_ACTIVATION_H_
