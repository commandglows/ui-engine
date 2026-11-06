import 'package:shipglows_organize/shipglows_organize.dart';

import 'feeling.dart';
import 'standard_feelings.dart';

/// Longest word a person can add themselves, in characters.
const int maxCustomFeelingLength = 40;

const String _customPrefix = 'custom:';

/// The id to store for a person's own word, or `null` if [text] is blank.
///
/// Spaces are tidied and the text is cut to [maxCustomFeelingLength].
String? customFeelingId(String text) {
  var tidy = text.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (tidy.isEmpty) return null;
  if (tidy.length > maxCustomFeelingLength) {
    tidy = tidy.substring(0, maxCustomFeelingLength).trimRight();
  }
  return '$_customPrefix$tidy';
}

/// The person's own word held by [id], or `null` if [id] is not one.
String? customFeelingText(String id) {
  if (!id.startsWith(_customPrefix)) return null;
  final text = id.substring(_customPrefix.length);
  return text.isEmpty ? null : text;
}

/// A set of feeling words, in display order.
class FeelingBank {
  FeelingBank(Iterable<Feeling> feelings)
    : feelings = List.unmodifiable(feelings) {
    for (final feeling in this.feelings) {
      _byId[feeling.id] = feeling;
    }
  }

  /// Every word of this package.
  static final FeelingBank standard = FeelingBank(standardFeelings);

  /// The words, in display order.
  final List<Feeling> feelings;

  final Map<String, Feeling> _byId = {};

  /// Families that have at least one word, in their declared order.
  List<FeelingFamily> get families => [
    for (final family in FeelingFamily.values)
      if (feelings.any((feeling) => feeling.family == family)) family,
  ];

  /// Words of [family], in display order.
  List<Feeling> ofFamily(FeelingFamily family) => [
    for (final feeling in feelings)
      if (feeling.family == family) feeling,
  ];

  /// The word with this [id], or `null`.
  Feeling? byId(String id) => _byId[id];

  /// What to show for a stored [id]: the word's label, the person's own word,
  /// or `null` when this bank no longer has it.
  String? labelOf(String id, {required String languageCode}) =>
      _byId[id]?.label(languageCode) ?? customFeelingText(id);

  /// Words matching [query] on labels in both languages and on aliases, best
  /// first. Case and accents are ignored. An empty query returns every word.
  List<Feeling> search(String query, {required String languageCode}) =>
      rankBySearch(
        feelings,
        query,
        label: (feeling) => feeling.label(languageCode),
        fields: (feeling) => [feeling.fr, feeling.en, ...feeling.aliases],
      );

  /// A bank with only these [ids], in this bank's order.
  FeelingBank only(Iterable<String> ids) {
    final kept = ids.toSet();
    return FeelingBank(feelings.where((feeling) => kept.contains(feeling.id)));
  }

  /// A bank without these [ids].
  FeelingBank without(Iterable<String> ids) {
    final removed = ids.toSet();
    return FeelingBank(
      feelings.where((feeling) => !removed.contains(feeling.id)),
    );
  }

  /// A bank with [additions]: a word with an existing id replaces it in place,
  /// the others go at the end.
  FeelingBank plus(Iterable<Feeling> additions) {
    final added = {for (final feeling in additions) feeling.id: feeling};
    return FeelingBank([
      for (final feeling in feelings) added.remove(feeling.id) ?? feeling,
      ...added.values,
    ]);
  }
}
