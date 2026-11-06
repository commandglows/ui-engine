import 'tree.dart';

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

/// For apps whose items store a folder name rather than an id: the distinct
/// names (ignoring case, first spelling kept), sorted.
List<String> distinctFolderNames(Iterable<String?> names) {
  final byKey = <String, String>{};
  for (final name in names) {
    if (name != null) {
      byKey.putIfAbsent(name.toLowerCase(), () => name);
    }
  }
  return byKey.values.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
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

const _folderType = 'folder';

/// Folders nest in folders, nothing else.
const _folderRules = ParentRules({
  _folderType: {_folderType},
});

/// Read-only view of every folder, built once from the stored list: a
/// [TypedTree] of one type, siblings sorted by name.
///
/// Folders whose parent is missing, or that sit in a cycle (bad stored data),
/// are shown at the root so nothing disappears.
class FolderTree extends TypedTree<Folder> {
  FolderTree(Iterable<Folder> folders)
    : super(
        folders,
        idOf: _idOf,
        parentIdOf: _parentIdOf,
        typeOf: _typeOf,
        rules: _folderRules,
        compare: _byName,
      );

  static String _idOf(Folder folder) => folder.id;

  static String? _parentIdOf(Folder folder) => folder.parentId;

  static String _typeOf(Folder folder) => _folderType;

  static int _byName(Folder a, Folder b) {
    final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
    return byName != 0 ? byName : a.id.compareTo(b.id);
  }

  /// `Parent / Child` label of [id].
  String label(String id, {String separator = ' / '}) =>
      path(id).map((f) => f.name).join(separator);

  /// Problem with naming a folder [name] under [parentId], or `null`.
  /// Names are unique among siblings, ignoring case; [exceptId] is the folder
  /// being renamed or moved.
  FolderProblem? checkName(String? name, String? parentId, {String? exceptId}) {
    final clean = normalizeFolderName(name);
    if (clean == null) {
      return FolderProblem.emptyName;
    }
    if (parentId != null && this[parentId] == null) {
      return FolderProblem.unknownParent;
    }
    final taken = children(parentId).any(
      (f) => f.id != exceptId && f.name.toLowerCase() == clean.toLowerCase(),
    );
    return taken ? FolderProblem.nameTaken : null;
  }

  /// Problem with moving [id] under [newParentId], or `null`.
  FolderProblem? checkMove(String id, String? newParentId) {
    switch (checkParent(_folderType, newParentId, movingId: id)) {
      case TreeProblem.unknownParent:
        return FolderProblem.unknownParent;
      case TreeProblem.cycle || TreeProblem.incompatibleType:
        return FolderProblem.cycle;
      case null:
        return checkName(this[id]?.name, newParentId, exceptId: id);
    }
  }
}
