import 'folders.dart';
import 'text_search.dart';

/// [searchKey] of a name, trimmed and single-spaced: two names with the same
/// key are the same name (`'  Élodie   Œuvre'` and `'elodie oeuvre'`).
String nameKey(String name) =>
    searchKey(name).trim().replaceAll(RegExp(r'\s+'), ' ');

/// Orders [a] and [b] by [nameKey], for sorting by name.
int compareNames(String a, String b) => nameKey(a).compareTo(nameKey(b));

/// [normalizeFolderName] without its length cut: stored names are compared
/// as they are.
String? _cleanName(String? name) =>
    normalizeFolderName(name, maxLength: name?.length ?? 0);

/// For flat collections stored by name (playlists, named folders): problem
/// with naming one [name] among [names], or `null`. Same rule as
/// `FolderTree.checkName`: not empty, unique ignoring case; [exceptName] is
/// the one being renamed.
FolderProblem? checkNameAmong(
  Iterable<String> names,
  String? name, {
  String? exceptName,
}) {
  final clean = _cleanName(name);
  if (clean == null) {
    return FolderProblem.emptyName;
  }
  final wanted = clean.toLowerCase();
  final except = _cleanName(exceptName);
  final taken = names.any((existing) {
    final other = _cleanName(existing);
    return other != null &&
        other != except &&
        other.toLowerCase() == wanted;
  });
  return taken ? FolderProblem.nameTaken : null;
}

/// Items created twice under the same name (two devices adding the same
/// folder or artist, each with its own id): maps each duplicate id to the id
/// kept everywhere, the smallest one of its [key]. Defaults to [nameKey], so
/// case, accents and spaces do not split a name.
Map<String, String> duplicateAliases<T>(
  Iterable<T> items, {
  required String Function(T item) id,
  required String Function(T item) name,
  String Function(String name) key = nameKey,
}) {
  final keptByKey = <String, String>{};
  for (final item in items) {
    final k = key(name(item));
    final kept = keptByKey[k];
    final own = id(item);
    keptByKey[k] = kept == null || own.compareTo(kept) < 0 ? own : kept;
  }
  return {
    for (final item in items)
      if (keptByKey[key(name(item))]! != id(item))
        id(item): keptByKey[key(name(item))]!,
  };
}
