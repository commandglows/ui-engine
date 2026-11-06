#include "include/shipglows_tray/single_instance.h"

#include <shellapi.h>

#include <string>
#include <utility>
#include <vector>

#include "single_instance_internal.h"

extern "C" IMAGE_DOS_HEADER __ImageBase;

namespace shipglows_tray {
namespace {

constexpr UINT kDeliverMessage = WM_APP + 0x5A2;
constexpr int kForwardAttempts = 50;
constexpr DWORD kForwardRetryMs = 100;
constexpr UINT kForwardTimeoutMs = 2000;

std::wstring& AppId() {
  static std::wstring app_id;
  return app_id;
}

// Owned until the process exits; Windows releases it then, even after a
// crash.
HANDLE instance_mutex = nullptr;

HWND receiver = nullptr;
const void* handler_owner = nullptr;
SecondInstanceHandler handler;
std::vector<std::vector<std::wstring>> pending;

HINSTANCE ModuleInstance() {
  return reinterpret_cast<HINSTANCE>(&__ImageBase);
}

// Class of the receiver, the one a later instance looks for: derived from
// the app id given to ShipglowsTrayForwardToPrimary, else unique to this
// process.
std::wstring ReceiverClass() {
  if (!AppId().empty()) return L"ShipGlowsTrayInstance." + AppId();
  return L"ShipGlowsTrayInstance.pid" + std::to_wstring(GetCurrentProcessId());
}

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

std::vector<std::wstring> ArgumentsFrom(const COPYDATASTRUCT& packet) {
  std::vector<std::wstring> arguments;
  if (packet.lpData == nullptr || packet.cbData < sizeof(wchar_t)) {
    return arguments;
  }
  const auto* text = static_cast<const wchar_t*>(packet.lpData);
  const size_t length = packet.cbData / sizeof(wchar_t);
  size_t start = 0;
  for (size_t index = 0; index < length; ++index) {
    if (text[index] != L'\0') continue;
    arguments.emplace_back(text + start, index - start);
    start = index + 1;
  }
  return arguments;
}

void Deliver() {
  if (!handler) return;
  auto command_lines = std::move(pending);
  pending.clear();
  // Copy: the handler may detach itself.
  const SecondInstanceHandler current = handler;
  for (const auto& arguments : command_lines) current(arguments);
}

LRESULT CALLBACK ReceiverProc(HWND window, UINT message, WPARAM wparam,
                              LPARAM lparam) {
  if (message == WM_COPYDATA) {
    const auto* packet = reinterpret_cast<const COPYDATASTRUCT*>(lparam);
    if (packet == nullptr || packet->dwData != kCommandLineCopyData) {
      return FALSE;
    }
    // Answer the sender at once; handle it outside its SendMessage.
    pending.push_back(ArgumentsFrom(*packet));
    PostMessageW(window, kDeliverMessage, 0, 0);
    return TRUE;
  }
  if (message == kDeliverMessage) {
    Deliver();
    return 0;
  }
  return DefWindowProcW(window, message, wparam, lparam);
}

}  // namespace

void EnsureInstanceReceiver() {
  if (receiver != nullptr) return;
  const std::wstring class_name = ReceiverClass();
  WNDCLASSEXW window_class{};
  window_class.cbSize = sizeof(window_class);
  window_class.lpfnWndProc = ReceiverProc;
  window_class.hInstance = ModuleInstance();
  window_class.lpszClassName = class_name.c_str();
  RegisterClassExW(&window_class);
  // Top level, not message-only, so that FindWindow finds it.
  receiver = CreateWindowExW(WS_EX_TOOLWINDOW, class_name.c_str(),
                             L"ShipGlows instance", WS_POPUP, 0, 0, 0, 0,
                             nullptr, nullptr, ModuleInstance(), nullptr);
}

void AttachSecondInstanceHandler(const void* owner,
                                 SecondInstanceHandler new_handler) {
  handler_owner = owner;
  handler = std::move(new_handler);
  if (!pending.empty() && receiver != nullptr) {
    PostMessageW(receiver, kDeliverMessage, 0, 0);
  }
}

void DetachSecondInstanceHandler(const void* owner) {
  if (handler_owner != owner) return;
  handler_owner = nullptr;
  handler = nullptr;
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
  // The first instance may still be starting: its receiver appears once its
  // plugins are registered.
  for (int attempt = 0; attempt < kForwardAttempts; ++attempt) {
    const HWND target = FindWindowW(ReceiverClass().c_str(), nullptr);
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
