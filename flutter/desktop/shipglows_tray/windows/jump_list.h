#ifndef SHIPGLOWS_TRAY_JUMP_LIST_H_
#define SHIPGLOWS_TRAY_JUMP_LIST_H_

#include <windows.h>

#include <string>
#include <vector>

namespace shipglows_tray {

// One entry of the taskbar button's Jump List: this executable started with
// |arguments|.
struct JumpListLink {
  std::wstring title;
  // Tooltip; none when empty.
  std::wstring description;
  // .ico file; the executable's icon when empty.
  std::wstring icon_path;
  std::vector<std::wstring> arguments;
};

// A titled group of links; Windows offers to pin each of them.
struct JumpListCategory {
  // « Récent » or « Recent » when empty.
  std::wstring title;
  std::vector<JumpListLink> links;
};

struct JumpListContent {
  // The taskbar button's AppUserModelID; the process's when empty.
  std::wstring app_id;
  // In order; Windows' slots (10 by default) are shared between them.
  std::vector<JumpListCategory> categories;
  std::vector<JumpListLink> tasks;
};

struct JumpListResult {
  bool committed = false;
  // False when Windows hides recent items (Start settings) or there are none.
  bool categories_shown = false;
  // Arguments of the links the user removed from the list since the last
  // commit; they are left out of this one.
  std::vector<std::vector<std::wstring>> removed;
};

// Replaces the whole Jump List; pinned links stay, Windows keeps them.
// Needs COM on the calling thread (the runner initializes it).
JumpListResult CommitJumpList(const JumpListContent& content);

}  // namespace shipglows_tray

#endif  // SHIPGLOWS_TRAY_JUMP_LIST_H_
