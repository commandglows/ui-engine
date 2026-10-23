#ifndef SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_
#define SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_

#include <string>

namespace shipglows_tray {

// Argument the Run entry passes, so the app knows Windows launched it.
constexpr wchar_t kLaunchedAtStartupArgument[] = L"--launched-at-startup";

struct LaunchAtStartupState {
  // The Run entry of |name| launches this executable.
  bool registered = false;
  // Not turned off in Task Manager (or Settings > Apps > Startup).
  bool approved = true;
};

// Whether this process was started by its Run entry.
bool LaunchedAtStartup();

LaunchAtStartupState ReadLaunchAtStartup(const std::wstring& name);

// Writes or removes the Run entry |name| of the current user. Enabling also
// clears a Task Manager « Désactivé », since the user asked again. False when
// the registry refused.
bool WriteLaunchAtStartup(const std::wstring& name, bool enabled);

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_
