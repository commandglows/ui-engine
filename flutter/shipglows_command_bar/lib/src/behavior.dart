import 'package:flutter/foundation.dart';

/// Optional ways the bar searches and lists, chosen per app (by its
/// developer, or from the app's settings when the bar opens). All are off by
/// default.
@immutable
class CommandBarBehavior {
  const CommandBarBehavior({
    this.fuzzyMatch = false,
    this.sortSectionsByMatch = false,
    this.tappablePrefixHints = false,
  });

  /// Every option on.
  static const all = CommandBarBehavior(
    fuzzyMatch: true,
    sortSectionsByMatch: true,
    tappablePrefixHints: true,
  );

  /// Whether a word that is not part of the label or keywords still matches
  /// when its letters appear in order in the label (« rgl » finds
  /// « Réglages »), from two letters. Such matches rank last.
  final bool fuzzyMatch;

  /// Whether, with typed words and no filter, sections are ordered by their
  /// best match instead of the app's order (kept on ties). Recents stay
  /// first.
  final bool sortSectionsByMatch;

  /// Whether each prefix of the hint line under an empty field is a button
  /// that applies its filter.
  final bool tappablePrefixHints;

  @override
  bool operator ==(Object other) =>
      other is CommandBarBehavior &&
      other.fuzzyMatch == fuzzyMatch &&
      other.sortSectionsByMatch == sortSectionsByMatch &&
      other.tappablePrefixHints == tappablePrefixHints;

  @override
  int get hashCode =>
      Object.hash(fuzzyMatch, sortSectionsByMatch, tappablePrefixHints);
}
