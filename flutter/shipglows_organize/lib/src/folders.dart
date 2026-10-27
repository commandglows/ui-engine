/// Longest folder name kept by [normalizeFolderName].
const folderNameMaxLength = 48;

/// Folder name: trimmed, inner spaces collapsed, cut to [maxLength];
/// empty → `null`.
String? normalizeFolderName(
  Object? raw, {
  int maxLength = folderNameMaxLength,
}) {
  var name = (raw ?? '').toString().trim().replaceAll(RegExp(r'\s+'), ' ');
  if (name.length > maxLength) {
    name = name.substring(0, maxLength);
  }
  return name.isEmpty ? null : name;
}

/// A folder as the app stores it. [parentId] `null` is the root; apps with
/// flat folders never set it.
class Folder {
  const Folder({required this.id, required this.name, this.parentId});

  final String id;
  final String name;
  final String? parentId;

  Folder copyWith({String? name, String? Function()? parentId}) {
    return Folder(
      id: id,
      name: name ?? this.name,
      parentId: parentId == null ? this.parentId : parentId(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Folder &&
      other.id == id &&
      other.name == name &&
      other.parentId == parentId;

  @override
  int get hashCode => Object.hash(id, name, parentId);

  @override
  String toString() => 'Folder($id, $name, parent: $parentId)';
}

/// Why a folder change was refused.
enum FolderProblem { emptyName, nameTaken, unknownParent, cycle }

/// Read-only view of every folder, built once from the stored list.
///
/// Folders whose parent is missing, or that sit in a cycle (bad stored data),
/// are shown at the root so nothing disappears.
class FolderTree {
  FolderTree(Iterable<Folder> folders)
    : _byId = {for (final folder in folders) folder.id: folder} {
    for (final folder in _byId.values) {
      final parent = _safeParent(folder);
      (_children[parent] ??= []).add(folder);
    }
    for (final list in _children.values) {
      list.sort(_byName);
    }
  }

  final Map<String, Folder> _byId;
  final Map<String?, List<Folder>> _children = {};

  static int _byName(Folder a, Folder b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  String? _safeParent(Folder folder) {
    final parentId = folder.parentId;
    if (parentId == null || !_byId.containsKey(parentId)) {
      return null;
    }
    return _reaches(parentId, folder.id) ? null : parentId;
  }

  /// True when walking up from [start] meets [target] (or loops).
  bool _reaches(String start, String target) {
    final seen = <String>{};
    String? current = start;
    while (current != null) {
      if (current == target || !seen.add(current)) {
        return true;
      }
      current = _byId[current]?.parentId;
    }
    return false;
  }

  Iterable<Folder> get all => _byId.values;

  Folder? operator [](String id) => _byId[id];

  /// Folders directly under [parentId] (`null` = root), sorted by name.
  List<Folder> children(String? parentId) =>
      List.unmodifiable(_children[parentId] ?? const <Folder>[]);

  /// Parent of [id] as shown in the tree.
  String? parentOf(String id) {
    final folder = _byId[id];
    return folder == null ? null : _safeParent(folder);
  }

  /// Folders from the root down to [id], [id] included.
  List<Folder> path(String id) {
    final path = <Folder>[];
    String? current = id;
    while (current != null) {
      final folder = _byId[current];
      if (folder == null) {
        break;
      }
      path.insert(0, folder);
      current = _safeParent(folder);
    }
    return path;
  }

  /// `Parent / Child` label of [id].
  String label(String id, {String separator = ' / '}) =>
      path(id).map((f) => f.name).join(separator);

  /// Every folder under [id], depth first.
  List<Folder> descendants(String id) {
    final result = <Folder>[];
    void visit(String parentId) {
      for (final child in children(parentId)) {
        result.add(child);
        visit(child.id);
      }
    }

    visit(id);
    return result;
  }

  /// [id] and every folder under it: what a "this folder and below" filter
  /// or a cascading delete touches.
  Set<String> subtreeIds(String id) => {
    id,
    for (final folder in descendants(id)) folder.id,
  };

  /// Problem with naming a folder [name] under [parentId], or `null`.
  /// Names are unique among siblings, ignoring case; [exceptId] is the folder
  /// being renamed or moved.
  FolderProblem? checkName(String? name, String? parentId, {String? exceptId}) {
    final clean = normalizeFolderName(name);
    if (clean == null) {
      return FolderProblem.emptyName;
    }
    if (parentId != null && !_byId.containsKey(parentId)) {
      return FolderProblem.unknownParent;
    }
    final taken = children(parentId).any(
      (f) => f.id != exceptId && f.name.toLowerCase() == clean.toLowerCase(),
    );
    return taken ? FolderProblem.nameTaken : null;
  }

  /// Problem with moving [id] under [newParentId], or `null`.
  FolderProblem? checkMove(String id, String? newParentId) {
    if (newParentId != null) {
      if (!_byId.containsKey(newParentId)) {
        return FolderProblem.unknownParent;
      }
      if (newParentId == id || subtreeIds(id).contains(newParentId)) {
        return FolderProblem.cycle;
      }
    }
    return checkName(_byId[id]?.name, newParentId, exceptId: id);
  }
}
