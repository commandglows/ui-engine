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
    this.restoreLastQuery = false,
    this.showQueryHistory = false,
  });

  /// Every option on.
  static const all = CommandBarBehavior(
    fuzzyMatch: true,
    sortSectionsByMatch: true,
    tappablePrefixHints: true,
    restoreLastQuery: true,
    showQueryHistory: true,
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

  /// Whether the bar opens with the last search that led to a command, fully
  /// selected: typing replaces it, Enter runs it again.
  final bool restoreLastQuery;

  /// Whether the searches that led to a command are listed under an empty
  /// field, after the recent commands; choosing one puts it back in the field.
  final bool showQueryHistory;

  @override
  bool operator ==(Object other) =>
      other is CommandBarBehavior &&
      other.fuzzyMatch == fuzzyMatch &&
      other.sortSectionsByMatch == sortSectionsByMatch &&
      other.tappablePrefixHints == tappablePrefixHints &&
      other.restoreLastQuery == restoreLastQuery &&
      other.showQueryHistory == showQueryHistory;

  @override
  int get hashCode => Object.hash(
    fuzzyMatch,
    sortSectionsByMatch,
    tappablePrefixHints,
    restoreLastQuery,
    showQueryHistory,
  );
}
