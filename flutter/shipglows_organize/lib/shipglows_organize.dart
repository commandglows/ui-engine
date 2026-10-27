/// Folders, tags and search shared by ShipGlows apps, started from the
/// CommandGlows snippets: [normalizeTags] and friends clean and edit tag
/// lists, [FolderTree] reads a stored folder list (flat or nested) and checks
/// renames and moves, [TypedTree] does the same for typed items under
/// [ParentRules] (DreamGlows dream > goal > step > action), [rankBetween]
/// keeps a manual order, [OrganizeQuery] and [OrganizeFilter] select items.
///
/// Storage stays in each app: items only expose a folder or parent id, a tag
/// list and a rank. Pure Dart: no Flutter import.
library;

export 'src/folders.dart';
export 'src/labels.dart';
export 'src/named_items.dart';
export 'src/rank.dart';
export 'src/search.dart';
export 'src/sort.dart';
export 'src/tags.dart';
export 'src/text_search.dart';
export 'src/tree.dart';
