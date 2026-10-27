#ifndef SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_
#define SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_

#include <string>

namespace shipglows_tray {

// Argument the Run entry passes, so the app knows Windows launched it.
constexpr wchar_t kLaunchedAtStartupArgument[] = L"--launched-at-startup";

struct LaunchAtStartupState {
  // The Run entry of |name| launches this executable, or the managed dev
  // session of its project for a dev build.
  bool registered = false;
  // Not turned off in Task Manager (or Settings > Apps > Startup).
  bool approved = true;
};

// Whether this process was started by its Run entry.
bool LaunchedAtStartup();

// Also rewrites an entry of this executable whose command is stale, for
// example a dev build's own exe from before the dev session command.
LaunchAtStartupState ReadLaunchAtStartup(const std::wstring& name);

// Writes or removes the Run entry |name| of the current user: a dev build
// (<project>\build\windows\<arch>\runner\{Debug,Profile}) registers
// `shipglows-dev start -ProjectPath <project> -FlutterDevice windows`, any
// other copy its own executable. Enabling also
// clears a Task Manager « Désactivé », since the user asked again. False when
// the registry refused.
bool WriteLaunchAtStartup(const std::wstring& name, bool enabled);

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_LAUNCH_AT_STARTUP_H_
