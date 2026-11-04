#include "overlay_store.h"

#include <shlobj.h>

#include <cctype>
#include <cstdio>
#include <fstream>
#include <map>
#include <sstream>

namespace shipglows_overlay {
namespace {

using Fields = StoredFields;
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

StoredFields LoadStoredFields(const std::wstring& app_folder,
                              const std::string& id) {
  const std::wstring path = StorePath(app_folder);
  if (path.empty() || !ValidId(id)) return {};
  const Document document = Load(path);
  const auto entry = document.find(id);
  return entry == document.end() ? StoredFields{} : entry->second;
}

bool SaveStoredFields(
    const std::wstring& app_folder, const std::string& id,
    const std::map<std::string, std::optional<long long>>& changes) {
  const std::wstring path = StorePath(app_folder);
  if (path.empty() || !ValidId(id)) return false;
  for (const auto& [name, value] : changes) {
    if (!ValidId(name)) return false;
  }
  const std::wstring folder = path.substr(0, path.find_last_of(L'\\'));
  if (SHCreateDirectoryExW(nullptr, folder.c_str(), nullptr) != ERROR_SUCCESS &&
      GetLastError() != ERROR_ALREADY_EXISTS &&
      GetFileAttributesW(folder.c_str()) == INVALID_FILE_ATTRIBUTES) {
    return false;
  }

  // Only the fields named change: the bounds and the values an overlay keeps
  // for itself live side by side in its entry.
  Document document = Load(path);
  Fields fields = document[id];
  for (const auto& [name, value] : changes) {
    if (value) {
      fields[name] = *value;
    } else {
      fields.erase(name);
    }
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

std::optional<SIZE> StoredSize(const StoredFields& fields,
                               const std::string& prefix) {
  const auto width = fields.find(prefix + "width");
  const auto height = fields.find(prefix + "height");
  if (width == fields.end() || height == fields.end() || width->second <= 0 ||
      height->second <= 0 || width->second > kCoordinateLimit ||
      height->second > kCoordinateLimit) {
    return std::nullopt;
  }
  return SIZE{static_cast<LONG>(width->second),
              static_cast<LONG>(height->second)};
}

StoredBounds LoadStoredBounds(const std::wstring& app_folder,
                              const std::string& id) {
  StoredBounds bounds;
  const StoredFields fields = LoadStoredFields(app_folder, id);
  const auto x = fields.find("x");
  const auto y = fields.find("y");
  if (x != fields.end() && y != fields.end() && InRange(x->second) &&
      InRange(y->second)) {
    bounds.position = POINT{static_cast<LONG>(x->second),
                            static_cast<LONG>(y->second)};
  }
  bounds.size = StoredSize(fields, "");
  return bounds;
}

bool SaveStoredBounds(const std::wstring& app_folder, const std::string& id,
                      const StoredBounds& bounds) {
  const auto at = [](const auto& value, auto get) -> std::optional<long long> {
    if (!value) return std::nullopt;
    return get(*value);
  };
  return SaveStoredFields(
      app_folder, id,
      {
          {"x", at(bounds.position, [](POINT p) { return p.x; })},
          {"y", at(bounds.position, [](POINT p) { return p.y; })},
          {"width", at(bounds.size, [](SIZE s) { return s.cx; })},
          {"height", at(bounds.size, [](SIZE s) { return s.cy; })},
      });
}

}  // namespace shipglows_overlay
