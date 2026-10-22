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
    this.shortcutsTitle = 'Keyboard shortcuts',
    this.shortcutsPage = 'On this page',
    this.shortcutsEverywhere = 'Everywhere',
    this.shortcutsClose = 'Close',
    this.shortcutsSearchHint = 'Search shortcuts',
    this.shortcutsNoMatch = 'No matching shortcut',
    this.shortcutsOr = 'or',
    this.shortcutsThen = 'then',
    this.shortcutsTypingNote =
        'Shortcuts without Ctrl or Alt pause while you type in a field.',
    this.practice = 'Practice',
    this.practiceCard = 'Card {index} of {count}',
    this.practicePrompt =
        'Press the shortcut from memory. Escape pauses, twice shows the '
        'answer.',
    this.practicePaused =
        'Paused: the keyboard is free. Escape again shows the answer.',
    this.practiceResume = 'Resume',
    this.practiceSelfPrompt =
        'Windows or the app may catch this one before the practice: try it, '
        'then rate yourself.',
    this.practiceRight = 'Right!',
    this.practiceWrong = 'You pressed {keys}. Try again or show the answer.',
    this.practiceShowAnswer = 'Show the answer',
    this.practiceGotIt = 'I got it',
    this.practiceReview = 'To review',
    this.practiceNext = 'Next card',
    this.practiceSummary = '{right} of {count} right',
    this.practiceAgain = 'Review the missed ones',
    this.practiceRestart = 'Start over',
    this.practiceBack = 'Back to the list',
    this.shiftKey = 'Shift',
    this.querySection = 'Recent searches',
    this.fillQuery = 'search again',
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
    shortcutsTitle: 'Raccourcis clavier',
    shortcutsPage: 'Sur cette page',
    shortcutsEverywhere: 'Partout',
    shortcutsClose: 'Fermer',
    shortcutsSearchHint: 'Rechercher un raccourci',
    shortcutsNoMatch: 'Aucun raccourci ne correspond',
    shortcutsOr: 'ou',
    shortcutsThen: 'puis',
    shortcutsTypingNote:
        'Les raccourcis sans Ctrl ni Alt sont en pause pendant la saisie '
        'dans un champ.',
    practice: "S'entraîner",
    practiceCard: 'Carte {index} / {count}',
    practicePrompt:
        'Tape le raccourci de mémoire. Échap : pause, deux fois : la réponse.',
    practicePaused:
        'En pause : le clavier est libre. Échap à nouveau affiche la réponse.',
    practiceResume: 'Reprendre',
    practiceSelfPrompt:
        "Windows ou l'app peut intercepter celui-ci : essaie-le, puis "
        'évalue-toi.',
    practiceRight: 'Bravo !',
    practiceWrong: 'Tu as tapé {keys}. Essaie encore ou affiche la réponse.',
    practiceShowAnswer: 'Afficher la réponse',
    practiceGotIt: "Je l'ai réussi",
    practiceReview: 'À revoir',
    practiceNext: 'Carte suivante',
    practiceSummary: '{right} sur {count} réussis',
    practiceAgain: 'Revoir les ratés',
    practiceRestart: 'Recommencer',
    practiceBack: 'Retour à la liste',
    shiftKey: 'Maj',
    querySection: 'Recherches récentes',
    fillQuery: 'relancer',
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

  /// Title of the shortcuts sheet, also its entry in the bar.
  final String shortcutsTitle;

  /// Shortcuts sheet: group of the current screen's commands.
  final String shortcutsPage;

  /// Shortcuts sheet: group of the app-wide commands.
  final String shortcutsEverywhere;

  /// Shortcuts sheet: close button.
  final String shortcutsClose;

  /// Shortcuts sheet: placeholder of the search field.
  final String shortcutsSearchHint;

  /// Shortcuts sheet: shown when the search matches nothing.
  final String shortcutsNoMatch;

  /// Shortcuts sheet: word between alternatives (`Ctrl+Z` or `Ctrl+Y`).
  final String shortcutsOr;

  /// Shortcuts sheet: word between the keys of a sequence (`G` then `F`).
  final String shortcutsThen;

  /// Shortcuts sheet: note under the list.
  final String shortcutsTypingNote;

  /// Shortcuts sheet: button that starts the practice.
  final String practice;

  /// Practice: progress; `{index}` and `{count}`.
  final String practiceCard;

  /// Practice: what to do on a card.
  final String practicePrompt;

  /// Practice: Escape paused the card.
  final String practicePaused;

  /// Practice: listens to the keys again after a pause.
  final String practiceResume;

  /// Practice: a card whose keys cannot be checked here.
  final String practiceSelfPrompt;

  /// Practice: the keys were right.
  final String practiceRight;

  /// Practice: wrong keys; `{keys}` is what was pressed.
  final String practiceWrong;

  /// Practice: reveals the keys (the card goes to review).
  final String practiceShowAnswer;

  /// Practice: self-rating, success.
  final String practiceGotIt;

  /// Practice: self-rating, to review.
  final String practiceReview;

  /// Practice: next card.
  final String practiceNext;

  /// Practice: score at the end; `{right}` and `{count}`.
  final String practiceSummary;

  /// Practice: restarts with the cards to review.
  final String practiceAgain;

  /// Practice: restarts with every card.
  final String practiceRestart;

  /// Practice: back to the shortcuts list.
  final String practiceBack;

  /// Name of the Shift key, in typed keys.
  final String shiftKey;

  /// Title of the recently typed searches, listed under an empty field.
  final String querySection;

  /// Footer: Enter on a recent search, which puts it back in the field.
  final String fillQuery;

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
    String? shortcutsTitle,
    String? shortcutsPage,
    String? shortcutsEverywhere,
    String? shortcutsClose,
    String? shortcutsSearchHint,
    String? shortcutsNoMatch,
    String? shortcutsOr,
    String? shortcutsThen,
    String? shortcutsTypingNote,
    String? practice,
    String? practiceCard,
    String? practicePrompt,
    String? practicePaused,
    String? practiceResume,
    String? practiceSelfPrompt,
    String? practiceRight,
    String? practiceWrong,
    String? practiceShowAnswer,
    String? practiceGotIt,
    String? practiceReview,
    String? practiceNext,
    String? practiceSummary,
    String? practiceAgain,
    String? practiceRestart,
    String? practiceBack,
    String? shiftKey,
    String? querySection,
    String? fillQuery,
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
    shortcutsTitle: shortcutsTitle ?? this.shortcutsTitle,
    shortcutsPage: shortcutsPage ?? this.shortcutsPage,
    shortcutsEverywhere: shortcutsEverywhere ?? this.shortcutsEverywhere,
    shortcutsClose: shortcutsClose ?? this.shortcutsClose,
    shortcutsSearchHint: shortcutsSearchHint ?? this.shortcutsSearchHint,
    shortcutsNoMatch: shortcutsNoMatch ?? this.shortcutsNoMatch,
    shortcutsOr: shortcutsOr ?? this.shortcutsOr,
    shortcutsThen: shortcutsThen ?? this.shortcutsThen,
    shortcutsTypingNote: shortcutsTypingNote ?? this.shortcutsTypingNote,
    practice: practice ?? this.practice,
    practiceCard: practiceCard ?? this.practiceCard,
    practicePrompt: practicePrompt ?? this.practicePrompt,
    practicePaused: practicePaused ?? this.practicePaused,
    practiceResume: practiceResume ?? this.practiceResume,
    practiceSelfPrompt: practiceSelfPrompt ?? this.practiceSelfPrompt,
    practiceRight: practiceRight ?? this.practiceRight,
    practiceWrong: practiceWrong ?? this.practiceWrong,
    practiceShowAnswer: practiceShowAnswer ?? this.practiceShowAnswer,
    practiceGotIt: practiceGotIt ?? this.practiceGotIt,
    practiceReview: practiceReview ?? this.practiceReview,
    practiceNext: practiceNext ?? this.practiceNext,
    practiceSummary: practiceSummary ?? this.practiceSummary,
    practiceAgain: practiceAgain ?? this.practiceAgain,
    practiceRestart: practiceRestart ?? this.practiceRestart,
    practiceBack: practiceBack ?? this.practiceBack,
    shiftKey: shiftKey ?? this.shiftKey,
    querySection: querySection ?? this.querySection,
    fillQuery: fillQuery ?? this.fillQuery,
  );
}
