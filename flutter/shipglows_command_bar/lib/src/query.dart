import 'package:flutter/services.dart';

import 'command.dart';

/// Accented letters folded to their plain form for accent-insensitive search.
const Map<String, String> _accentFolds = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ä': 'a',
  'ã': 'a',
  'ç': 'c',
  'é': 'e',
  'è': 'e',
  'ê': 'e',
  'ë': 'e',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ñ': 'n',
  'ó': 'o',
  'ô': 'o',
  'ö': 'o',
  'õ': 'o',
  'ú': 'u',
  'ù': 'u',
  'û': 'u',
  'ü': 'u',
  'ÿ': 'y',
  'œ': 'oe',
  'æ': 'ae',
};

/// Lowercases [text] and folds accents, so « écran » matches « ecran ».
String normalizeCommandText(String text) {
  final buffer = StringBuffer();
  for (final char in text.toLowerCase().split('')) {
    buffer.write(_accentFolds[char] ?? char);
  }
  return buffer.toString();
}

/// Splits [query] into normalized, non-empty words.
List<String> commandSearchTokens(String query) => normalizeCommandText(
  query,
).split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList();

/// What the user typed, split into its category and the words to match.
class CommandBarQuery {
  const CommandBarQuery({required this.text, this.filter});

  /// Category restriction, or null for every category.
  final CommandBarFilter? filter;

  /// Words to match, with the prefix removed.
  final String text;
}

/// Splits [raw] into a [CommandBarQuery] using [filters].
///
/// A prefix counts only at the very start and, unless its filter has
/// [CommandBarFilter.requiresSpace] off, only when a space follows it:
/// `n idea` selects the `n` filter, while `n` alone, or `z idea` with an
/// unknown letter, is plain text. A filter without the space applies as soon
/// as its prefix is typed (`>foo`). A leading space selects the filter whose
/// prefix is a space, if there is one.
CommandBarQuery parseCommandBarQuery(
  String raw,
  List<CommandBarFilter> filters,
) {
  if (raw.startsWith(' ')) {
    for (final filter in filters) {
      if (filter.prefix == ' ') {
        return CommandBarQuery(filter: filter, text: raw.trim());
      }
    }
  }
  final lowered = raw.toLowerCase();
  for (final filter in filters) {
    if (filter.prefix != ' ' &&
        !filter.requiresSpace &&
        filter.prefix.isNotEmpty &&
        lowered.startsWith(filter.prefix.toLowerCase())) {
      return CommandBarQuery(
        filter: filter,
        text: raw.substring(filter.prefix.length).trim(),
      );
    }
  }
  if (raw.length >= 2 && raw[1] == ' ') {
    final typed = raw[0].toLowerCase();
    for (final filter in filters) {
      if (filter.prefix != ' ' &&
          filter.requiresSpace &&
          filter.prefix.toLowerCase() == typed) {
        return CommandBarQuery(filter: filter, text: raw.substring(2).trim());
      }
    }
  }
  return CommandBarQuery(text: raw);
}

/// Rank of a match whose words were only found as letters in order.
const int _fuzzyRank = 3;

/// Whether the letters of [word] appear in order in [text].
bool _isSubsequence(String word, String text) {
  var at = 0;
  for (var i = 0; i < text.length && at < word.length; i++) {
    if (text[i] == word[at]) at++;
  }
  return at == word.length;
}

