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

  /// Whether the bar opens with the last search typed, run or not, fully
  /// selected: typing replaces it, Enter runs it again.
  final bool restoreLastQuery;

  /// Whether the past searches are listed under an empty field (after the
  /// recent commands) and under the restored last search (after its matches);
  /// choosing one puts it back in the field.
  final bool showQueryHistory;

  /// Copy with the given options replaced, for an app that lets the user
  /// turn some on or off.
  CommandBarBehavior copyWith({
    bool? fuzzyMatch,
    bool? sortSectionsByMatch,
    bool? tappablePrefixHints,
    bool? restoreLastQuery,
    bool? showQueryHistory,
  }) => CommandBarBehavior(
    fuzzyMatch: fuzzyMatch ?? this.fuzzyMatch,
    sortSectionsByMatch: sortSectionsByMatch ?? this.sortSectionsByMatch,
    tappablePrefixHints: tappablePrefixHints ?? this.tappablePrefixHints,
    restoreLastQuery: restoreLastQuery ?? this.restoreLastQuery,
    showQueryHistory: showQueryHistory ?? this.showQueryHistory,
  );

  /// JSON-safe map with the keys [fromJson] reads, for a bar in another
  /// engine.
  Map<String, bool> toJson() => {
    'fuzzyMatch': fuzzyMatch,
    'sortSectionsByMatch': sortSectionsByMatch,
    'tappablePrefixHints': tappablePrefixHints,
    'restoreLastQuery': restoreLastQuery,
    'showQueryHistory': showQueryHistory,
  };

  /// Restores options from [json], as produced by [toJson]; null when [json]
  /// is not a map. A missing option is off.
  static CommandBarBehavior? fromJson(Object? json) {
    if (json is! Map) return null;
    return CommandBarBehavior(
      fuzzyMatch: json['fuzzyMatch'] == true,
      sortSectionsByMatch: json['sortSectionsByMatch'] == true,
      tappablePrefixHints: json['tappablePrefixHints'] == true,
      restoreLastQuery: json['restoreLastQuery'] == true,
      showQueryHistory: json['showQueryHistory'] == true,
    );
  }

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
