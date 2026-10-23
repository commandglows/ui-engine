import 'package:flutter/foundation.dart';
import 'package:shipglows_menu/shipglows_menu_model.dart';

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
    this.allFilters = 'All',
    this.switchFilter = 'change type',
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
    this.hotkeyChange = 'Change the shortcut',
    this.hotkeyPress = 'Press the keys…',
    this.hotkeyInvalid = 'Add Ctrl, Alt or Win to the key',
    this.hotkeyReset = 'Restore the default shortcut',
    this.queryActionsSection = 'With this text',
    this.entryKinds = const <String, String>{
      'open': 'Opens a screen of the app',
      'action': 'Runs right here',
      'app': 'Opens another app',
    },
    this.entryKindLabels = const <String, String>{
      'open': 'Screen',
      'action': 'Action',
      'app': 'App',
    },
    this.actions = 'actions',
    this.actionsPanel = 'Actions of « {label} »',
    this.confirmAction = 'Press again to confirm',
    this.menu = ShipglowsMenuStrings.en,
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
    allFilters: 'Tous',
    switchFilter: 'changer de type',
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
    hotkeyChange: 'Changer le raccourci',
    hotkeyPress: 'Appuie sur les touches…',
    hotkeyInvalid: 'Ajoute Ctrl, Alt ou Win à la touche',
    hotkeyReset: 'Rétablir le raccourci par défaut',
    queryActionsSection: 'Avec ce texte',
    entryKinds: <String, String>{
      'open': 'Ouvre un écran de l’app',
      'action': 'S’exécute ici',
      'app': 'Ouvre une autre app',
    },
    entryKindLabels: <String, String>{
      'open': 'Ouvre un écran',
      'action': 'Action',
      'app': 'App',
    },
    actions: 'actions',
    actionsPanel: 'Actions de « {label} »',
    confirmAction: 'Appuie encore pour confirmer',
    menu: ShipglowsMenuStrings.fr,
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

  /// Tooltip of a filter button; `{prefix}` is the prefix.
  final String prefixTooltip;

  /// Tooltip of a filter button whose filter needs no space.
  final String prefixTooltipNoSpace;

  /// Filter row: the button that removes the filter.
  final String allFilters;

  /// Footer: left and right arrows, which step through the filter row.
  final String switchFilter;

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

  /// Hotkey field: accessible name of the button that records a new one.
  final String hotkeyChange;

  /// Hotkey field: shown while it waits for the keys.
  final String hotkeyPress;

  /// Hotkey field: the keys pressed cannot open the bar.
  final String hotkeyInvalid;

  /// Hotkey field: tooltip of the button back to the default.
  final String hotkeyReset;

  /// Title of the actions that use the typed text (see
  /// [CommandBarEntry.usesQuery]), listed after the matches.
  final String queryActionsSection;

  /// What each [CommandBarEntryKind] does, by its id: the tooltip of its
  /// marker, and read aloud with the row. An app adds its own kinds here.
  final Map<String, String> entryKinds;

  /// Short name of each [CommandBarEntryKind], by its id, written at the end
  /// of the row when [CommandBarBehavior.kindDisplay] asks for text. Falls
  /// back to [entryKinds].
  final Map<String, String> entryKindLabels;

  /// Footer: Alt+Enter, which opens the actions panel of the row.
  final String actions;

  /// Title and accessible name of the actions panel; `{label}` is the
  /// entry's label.
  final String actionsPanel;

  /// Replaces the label of a [CommandBarEntryAction.confirm] action once it
  /// was chosen once in the actions panel: choosing it again runs it.
  final String confirmAction;

  /// Texts of the action menus (an entry's actions, the app menu): search
  /// field, empty result, standard entries.
  final ShipglowsMenuStrings menu;

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
    String? allFilters,
    String? switchFilter,
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
    String? hotkeyChange,
    String? hotkeyPress,
    String? hotkeyInvalid,
    String? hotkeyReset,
    String? queryActionsSection,
    Map<String, String>? entryKinds,
    Map<String, String>? entryKindLabels,
    String? actions,
    String? actionsPanel,
    String? confirmAction,
    ShipglowsMenuStrings? menu,
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
    allFilters: allFilters ?? this.allFilters,
    switchFilter: switchFilter ?? this.switchFilter,
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
    hotkeyChange: hotkeyChange ?? this.hotkeyChange,
    hotkeyPress: hotkeyPress ?? this.hotkeyPress,
    hotkeyInvalid: hotkeyInvalid ?? this.hotkeyInvalid,
    hotkeyReset: hotkeyReset ?? this.hotkeyReset,
    queryActionsSection: queryActionsSection ?? this.queryActionsSection,
    entryKinds: entryKinds ?? this.entryKinds,
    entryKindLabels: entryKindLabels ?? this.entryKindLabels,
    actions: actions ?? this.actions,
    actionsPanel: actionsPanel ?? this.actionsPanel,
    menu: menu ?? this.menu,
    confirmAction: confirmAction ?? this.confirmAction,
  );
}
