#include "overlay_store.h"

#include <shlobj.h>

#include <cctype>
#include <cstdio>
#include <fstream>
#include <map>
#include <sstream>

namespace shipglows_overlay {
namespace {

using Fields = std::map<std::string, long long>;
using Document = std::map<std::string, Fields>;

// Coordinates outside this range come from a corrupt file.
constexpr long long kCoordinateLimit = 1000000;

std::wstring StorePath(const std::wstring& app_folder) {
  if (app_folder.empty()) return {};
  PWSTR roaming = nullptr;
  if (FAILED(SHGetKnownFolderPath(FOLDERID_RoamingAppData, 0, nullptr,
                                  &roaming))) {
    return {};
  }
  std::wstring path = std::wstring(roaming) + L"\\" + app_folder;
  CoTaskMemFree(roaming);
  return path + L"\\overlay_windows.json";
}

// Reader for the flat {"id":{"key":integer}} document this file writes.
class Parser {
 public:
  explicit Parser(const std::string& text) : text_(text) {}

  bool Parse(Document* document) {
    if (!Consume('{')) return false;
    if (Consume('}')) return AtEnd();
    do {
      std::string id;
      Fields fields;
      if (!String(&id) || !Consume(':') || !Object(&fields)) return false;
      (*document)[id] = fields;
    } while (Consume(','));
    return Consume('}') && AtEnd();
  }

 private:
  bool Object(Fields* fields) {
    if (!Consume('{')) return false;
    if (Consume('}')) return true;
    do {
      std::string key;
      long long value = 0;
      if (!String(&key) || !Consume(':') || !Number(&value)) return false;
      (*fields)[key] = value;
    } while (Consume(','));
    return Consume('}');
  }

  bool String(std::string* out) {
    if (!Consume('"')) return false;
    while (index_ < text_.size() && text_[index_] != '"') {
      if (text_[index_] == '\\') return false;
      out->push_back(text_[index_++]);
    }
    return Consume('"');
  }

  bool Number(long long* out) {
    SkipSpace();
    const size_t start = index_;
    if (index_ < text_.size() && text_[index_] == '-') ++index_;
    const size_t digits = index_;
    while (index_ < text_.size() &&
           std::isdigit(static_cast<unsigned char>(text_[index_]))) {
      ++index_;
    }
    if (index_ == digits || index_ - start > 12) return false;
    *out = std::stoll(text_.substr(start, index_ - start));
    // A fractional part, if an editor added one, is dropped.
    if (index_ < text_.size() && text_[index_] == '.') {
      ++index_;
      while (index_ < text_.size() &&
             std::isdigit(static_cast<unsigned char>(text_[index_]))) {
        ++index_;
      }
    }
    return true;
  }

  bool Consume(char expected) {
    SkipSpace();
    if (index_ >= text_.size() || text_[index_] != expected) return false;
    ++index_;
    return true;
  }

  bool AtEnd() {
    SkipSpace();
    return index_ == text_.size();
  }

  void SkipSpace() {
    while (index_ < text_.size() &&
           std::isspace(static_cast<unsigned char>(text_[index_]))) {
      ++index_;
    }
  }

  const std::string& text_;
  size_t index_ = 0;
};

Document Load(const std::wstring& path) {
  Document document;
  std::ifstream file(path, std::ios::binary);
  if (!file) return document;
  std::stringstream buffer;
  buffer << file.rdbuf();
  const std::string text = buffer.str();
  if (!Parser(text).Parse(&document)) document.clear();
  return document;
}

bool InRange(long long value) {
  return value >= -kCoordinateLimit && value <= kCoordinateLimit;
}

bool ValidId(const std::string& id) {
  if (id.empty()) return false;
  for (const char c : id) {
    if (c == '"' || c == '\\' || static_cast<unsigned char>(c) < 0x20) {
      return false;
    }
  }
  return true;
}

}  // namespace

StoredBounds LoadStoredBounds(const std::wstring& app_folder,
                              const std::string& id) {
  StoredBounds bounds;
  const std::wstring path = StorePath(app_folder);
  if (path.empty() || !ValidId(id)) return bounds;
  const Document document = Load(path);
  const auto entry = document.find(id);
  if (entry == document.end()) return bounds;
  const Fields& fields = entry->second;
  const auto x = fields.find("x");
  const auto y = fields.find("y");
  if (x != fields.end() && y != fields.end() && InRange(x->second) &&
      InRange(y->second)) {
    bounds.position = POINT{static_cast<LONG>(x->second),
                            static_cast<LONG>(y->second)};
  }
  const auto width = fields.find("width");
  const auto height = fields.find("height");
  if (width != fields.end() && height != fields.end() && width->second > 0 &&
      height->second > 0 && width->second <= kCoordinateLimit &&
      height->second <= kCoordinateLimit) {
    bounds.size = SIZE{static_cast<LONG>(width->second),
                       static_cast<LONG>(height->second)};
  }
  return bounds;
}

bool SaveStoredBounds(const std::wstring& app_folder, const std::string& id,
                      const StoredBounds& bounds) {
  const std::wstring path = StorePath(app_folder);
  if (path.empty() || !ValidId(id)) return false;
  const std::wstring folder = path.substr(0, path.find_last_of(L'\\'));
  if (SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr) != ERROR_SUCCESS &&
      GetLastError() != ERROR_ALREADY_EXISTS &&
      GetFileAttributesW(folder.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return false;
  }

  Document document = Load(path);
  Fields fields;
  if (bounds.position) {
    fields["x"] = bounds.position->x;
    fields["y"] = bounds.position->y;
  }
  if (bounds.size) {
    fields["width"] = bounds.size->cx;
    fields["height"] = bounds.size->cy;
  }
  if (fields.empty()) {
    document.erase(id);
  } else {
    document[id] = fields;
  }

  std::ostringstream out;
  out << "{";
  bool first_entry = true;
  for (const auto& [key, values] : document) {
    out << (first_entry ? "\n  " : ",\n  ") << '"' << key << "\": {";
    first_entry = false;
    bool first_field = true;
    for (const auto& [name, value] : values) {
      out << (first_field ? "" : ", ") << '"' << name << "\": " << value;
      first_field = false;
    }
    out << "}";
  }
  out << "\n}\n";

  const std::wstring temporary = path + L".tmp";
  {
    std::ofstream file(temporary, std::ios::binary | std::ios::trunc);
    if (!file) return false;
    const std::string text = out.str();
    file.write(text.data(), static_cast<std::streamsize>(text.size()));
    if (!file) return false;
  }
  return MoveFileExW(temporary.c_str(), path.c_str(),
                     MOVEFILE_REPLACE_EXISTING | MOVEFILE_WRITE_THROUGH) != 0;
}

}  // namespace shipglows_overlay
