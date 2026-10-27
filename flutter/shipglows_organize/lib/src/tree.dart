/// Which parent types each item type accepts, e.g. an action under a goal or
/// a step. Folders are the case of one type that only holds itself.
class ParentRules {
  const ParentRules(this.allowed);

  /// Parent types accepted by each type; a type missing here never has a
  /// parent.
  final Map<String, Set<String>> allowed;

  bool canHaveParent(String type) => allowed.containsKey(type);

  bool accepts(String type, String parentType) =>
      allowed[type]?.contains(parentType) ?? false;
}

/// Why a parent was refused.
enum TreeProblem { unknownParent, incompatibleType, cycle }

/// Read-only view of typed items linked by a parent id, built once from the
/// stored list, under [ParentRules]. On a duplicated id the last item wins.
///
/// [children], [parentOf], [path] and [descendants] show the tree: items
/// whose parent is missing, or that sit in a cycle (bad stored data), are
/// shown at the root so nothing disappears. [walkUp] and [walkDown] follow
/// the stored parent ids instead, to report or tolerate that bad data.
class TypedTree<T> {
  TypedTree(
    Iterable<T> items, {
    required this.idOf,
    required this.parentIdOf,
    required this.typeOf,
    required this.rules,
    this.compare,
  }) : _byId = {for (final item in items) idOf(item): item} {
    for (final item in _byId.values) {
      (_children[_safeParent(item)] ??= []).add(item);
    }
    _sort(_children);
  }

  final String Function(T item) idOf;
  final String? Function(T item) parentIdOf;
  final String Function(T item) typeOf;
  final ParentRules rules;

  /// Order of siblings; `null` keeps the stored order.
  final Comparator<T>? compare;

  final Map<String, T> _byId;
  final Map<String?, List<T>> _children = {};
  Map<String?, List<T>>? _linked;

  void _sort(Map<String?, List<T>> groups) {
    final compare = this.compare;
    if (compare != null) {
      for (final list in groups.values) {
        list.sort(compare);
      }
    }
  }

  String? _safeParent(T item) {
    final parentId = parentIdOf(item);
    if (parentId == null || !_byId.containsKey(parentId)) {
      return null;
    }
    return _reaches(parentId, idOf(item)) ? null : parentId;
  }

  /// True when walking up the stored parent ids from [start] meets [target]
  /// (or loops).
  bool _reaches(String start, String? target) {
    final seen = <String>{};
    String? current = start;
    while (current != null) {
      if (current == target || !seen.add(current)) {
        return true;
      }
      final item = _byId[current];
      current = item == null ? null : parentIdOf(item);
    }
    return false;
  }

  Iterable<T> get all => _byId.values;

  T? operator [](String id) => _byId[id];

  /// Items directly under [parentId] (`null` = root).
  List<T> children(String? parentId) =>
      List.unmodifiable(_children[parentId] ?? <T>[]);

  /// Parent of [id] as shown in the tree.
  String? parentOf(String id) {
    final item = _byId[id];
    return item == null ? null : _safeParent(item);
  }

  /// Items from the root down to [id], [id] included.
  List<T> path(String id) {
    final path = <T>[];
    String? current = id;
    while (current != null) {
      final item = _byId[current];
      if (item == null) {
        break;
      }
      path.insert(0, item);
      current = _safeParent(item);
    }
    return path;
  }

  /// Every item under [id], depth first.
  List<T> descendants(String id) {
    final result = <T>[];
    void visit(String parentId) {
      for (final child in children(parentId)) {
        result.add(child);
        visit(idOf(child));
      }
    }

    visit(id);
    return result;
  }

  /// [id] and every item under it: what a "this item and below" filter or a
  /// cascading delete touches.
  Set<String> subtreeIds(String id) => {
    id,
    for (final item in descendants(id)) idOf(item),
  };

  /// Stored ancestors of [item], nearest first. The walk stops at a missing
  /// parent ([TreeProblem.unknownParent]) or at an id met twice
  /// ([TreeProblem.cycle]), keeping the ancestors found until then.
  ({List<T> ancestors, TreeProblem? problem}) walkUp(T item) {
    final ancestors = <T>[];
    final seen = {idOf(item)};
    var parentId = parentIdOf(item);
    while (parentId != null) {
      if (!seen.add(parentId)) {
        return (ancestors: ancestors, problem: TreeProblem.cycle);
      }
      final parent = _byId[parentId];
      if (parent == null) {
        return (ancestors: ancestors, problem: TreeProblem.unknownParent);
      }
      ancestors.add(parent);
      parentId = parentIdOf(parent);
    }
    return (ancestors: ancestors, problem: null);
  }

  /// Every item whose stored parent ids lead to [id], depth first, each once
  /// even when they loop back to [id]: what a roll-up of [id] counts.
  List<T> walkDown(String id) {
    final linked = _linked ??= _groupByStoredParent();
    final seen = {id};
    final stack = [...(linked[id] ?? <T>[]).reversed];
    final result = <T>[];
    while (stack.isNotEmpty) {
      final item = stack.removeLast();
      if (!seen.add(idOf(item))) {
        continue;
      }
      result.add(item);
      stack.addAll((linked[idOf(item)] ?? <T>[]).reversed);
    }
    return result;
  }

  Map<String?, List<T>> _groupByStoredParent() {
    final groups = <String?, List<T>>{};
    for (final item in _byId.values) {
      final parentId = parentIdOf(item);
      if (parentId != null) {
        (groups[parentId] ??= []).add(item);
      }
    }
    _sort(groups);
    return groups;
  }

  /// Problem with putting an item of [type] under [parentId] (`null` = root,
  /// always allowed), or `null`. [movingId] is the item being moved: a parent
  /// under it is a cycle, as is a parent whose stored ancestors loop.
  TreeProblem? checkParent(String type, String? parentId, {String? movingId}) {
    if (parentId == null) {
      return null;
    }
    final parent = _byId[parentId];
    if (parent == null) {
      return TreeProblem.unknownParent;
    }
    if (!rules.accepts(type, typeOf(parent))) {
      return TreeProblem.incompatibleType;
    }
    return _reaches(parentId, movingId) ? TreeProblem.cycle : null;
  }
}
