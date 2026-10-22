#include "include/shipglows_tray/single_instance.h"

#include <shellapi.h>

#include <string>
#include <vector>

#include "single_instance_internal.h"

namespace shipglows_tray {
namespace {

std::wstring& AppId() {
  static std::wstring app_id;
  return app_id;
}

// Owned until the process exits; Windows releases it then, even after a
// crash.
HANDLE instance_mutex = nullptr;

constexpr int kForwardAttempts = 50;
constexpr DWORD kForwardRetryMs = 100;
constexpr UINT kForwardTimeoutMs = 2000;

// Arguments without the executable, each ended by a null character.
std::vector<wchar_t> CommandLineBlob() {
  std::vector<wchar_t> blob;
  int count = 0;
  LPWSTR* arguments = CommandLineToArgvW(GetCommandLineW(), &count);
  if (arguments == nullptr) return blob;
  for (int index = 1; index < count; ++index) {
    const std::wstring argument = arguments[index];
    blob.insert(blob.end(), argument.begin(), argument.end());
    blob.push_back(L'\0');
  }
  LocalFree(arguments);
  return blob;
}

}  // namespace

std::wstring HostWindowClass() {
  if (!AppId().empty()) return L"ShipGlowsTrayHost." + AppId();
  return L"ShipGlowsTrayHost.pid" + std::to_wstring(GetCurrentProcessId());
}

}  // namespace shipglows_tray

bool ShipglowsTrayForwardToPrimary(const wchar_t* app_id) {
  using namespace shipglows_tray;
  if (app_id == nullptr || *app_id == L'\0' || instance_mutex != nullptr) {
    return false;
  }
  AppId() = app_id;
  const std::wstring name = L"Local\\ShipGlows." + AppId() + L".instance";
  instance_mutex = CreateMutexW(nullptr, TRUE, name.c_str());
  // Without the mutex there is no way to tell: start normally.
  if (instance_mutex == nullptr) return false;
  if (GetLastError() != ERROR_ALREADY_EXISTS) return false;
  CloseHandle(instance_mutex);
  instance_mutex = nullptr;

  std::vector<wchar_t> blob = CommandLineBlob();
  COPYDATASTRUCT packet{};
  packet.dwData = kCommandLineCopyData;
  packet.cbData = static_cast<DWORD>(blob.size() * sizeof(wchar_t));
  packet.lpData = blob.empty() ? nullptr : blob.data();
  // The first instance may still be starting: its tray window appears once
  // its plugins are registered.
  for (int attempt = 0; attempt < kForwardAttempts; ++attempt) {
    const HWND target = FindWindowW(HostWindowClass().c_str(), nullptr);
    if (target != nullptr) {
      DWORD process = 0;
      GetWindowThreadProcessId(target, &process);
      // Lets the first instance bring its window to the front.
      AllowSetForegroundWindow(process);
      DWORD_PTR reply = 0;
      if (SendMessageTimeoutW(target, WM_COPYDATA, 0,
                              reinterpret_cast<LPARAM>(&packet),
                              SMTO_ABORTIFHUNG | SMTO_BLOCK, kForwardTimeoutMs,
                              &reply) != 0 &&
          reply == TRUE) {
        return true;
      }
    }
    Sleep(kForwardRetryMs);
  }
  return true;
}
