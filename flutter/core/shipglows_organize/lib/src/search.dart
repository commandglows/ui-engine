/// A search typed by the user: `#term` must prefix one of the item's tags,
/// every other term must appear in one of its fields or prefix a tag.
class OrganizeQuery {
  OrganizeQuery._(this.terms, this.tagTerms);

  factory OrganizeQuery.parse(String query) {
    final terms = <String>[];
    final tagTerms = <String>[];
    for (final term in query.trim().toLowerCase().split(RegExp(r'\s+'))) {
      if (term.startsWith('#')) {
        final wanted = term.replaceFirst(RegExp(r'^#+'), '');
        if (wanted.isNotEmpty) {
          tagTerms.add(wanted);
        }
      } else if (term.isNotEmpty) {
        terms.add(term);
      }
    }
    return OrganizeQuery._(
      List.unmodifiable(terms),
      List.unmodifiable(tagTerms),
    );
  }

  final List<String> terms;
  final List<String> tagTerms;

  bool get isEmpty => terms.isEmpty && tagTerms.isEmpty;

  /// True if an item with [tags] and searchable [fields] (title, body,
  /// folder label…) matches every term.
  bool matches({
    required Iterable<String> tags,
    Iterable<String?> fields = const [],
  }) {
    for (final wanted in tagTerms) {
      if (!tags.any((t) => t.startsWith(wanted))) {
        return false;
      }
    }
    if (terms.isEmpty) {
      return true;
    }
    final lowered = [
      for (final field in fields)
        if (field != null && field.isNotEmpty) field.toLowerCase(),
    ];
    for (final term in terms) {
      final found =
          lowered.any((f) => f.contains(term)) ||
          tags.any((t) => t.startsWith(term));
      if (!found) {
        return false;
      }
    }
    return true;
  }
}

/// How several selected tags combine in a filter.
enum TagMatch { all, any }

/// Exact filters picked in the UI, on top of an [OrganizeQuery].
class OrganizeFilter {
  const OrganizeFilter({
    this.folderIds,
    this.tags = const {},
    this.tagMatch = TagMatch.all,
  });

  /// Allowed folders (`null` = any, include `null` in the set for items
  /// without folder). Use `FolderTree.subtreeIds` to include sub-folders.
  final Set<String?>? folderIds;
  final Set<String> tags;
  final TagMatch tagMatch;

  bool matches({String? folderId, required Iterable<String> tags}) {
    final folders = folderIds;
    if (folders != null && !folders.contains(folderId)) {
      return false;
    }
    if (this.tags.isEmpty) {
      return true;
    }
    final own = tags.toSet();
    return switch (tagMatch) {
      TagMatch.all => own.containsAll(this.tags),
      TagMatch.any => this.tags.any(own.contains),
    };
  }
}
