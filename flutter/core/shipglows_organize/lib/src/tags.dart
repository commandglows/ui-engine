/// Limits applied by [normalizeTags]; each app picks its own.
class TagRules {
  const TagRules({this.maxLength = 32, this.maxCount = 20});

  final int maxLength;
  final int maxCount;
}

/// One tag: trimmed, leading `#` removed, lower case, cut to
/// [TagRules.maxLength]; empty → `null`.
String? normalizeTag(Object? raw, {TagRules rules = const TagRules()}) {
  var tag = (raw ?? '').toString().trim().replaceFirst(RegExp(r'^#+'), '');
  tag = tag.toLowerCase();
  if (tag.length > rules.maxLength) {
    tag = tag.substring(0, rules.maxLength);
  }
  return tag.isEmpty ? null : tag;
}

/// Tags of an item: see [normalizeTag], without duplicates, at most
/// [TagRules.maxCount]. Accepts a list or a string split on commas/spaces.
List<String> normalizeTags(Object? raw, {TagRules rules = const TagRules()}) {
  final Iterable<Object?> parts = raw is Iterable
      ? raw
      : (raw ?? '').toString().split(RegExp(r'[,\s]+'));
  final tags = <String>[];
  for (final part in parts) {
    final tag = normalizeTag(part, rules: rules);
    if (tag != null && !tags.contains(tag)) {
      tags.add(tag);
    }
    if (tags.length == rules.maxCount) {
      break;
    }
  }
  return tags;
}

/// Distinct tags of [itemTags], sorted.
List<String> distinctTags(Iterable<Iterable<String>> itemTags) {
  return {for (final tags in itemTags) ...tags}.toList()..sort();
}

/// How many items carry each tag, sorted by tag.
Map<String, int> tagCounts(Iterable<Iterable<String>> itemTags) {
  final counts = <String, int>{};
  for (final tags in itemTags) {
    for (final tag in tags.toSet()) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }
  return Map.fromEntries(
    counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
  );
}

/// [tags] with [from] renamed to [to]; when [to] is already there the two
/// merge. Returns the same list when [from] is absent, so callers can skip
/// unchanged items. Renaming to an empty tag removes [from].
List<String> renameTag(
  List<String> tags,
  String from,
  String to, {
  TagRules rules = const TagRules(),
}) {
  if (!tags.contains(from)) {
    return tags;
  }
  final target = normalizeTag(to, rules: rules);
  final result = <String>[];
  for (final tag in tags) {
    final next = tag == from ? target : tag;
    if (next != null && !result.contains(next)) {
      result.add(next);
    }
  }
  return result;
}

/// [tags] without [tag]; the same list when [tag] is absent.
List<String> removeTag(List<String> tags, String tag) {
  return tags.contains(tag) ? [...tags.where((t) => t != tag)] : tags;
}
