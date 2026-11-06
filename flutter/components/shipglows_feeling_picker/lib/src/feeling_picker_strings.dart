/// Every string of the picker. Use a preset, or your own for your app's voice.
class FeelingPickerStrings {
  /// Creates a set of strings.
  const FeelingPickerStrings({
    required this.seeAll,
    required this.sheetTitle,
    required this.done,
    required this.searchHint,
    required this.selectedTitle,
    required this.noResult,
    required this.addCustom,
    required this.limitReached,
  });

  /// French.
  static const fr = FeelingPickerStrings(
    seeAll: 'Voir tous les mots',
    sheetTitle: 'Mettre des mots sur ce que je ressens',
    done: 'Terminé',
    searchHint: 'Chercher un mot',
    selectedTitle: 'Mes mots',
    noResult: 'Aucun mot de la liste ne correspond.',
    addCustom: _addCustomFr,
    limitReached: _limitFr,
  );

  /// English.
  static const en = FeelingPickerStrings(
    seeAll: 'See all the words',
    sheetTitle: 'Put words on what I feel',
    done: 'Done',
    searchHint: 'Search for a word',
    selectedTitle: 'My words',
    noResult: 'No word on the list matches.',
    addCustom: _addCustomEn,
    limitReached: _limitEn,
  );

  /// The preset for [languageCode]: French for `fr`, English otherwise.
  static FeelingPickerStrings of(String languageCode) =>
      languageCode == 'fr' ? fr : en;

  /// Button opening the sheet.
  final String seeAll;

  /// Title of the sheet.
  final String sheetTitle;

  /// Button closing the sheet.
  final String done;

  /// Hint of the search field.
  final String searchHint;

  /// Heading above the picked words.
  final String selectedTitle;

  /// Shown when a search finds nothing.
  final String noResult;

  /// Button adding the searched text as the person's own word.
  final String Function(String text) addCustom;

  /// Shown once the limit is reached.
  final String Function(int max) limitReached;
}

String _addCustomFr(String text) => 'Ajouter « $text » comme mon mot';

String _addCustomEn(String text) => 'Add “$text” as my own word';

String _limitFr(int max) =>
    '$max mots au plus. Retires-en un pour en choisir un autre.';

String _limitEn(int max) => '$max words at most. Remove one to pick another.';
