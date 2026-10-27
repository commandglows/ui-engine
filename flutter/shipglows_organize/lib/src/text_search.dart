/// Plain-text search for pickers and command bars, started from the
/// ShipGlows app: case and accents are ignored, every typed word must match.

/// Lower-case, accent-free form of [value], used on both sides of a match.
String searchKey(String value) {
  const from = 'àâäáãåçéèêëíìîïñóòôöõúùûüýÿœæ';
  const to = 'aaaaaaceeeeiiiinooooouuuuyyoa';
  final buffer = StringBuffer();
  for (final char in value.toLowerCase().split('')) {
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString();
}

/// The words of [query] in [searchKey] form, empty ones dropped.
List<String> searchWords(String query) => [
  for (final word in searchKey(query).split(RegExp(r'\s+')))
    if (word.isNotEmpty) word,
];

/// True if every word of [query] appears in one of [fields]; an empty query
/// matches everything.
bool matchesSearch(String query, Iterable<String?> fields) {
  final words = searchWords(query);
  if (words.isEmpty) {
    return true;
  }
  final keys = [
    for (final field in fields)
      if (field != null && field.isNotEmpty) searchKey(field),
  ];
  return words.every((word) => keys.any((key) => key.contains(word)));
}

/// [items] matching [query], best first: a [label] starting with the query,
/// then a label holding every word, then every word found in the label or
/// [fields]. Equal matches keep the order of [items]; an empty query returns
/// them all.
List<T> rankBySearch<T>(
  Iterable<T> items,
  String query, {
  required String Function(T item) label,
  Iterable<String?> Function(T item)? fields,
}) {
  final words = searchWords(query);
  if (words.isEmpty) {
    return items.toList();
  }
  final phrase = words.join(' ');
  final tiers = [for (var tier = 0; tier < 3; tier++) <T>[]];
  for (final item in items) {
    final key = searchKey(label(item));
    if (key.startsWith(phrase)) {
      tiers[0].add(item);
    } else if (words.every(key.contains)) {
      tiers[1].add(item);
    } else {
      final haystack = searchKey(
        [label(item), ...?fields?.call(item)].whereType<String>().join(' '),
      );
      if (words.every(haystack.contains)) {
        tiers[2].add(item);
      }
    }
  }
  return [for (final tier in tiers) ...tier];
}