/// The [entries] matching every word of [query] with their rank, best
/// matches first.
///
/// Rank 0: the label starts with the first word; 1: the label contains it;
/// 2: found only in the keywords; 3 ([fuzzy] only): a word of two letters or
/// more was found only as letters in order in the label. An empty query
/// returns all entries at rank 0, in their original order.
List<({T entry, int rank})> scoreCommandEntries<T>(
  List<T> entries,
  String query, {
  required String Function(T entry) labelOf,
  required List<String> Function(T entry) keywordsOf,
  bool fuzzy = false,
}) {
  final tokens = commandSearchTokens(query);
  if (tokens.isEmpty) {
    return [for (final entry in entries) (entry: entry, rank: 0)];
  }

  final ranked = <({int rank, int index, T entry})>[];
  for (var index = 0; index < entries.length; index++) {
    final entry = entries[index];
    final label = normalizeCommandText(labelOf(entry));
    final haystack = [
      label,
      ...keywordsOf(entry).map(normalizeCommandText),
    ].join(' ');
    var fuzzyOnly = false;
    var matches = true;
    for (final token in tokens) {
      if (haystack.contains(token)) continue;
      if (fuzzy && token.length >= 2 && _isSubsequence(token, label)) {
        fuzzyOnly = true;
        continue;
      }
      matches = false;
      break;
    }
    if (!matches) continue;
    final first = tokens.first;
    final rank = fuzzyOnly
        ? _fuzzyRank
        : label.startsWith(first)
        ? 0
        : label.contains(first)
        ? 1
        : 2;
    ranked.add((rank: rank, index: index, entry: entry));
  }
  ranked.sort(
    (a, b) => a.rank != b.rank
        ? a.rank.compareTo(b.rank)
        : a.index.compareTo(b.index),
  );
  return [for (final match in ranked) (entry: match.entry, rank: match.rank)];
}

/// Returns the [entries] matching every word of [query], best matches first.
/// See [scoreCommandEntries] for the order.
List<T> rankCommandEntries<T>(
  List<T> entries,
  String query, {
  required String Function(T entry) labelOf,
  required List<String> Function(T entry) keywordsOf,
  bool fuzzy = false,
}) => [
  for (final match in scoreCommandEntries(
    entries,
    query,
    labelOf: labelOf,
    keywordsOf: keywordsOf,
    fuzzy: fuzzy,
  ))
    match.entry,
];

/// Entries matching [query] with their rank (see [scoreCommandEntries]),
/// best matches first, disabled ones after the enabled ones.
List<({CommandBarEntry entry, int rank})> scoreCommandBarMatches(
  Iterable<CommandBarEntry> entries,
  CommandBarQuery query, {
  bool fuzzy = false,
}) {
  final filter = query.filter;
  final scoped = [
    for (final entry in entries)
      if (filter == null || filter.matches(entry)) entry,
  ];
  final ranked = scoreCommandEntries<CommandBarEntry>(
    scoped,
    query.text,
    labelOf: (entry) => entry.label,
    keywordsOf: (entry) => entry.keywords,
    fuzzy: fuzzy,
  );
  return [
    ...ranked.where((match) => match.entry.enabled),
    ...ranked.where((match) => !match.entry.enabled),
  ];
}

/// Entries matching [query], best matches first, disabled ones after the
/// enabled ones.
List<CommandBarEntry> commandBarMatches(
  Iterable<CommandBarEntry> entries,
  CommandBarQuery query, {
  bool fuzzy = false,
}) => [
  for (final match in scoreCommandBarMatches(entries, query, fuzzy: fuzzy))
    match.entry,
];

const List<LogicalKeyboardKey> _topRowDigits = <LogicalKeyboardKey>[
  LogicalKeyboardKey.digit1,
  LogicalKeyboardKey.digit2,
  LogicalKeyboardKey.digit3,
  LogicalKeyboardKey.digit4,
  LogicalKeyboardKey.digit5,
  LogicalKeyboardKey.digit6,
  LogicalKeyboardKey.digit7,
  LogicalKeyboardKey.digit8,
  LogicalKeyboardKey.digit9,
];

const List<LogicalKeyboardKey> _numpadDigits = <LogicalKeyboardKey>[
  LogicalKeyboardKey.numpad1,
  LogicalKeyboardKey.numpad2,
  LogicalKeyboardKey.numpad3,
  LogicalKeyboardKey.numpad4,
  LogicalKeyboardKey.numpad5,
  LogicalKeyboardKey.numpad6,
  LogicalKeyboardKey.numpad7,
  LogicalKeyboardKey.numpad8,
  LogicalKeyboardKey.numpad9,
];

/// The 1-based number of a top-row or numpad digit key, or null.
int? commandBarDigit(LogicalKeyboardKey key) {
  final topIndex = _topRowDigits.indexOf(key);
  if (topIndex >= 0) return topIndex + 1;
  final padIndex = _numpadDigits.indexOf(key);
  return padIndex >= 0 ? padIndex + 1 : null;
}
