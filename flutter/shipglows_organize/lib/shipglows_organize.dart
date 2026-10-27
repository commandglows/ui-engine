/// Folders, tags and search shared by ShipGlows apps, started from the
/// CommandGlows snippets: [normalizeTags] and friends clean and edit tag
/// lists, [FolderTree] reads a stored folder list (flat or nested) and checks
/// renames and moves, [OrganizeQuery] and [OrganizeFilter] select items.
///
/// Storage stays in each app: items only expose a folder id and a tag list.
library;

export 'src/folders.dart';
export 'src/labels.dart';
export 'src/named_items.dart';
export 'src/search.dart';
export 'src/sort.dart';
export 'src/tags.dart';
export 'src/text_search.dart';
