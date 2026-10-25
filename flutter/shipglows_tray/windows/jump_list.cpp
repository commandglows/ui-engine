#include "jump_list.h"

#include <shellapi.h>
#include <shobjidl.h>
#include <propkey.h>
#include <propvarutil.h>
#include <wrl/client.h>

#include <algorithm>

namespace shipglows_tray {
namespace {

using Microsoft::WRL::ComPtr;

constexpr DWORD kArgumentsCapacity = 4096;

std::wstring ExecutablePath() {
  std::wstring path(32768, L'\0');
  const DWORD length = GetModuleFileNameW(nullptr, path.data(),
                                          static_cast<DWORD>(path.size()));
  path.resize(length < path.size() ? length : 0);
  return path;
}

// Quoted as CommandLineToArgvW reads it back.
std::wstring QuoteArgument(const std::wstring& argument) {
  if (!argument.empty() &&
      argument.find_first_of(L" \t\n\v\"") == std::wstring::npos) {
    return argument;
  }
  std::wstring quoted = L"\"";
  for (auto it = argument.begin();; ++it) {
    size_t backslashes = 0;
    while (it != argument.end() && *it == L'\\') {
      ++it;
      ++backslashes;
    }
    if (it == argument.end()) {
      quoted.append(backslashes * 2, L'\\');
      break;
    }
    if (*it == L'"') {
      quoted.append(backslashes * 2 + 1, L'\\');
    } else {
      quoted.append(backslashes, L'\\');
    }
    quoted.push_back(*it);
  }
  quoted.push_back(L'"');
  return quoted;
}

std::wstring CommandLine(const std::vector<std::wstring>& arguments) {
  std::wstring line;
  for (const auto& argument : arguments) {
    if (!line.empty()) line.push_back(L' ');
    line += QuoteArgument(argument);
  }
  return line;
}

std::vector<std::wstring> SplitCommandLine(const std::wstring& line) {
  std::vector<std::wstring> arguments;
  if (line.empty()) return arguments;
  // The first token is read as a program name: give it one.
  const std::wstring full = L"x " + line;
  int count = 0;
  LPWSTR* parts = CommandLineToArgvW(full.c_str(), &count);
  if (parts == nullptr) return arguments;
  for (int index = 1; index < count; ++index) arguments.emplace_back(parts[index]);
  LocalFree(parts);
  return arguments;
}

HRESULT SetTitle(IShellLinkW* link, const std::wstring& title) {
  ComPtr<IPropertyStore> properties;
  HRESULT hr = link->QueryInterface(IID_PPV_ARGS(&properties));
  if (FAILED(hr)) return hr;
  PROPVARIANT value;
  if (FAILED(hr = InitPropVariantFromString(title.c_str(), &value))) return hr;
  hr = properties->SetValue(PKEY_Title, value);
  PropVariantClear(&value);
  return SUCCEEDED(hr) ? properties->Commit() : hr;
}

HRESULT AddLink(IObjectCollection* collection, const std::wstring& executable,
                const JumpListLink& entry) {
  ComPtr<IShellLinkW> link;
  HRESULT hr = CoCreateInstance(CLSID_ShellLink, nullptr, CLSCTX_INPROC_SERVER,
                                IID_PPV_ARGS(&link));
  if (FAILED(hr)) return hr;
  const std::wstring icon =
      entry.icon_path.empty() ? executable : entry.icon_path;
  if (FAILED(hr = link->SetPath(executable.c_str())) ||
      FAILED(hr = link->SetArguments(CommandLine(entry.arguments).c_str())) ||
      FAILED(hr = link->SetIconLocation(icon.c_str(), 0))) {
    return hr;
  }
  const size_t separator = executable.find_last_of(L"\\/");
  if (separator != std::wstring::npos &&
      FAILED(hr = link->SetWorkingDirectory(
                 executable.substr(0, separator).c_str()))) {
    return hr;
  }
  if (!entry.description.empty() &&
      FAILED(hr = link->SetDescription(entry.description.c_str()))) {
    return hr;
  }
  if (FAILED(hr = SetTitle(link.Get(), entry.title))) return hr;
  return collection->AddObject(link.Get());
}

// Command lines of the links in |removed|.
std::vector<std::wstring> RemovedCommandLines(IObjectArray* removed) {
  std::vector<std::wstring> lines;
  UINT count = 0;
  if (removed == nullptr || FAILED(removed->GetCount(&count))) return lines;
  for (UINT index = 0; index < count; ++index) {
    ComPtr<IShellLinkW> link;
    if (FAILED(removed->GetAt(index, IID_PPV_ARGS(&link)))) continue;
    std::wstring arguments(kArgumentsCapacity, L'\0');
    if (FAILED(link->GetArguments(arguments.data(), kArgumentsCapacity))) {
      continue;
    }
    arguments.resize(wcslen(arguments.c_str()));
    lines.push_back(std::move(arguments));
  }
  return lines;
}

HRESULT NewCollection(ComPtr<IObjectCollection>* collection) {
  return CoCreateInstance(CLSID_EnumerableObjectCollection, nullptr,
                          CLSCTX_INPROC_SERVER, IID_PPV_ARGS(collection->GetAddressOf()));
}

HRESULT AppendCategory(ICustomDestinationList* list,
                       const JumpListCategory& category,
                       const std::wstring& executable,
                       const std::vector<std::wstring>& removed, UINT slots) {
  ComPtr<IObjectCollection> links;
  HRESULT hr = NewCollection(&links);
  if (FAILED(hr)) return hr;
  UINT added = 0;
  for (const auto& entry : category.links) {
    if (added >= slots) break;
    const std::wstring line = CommandLine(entry.arguments);
    // Windows refuses the category when it holds a link the user removed.
    if (std::find(removed.begin(), removed.end(), line) != removed.end()) {
      continue;
    }
    if (FAILED(hr = AddLink(links.Get(), executable, entry))) return hr;
    ++added;
  }
  if (added == 0) return S_FALSE;
  ComPtr<IObjectArray> array;
  if (FAILED(hr = links.As(&array))) return hr;
  std::wstring title = category.title;
  if (title.empty()) {
    title = PRIMARYLANGID(GetUserDefaultUILanguage()) == LANG_FRENCH
                ? L"Récent"
                : L"Recent";
  }
  return list->AppendCategory(title.c_str(), array.Get());
}

HRESULT AddTasks(ICustomDestinationList* list, const JumpListContent& content,
                 const std::wstring& executable) {
  ComPtr<IObjectCollection> links;
  HRESULT hr = NewCollection(&links);
  if (FAILED(hr)) return hr;
  for (const auto& entry : content.tasks) {
    if (FAILED(hr = AddLink(links.Get(), executable, entry))) return hr;
  }
  ComPtr<IObjectArray> array;
  if (FAILED(hr = links.As(&array))) return hr;
  return list->AddUserTasks(array.Get());
}

}  // namespace

JumpListResult CommitJumpList(const JumpListContent& content) {
  JumpListResult result;
  const std::wstring executable = ExecutablePath();
  if (executable.empty()) return result;
  ComPtr<ICustomDestinationList> list;
  if (FAILED(CoCreateInstance(CLSID_DestinationList, nullptr,
                              CLSCTX_INPROC_SERVER, IID_PPV_ARGS(&list)))) {
    return result;
  }
  if (!content.app_id.empty() &&
      FAILED(list->SetAppID(content.app_id.c_str()))) {
    return result;
  }
  UINT slots = 0;
  ComPtr<IObjectArray> removed;
  if (FAILED(list->BeginList(&slots, IID_PPV_ARGS(&removed)))) return result;
  const std::vector<std::wstring> removed_lines =
      RemovedCommandLines(removed.Get());
  for (const auto& line : removed_lines) {
    result.removed.push_back(SplitCommandLine(line));
  }
  size_t filled = 0;
  for (const auto& category : content.categories) {
    if (!category.links.empty()) ++filled;
  }
  // Windows cuts the last categories past its slots: share them out.
  const UINT per_category =
      filled == 0 ? 0
                  : (std::max)(1u, slots / static_cast<UINT>(filled));
  for (const auto& category : content.categories) {
    if (category.links.empty()) continue;
    // E_ACCESSDENIED while Windows hides recent items: keep the tasks.
    if (AppendCategory(list.Get(), category, executable, removed_lines,
                       per_category) == S_OK) {
      result.categories_shown = true;
    }
  }
  if (!content.tasks.empty() &&
      FAILED(AddTasks(list.Get(), content, executable))) {
    list->AbortList();
    return result;
  }
  result.committed = SUCCEEDED(list->CommitList());
  if (!result.committed) list->AbortList();
  return result;
}

}  // namespace shipglows_tray
