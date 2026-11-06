#include "launch_at_startup.h"

#include <windows.h>
#include <shellapi.h>

#include <filesystem>
#include <system_error>
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

bool NameIs(const std::filesystem::path& path, const wchar_t* name) {
  return _wcsicmp(path.filename().c_str(), name) == 0;
}

// The Flutter project of a dev build, run from
// <project>\build\windows\<arch>\runner\{Debug,Profile}\<app>.exe. Empty for
// an installed or release copy.
std::wstring DevProjectPath() {
  const std::filesystem::path configuration =
      std::filesystem::path(ExecutablePath()).parent_path();
  const std::filesystem::path runner = configuration.parent_path();
  const std::filesystem::path build =
      runner.parent_path().parent_path().parent_path();
  if ((!NameIs(configuration, L"Debug") &&
       !NameIs(configuration, L"Profile")) ||
      !NameIs(runner, L"runner") || !NameIs(build, L"build")) {
    return {};
  }
  const std::filesystem::path project = build.parent_path();
  std::error_code error;
  if (!std::filesystem::is_regular_file(project / L"pubspec.yaml", error)) {
    return {};
  }
  return project.wstring();
}

// The ShipGlows dev server CLI (shipglows-dev, alias s): its installed copy,
// else the one on PATH. Empty when missing.
std::wstring DevServerCli() {
  constexpr wchar_t kCli[] = L"shipglows-dev.exe";
  std::wstring home(MAX_PATH, L'\0');
  const DWORD length = GetEnvironmentVariableW(
      L"USERPROFILE", home.data(), static_cast<DWORD>(home.size()));
  if (length > 0 && length < home.size()) {
    home.resize(length);
    const std::filesystem::path installed =
        std::filesystem::path(home) / L".shipglows" / L"runtime" / L"bin" /
        kCli;
    std::error_code error;
    if (std::filesystem::is_regular_file(installed, error)) {
      return installed.wstring();
    }
  }
  std::wstring found(MAX_PATH, L'\0');
  const DWORD size = SearchPathW(nullptr, kCli, nullptr,
                                 static_cast<DWORD>(found.size()),
                                 found.data(), nullptr);
  if (size == 0 || size >= found.size()) return {};
  found.resize(size);
  return found;
}

// A dev build's exe only holds its last full compile (hot reloads live in
// the `flutter run` session), so sign-in starts the managed dev session
// instead, which compiles the current sources. Elsewhere, this executable.
std::wstring Command() {
  const std::wstring project = DevProjectPath();
  const std::wstring cli = project.empty() ? L"" : DevServerCli();
  if (!cli.empty()) {
    return L"\"" + cli + L"\" start -ProjectPath \"" + project +
           L"\" -FlutterDevice windows";
  }
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

bool WriteString(const wchar_t* key, const std::wstring& name,
                 const std::wstring& value) {
  return RegSetKeyValueW(HKEY_CURRENT_USER, key, name.c_str(), REG_SZ,
                         value.c_str(),
                         static_cast<DWORD>((value.size() + 1) *
                                            sizeof(wchar_t))) == ERROR_SUCCESS;
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
  if (!ReadString(kRunKey, name, &command)) return state;
  const std::wstring current = Command();
  // Another copy of the app (another checkout, an older install) does not
  // count.
  state.registered =
      _wcsicmp(command.c_str(), current.c_str()) == 0 ||
      _wcsicmp(CommandExecutable(command).c_str(), ExecutablePath().c_str()) ==
          0;
  // An entry of this executable written before (a dev build's own exe, other
  // arguments) now runs the current command; Task Manager's switch stays.
  if (state.registered && _wcsicmp(command.c_str(), current.c_str()) != 0) {
    WriteString(kRunKey, name, current);
  }
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
  return WriteString(kRunKey, name, Command()) &&
         DeleteValue(kApprovedKey, name);
}

}  // namespace shipglows_tray
