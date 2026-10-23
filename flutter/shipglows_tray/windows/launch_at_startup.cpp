#include "launch_at_startup.h"

#include <windows.h>
#include <shellapi.h>

#include <utility>
#include <vector>

namespace shipglows_tray {
namespace {

constexpr wchar_t kRunKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Run";
// Task Manager's on/off switch: a binary value whose first byte is odd when
// the entry is turned off. A missing value means on.
constexpr wchar_t kApprovedKey[] =
    L"Software\\Microsoft\\Windows\\CurrentVersion\\Explorer\\StartupApproved"
    L"\\Run";

std::wstring ExecutablePath() {
  std::wstring path(MAX_PATH, L'\0');
  for (;;) {
    const DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                            static_cast<DWORD>(path.size()));
    if (length < path.size()) {
      path.resize(length);
      return path;
    }
    path.resize(path.size() * 2);
  }
}

std::wstring Command() {
  return L"\"" + ExecutablePath() + L"\" " + kLaunchedAtStartupArgument;
}

// The executable a Run command launches (its first argument).
std::wstring CommandExecutable(const std::wstring& command) {
  int count = 0;
  LPWSTR* arguments = CommandLineToArgvW(command.c_str(), &count);
  if (arguments == nullptr) return {};
  std::wstring executable = count > 0 ? arguments[0] : L"";
  LocalFree(arguments);
  return executable;
}

bool ReadString(const wchar_t* key, const std::wstring& name,
                std::wstring* value) {
  DWORD size = 0;
  if (RegGetValueW(HKEY_CURRENT_USER, key, name.c_str(), RRF_RT_REG_SZ,
                   nullptr, nullptr, &size) != ERROR_SUCCESS) {
    return false;
  }
  std::wstring text(size / sizeof(wchar_t), L'\0');
  if (RegGetValueW(HKEY_CURRENT_USER, key, name.c_str(), RRF_RT_REG_SZ,
                   nullptr, text.data(), &size) != ERROR_SUCCESS) {
    return false;
  }
  text.resize(wcsnlen(text.c_str(), text.size()));
  *value = std::move(text);
  return true;
}

bool DeleteValue(const wchar_t* key, const std::wstring& name) {
  const LSTATUS status =
      RegDeleteKeyValueW(HKEY_CURRENT_USER, key, name.c_str());
  return status == ERROR_SUCCESS || status == ERROR_FILE_NOT_FOUND;
}

}  // namespace

bool LaunchedAtStartup() {
  int count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &count);
  if (arguments == nullptr) return false;
  bool found = false;
  for (int index = 1; index < count && !found; ++index) {
    found = _wcsicmp(arguments[index], kLaunchedAtStartupArgument) == 0;
  }
  LocalFree(arguments);
  return found;
}

LaunchAtStartupState ReadLaunchAtStartup(const std::wstring& name) {
  LaunchAtStartupState state;
  if (name.empty()) return state;
  std::wstring command;
  // Another copy of the app (a dev build, an older install) does not count.
  state.registered =
      ReadString(kRunKey, name, &command) &&
      _wcsicmp(CommandExecutable(command).c_str(), ExecutablePath().c_str()) ==
          0;
  BYTE approval[12] = {};
  DWORD size = sizeof(approval);
  if (RegGetValueW(HKEY_CURRENT_USER, kApprovedKey, name.c_str(),
                   RRF_RT_REG_BINARY, nullptr, approval,
                   &size) == ERROR_SUCCESS &&
      size > 0) {
    state.approved = (approval[0] & 1) == 0;
  }
  return state;
}

bool WriteLaunchAtStartup(const std::wstring& name, bool enabled) {
  if (name.empty()) return false;
  if (!enabled) {
    return DeleteValue(kRunKey, name) && DeleteValue(kApprovedKey, name);
  }
  const std::wstring command = Command();
  if (RegSetKeyValueW(HKEY_CURRENT_USER, kRunKey, name.c_str(), REG_SZ,
                      command.c_str(),
                      static_cast<DWORD>((command.size() + 1) *
                                         sizeof(wchar_t))) != ERROR_SUCCESS) {
    return false;
  }
  return DeleteValue(kApprovedKey, name);
}

}  // namespace shipglows_tray
