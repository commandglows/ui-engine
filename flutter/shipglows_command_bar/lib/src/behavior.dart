import 'package:flutter/foundation.dart';

/// How a row shows its [CommandBarEntry.kind] when
/// [CommandBarBehavior.showEntryKinds] is on.
enum CommandBarKindDisplay {
  /// A small muted icon, its text in a tooltip.
  icon,

  /// The short text of [CommandBarStrings.entryKindLabels], muted, at the end
  /// of the row (« Action », « App »).
  label,

  /// The icon, then the text.
  iconAndLabel,
}

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
    this.showEntryKinds = false,
    this.hiddenKinds = const <String>{},
    this.kindDisplay = CommandBarKindDisplay.icon,
    this.compactRows = false,
  });

  /// Every option on.
  static const all = CommandBarBehavior(
    fuzzyMatch: true,
    sortSectionsByMatch: true,
    tappablePrefixHints: true,
    restoreLastQuery: true,
    showQueryHistory: true,
    showEntryKinds: true,
    compactRows: true,
  );

  /// Whether a word that is not part of the label or keywords still matches
  /// when its letters appear in order in the label (« rgl » finds
  /// « Réglages »), from two letters. Such matches rank last.
  final bool fuzzyMatch;

  /// Whether, with typed words and no filter, sections are ordered by their
  /// best match instead of the app's order (kept on ties). Recents stay
  /// first.
  final bool sortSectionsByMatch;

  /// Kept for saved settings only: the filter row under the field is always
  /// made of buttons now.
  final bool tappablePrefixHints;

  /// Whether the bar opens with the last search typed, run or not, fully
  /// selected: typing replaces it, Enter runs it again.
  final bool restoreLastQuery;

  /// Whether the past searches are listed under an empty field (after the
  /// recent commands) and under the restored last search (after its matches);
  /// choosing one puts it back in the field.
  final bool showQueryHistory;

  /// Whether each row shows what choosing it does (its
  /// [CommandBarEntry.kind]): open a screen, act right here, open another
  /// app.
  final bool showEntryKinds;

  /// Ids of the [CommandBarEntryKind]s the bar leaves out, such as `open` for
  /// a user who only wants actions. Entries without a kind always show.
  final Set<String> hiddenKinds;

  /// How each row shows its kind, when [showEntryKinds] is on.
  final CommandBarKindDisplay kindDisplay;

  /// Whether the subtitle follows the label on the same line, muted, so
  /// more rows fit. A disabled row keeps its reason on a line of its own.
  final bool compactRows;

  /// Copy with the given options replaced, for an app that lets the user
  /// turn some on or off.
  CommandBarBehavior copyWith({
    bool? fuzzyMatch,
    bool? sortSectionsByMatch,
    bool? tappablePrefixHints,
    bool? restoreLastQuery,
    bool? showQueryHistory,
    bool? showEntryKinds,
    Set<String>? hiddenKinds,
    CommandBarKindDisplay? kindDisplay,
    bool? compactRows,
  }) => CommandBarBehavior(
    fuzzyMatch: fuzzyMatch ?? this.fuzzyMatch,
    sortSectionsByMatch: sortSectionsByMatch ?? this.sortSectionsByMatch,
    tappablePrefixHints: tappablePrefixHints ?? this.tappablePrefixHints,
    restoreLastQuery: restoreLastQuery ?? this.restoreLastQuery,
    showQueryHistory: showQueryHistory ?? this.showQueryHistory,
    showEntryKinds: showEntryKinds ?? this.showEntryKinds,
    hiddenKinds: hiddenKinds ?? this.hiddenKinds,
    kindDisplay: kindDisplay ?? this.kindDisplay,
    compactRows: compactRows ?? this.compactRows,
  );

  /// JSON-safe map with the keys [fromJson] reads, for a bar in another
  /// engine.
  Map<String, Object> toJson() => {
    'fuzzyMatch': fuzzyMatch,
    'sortSectionsByMatch': sortSectionsByMatch,
    'tappablePrefixHints': tappablePrefixHints,
    'restoreLastQuery': restoreLastQuery,
    'showQueryHistory': showQueryHistory,
    'showEntryKinds': showEntryKinds,
    'hiddenKinds': hiddenKinds.toList(),
    'kindDisplay': kindDisplay.name,
    'compactRows': compactRows,
  };

  /// Restores options from [json], as produced by [toJson]; null when [json]
  /// is not a map. A missing option is off; a missing [kindDisplay] is
  /// [CommandBarKindDisplay.icon].
  static CommandBarBehavior? fromJson(Object? json) {
    if (json is! Map) return null;
    return CommandBarBehavior(
      fuzzyMatch: json['fuzzyMatch'] == true,
      sortSectionsByMatch: json['sortSectionsByMatch'] == true,
      tappablePrefixHints: json['tappablePrefixHints'] == true,
      restoreLastQuery: json['restoreLastQuery'] == true,
      showQueryHistory: json['showQueryHistory'] == true,
      showEntryKinds: json['showEntryKinds'] == true,
      hiddenKinds: {
        if (json['hiddenKinds'] case final List ids)
          for (final id in ids)
            if (id is String) id,
      },
      kindDisplay: CommandBarKindDisplay.values.firstWhere(
        (display) => display.name == json['kindDisplay'],
        orElse: () => CommandBarKindDisplay.icon,
      ),
      compactRows: json['compactRows'] == true,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CommandBarBehavior &&
      other.fuzzyMatch == fuzzyMatch &&
      other.sortSectionsByMatch == sortSectionsByMatch &&
      other.tappablePrefixHints == tappablePrefixHints &&
      other.restoreLastQuery == restoreLastQuery &&
      other.showQueryHistory == showQueryHistory &&
      other.showEntryKinds == showEntryKinds &&
      setEquals(other.hiddenKinds, hiddenKinds) &&
      other.kindDisplay == kindDisplay &&
      other.compactRows == compactRows;

  @override
  int get hashCode => Object.hash(
    fuzzyMatch,
    sortSectionsByMatch,
    tappablePrefixHints,
    restoreLastQuery,
    showQueryHistory,
    showEntryKinds,
    Object.hashAllUnordered(hiddenKinds),
    kindDisplay,
    compactRows,
  );
}
