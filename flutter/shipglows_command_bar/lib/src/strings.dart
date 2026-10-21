import 'package:flutter/foundation.dart';

/// Texts of the command bar. The app picks the language: use [en], [fr], or
/// its own values.
@immutable
class CommandBarStrings {
  const CommandBarStrings({
    required this.dialogLabel,
    required this.searchHint,
    required this.recentSection,
    required this.noMatch,
    required this.filterChip,
    required this.prefixesHint,
    required this.spaceKey,
    required this.navigate,
    required this.open,
    required this.secondary,
    required this.close,
    required this.openCommandBar,
    this.prefixTooltip = 'Type « {prefix} » then Space',
    this.prefixTooltipNoSpace = 'Type « {prefix} »',
  });

  /// English texts.
  static const en = CommandBarStrings(
    dialogLabel: 'Command bar',
    searchHint: 'Search a command',
    recentSection: 'Recent',
    noMatch: 'No matching command',
    filterChip: 'Filter: {filter}, remove with Backspace',
    prefixesHint: 'Prefixes:',
    spaceKey: 'space',
    navigate: 'move',
    open: 'open',
    secondary: 'more',
    close: 'close',
    openCommandBar: 'Open the command bar',
  );

  /// French texts.
  static const fr = CommandBarStrings(
    dialogLabel: 'Barre de commandes',
    searchHint: 'Rechercher une commande',
    recentSection: 'Récents',
    noMatch: 'Aucune commande ne correspond',
    filterChip: 'Filtre : {filter}, retirer avec Retour arrière',
    prefixesHint: 'Préfixes :',
    spaceKey: 'espace',
    navigate: 'naviguer',
    open: 'ouvrir',
    secondary: 'autre action',
    close: 'fermer',
    openCommandBar: 'Ouvrir la barre de commandes',
    prefixTooltip: 'Tape « {prefix} » puis Espace',
    prefixTooltipNoSpace: 'Tape « {prefix} »',
  );

  /// Accessible name of the dialog.
  final String dialogLabel;

  /// Placeholder and accessible name of the search field.
  final String searchHint;

  /// Title of the recently run commands.
  final String recentSection;

  /// Shown when nothing matches and no filter is active.
  final String noMatch;

  /// Accessible name of the filter chip; `{filter}` is the filter label.
  final String filterChip;

  /// Lead-in of the prefix hint shown under an empty field, colon included.
  final String prefixesHint;

  /// Name of the space key in the prefix hint.
  final String spaceKey;

  /// Footer: arrow keys.
  final String navigate;

  /// Footer: Enter.
  final String open;

  /// Footer: Shift+Enter, when the highlighted row has no label of its own.
  final String secondary;

  /// Footer: Escape.
  final String close;

  /// Label of the hotkey in a shortcuts help list.
  final String openCommandBar;

  /// Tooltip of a tappable prefix hint; `{prefix}` is the prefix.
  final String prefixTooltip;

  /// Tooltip of a tappable prefix hint whose filter needs no space.
  final String prefixTooltipNoSpace;

  /// Copy of these texts with the given values replaced.
  CommandBarStrings copyWith({
    String? dialogLabel,
    String? searchHint,
    String? recentSection,
    String? noMatch,
    String? filterChip,
    String? prefixesHint,
    String? spaceKey,
    String? navigate,
    String? open,
    String? secondary,
    String? close,
    String? openCommandBar,
    String? prefixTooltip,
    String? prefixTooltipNoSpace,
  }) => CommandBarStrings(
    dialogLabel: dialogLabel ?? this.dialogLabel,
    searchHint: searchHint ?? this.searchHint,
    recentSection: recentSection ?? this.recentSection,
    noMatch: noMatch ?? this.noMatch,
    filterChip: filterChip ?? this.filterChip,
    prefixesHint: prefixesHint ?? this.prefixesHint,
    spaceKey: spaceKey ?? this.spaceKey,
    navigate: navigate ?? this.navigate,
    open: open ?? this.open,
    secondary: secondary ?? this.secondary,
    close: close ?? this.close,
    openCommandBar: openCommandBar ?? this.openCommandBar,
    prefixTooltip: prefixTooltip ?? this.prefixTooltip,
    prefixTooltipNoSpace: prefixTooltipNoSpace ?? this.prefixTooltipNoSpace,
  );
}
