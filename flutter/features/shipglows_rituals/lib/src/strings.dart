import 'package:flutter/widgets.dart';

enum RitualText {
  daily,
  weekly,
  weekPeriod,
  start,
  reread,
  resume,
  customize,
  completed,
  draft,
  discardTitle,
  discardMessage,
  continueWriting,
  discard,
  pageIntro,
  snapshot,
  references,
  unavailableReference,
  pageSaveFailure,
  clearResponse,
  chooseResponse,
  invalidNumber,
  fixInvalidAnswers,
  stepProgress,
  back,
  next,
  close,
  saveDraft,
  saving,
  saveChanges,
  finish,
  editorTitle,
  editorIntro,
  richTemplateHint,
  modelName,
  requiredName,
  modelPurpose,
  weeklyPage,
  cadenceHint,
  questions,
  questionHint,
  steps,
  stepHint,
  fieldCount,
  templateSaveFailure,
  cancel,
  saveTemplate,
}

/// Built-in English/French copy, with host overrides for product vocabulary.
class RitualStrings {
  const RitualStrings({this.languageCode = 'en', this.overrides = const {}});
  static const en = RitualStrings();
  static const fr = RitualStrings(languageCode: 'fr');

  final String languageCode;
  final Map<RitualText, String> overrides;

  static RitualStrings of(BuildContext context) =>
      Localizations.localeOf(context).languageCode == 'fr' ? fr : en;

  RitualStrings copyWith({Map<RitualText, String> overrides = const {}}) =>
      RitualStrings(
        languageCode: languageCode,
        overrides: {...this.overrides, ...overrides},
      );

  String call(RitualText key) =>
      overrides[key] ?? (languageCode == 'fr' ? _fr[key] : _en[key])!;

  String format(RitualText key, Map<String, String> values) {
    var text = call(key);
    for (final entry in values.entries) {
      text = text.replaceAll('{${entry.key}}', entry.value);
    }
    return text;
  }
}

const _en = {
  RitualText.daily: 'Daily',
  RitualText.weekly: 'Weekly',
  RitualText.weekPeriod: 'Week of {start} – {end}',
  RitualText.start: 'Start',
  RitualText.reread: 'Read and edit',
  RitualText.resume: 'Resume draft',
  RitualText.customize: 'Customize template',
  RitualText.completed: 'Completed for this period',
  RitualText.draft: 'Draft saved',
  RitualText.discardTitle: 'Leave without saving?',
  RitualText.discardMessage: 'Your latest changes have not been saved.',
  RitualText.continueWriting: 'Keep writing',
  RitualText.discard: 'Leave without saving',
  RitualText.pageIntro:
      'Every answer is optional. Save a draft to come back later.',
  RitualText.snapshot: 'This page keeps the template it started with.',
  RitualText.references: 'Associated items',
  RitualText.unavailableReference:
      'An associated item is unavailable; its reference is retained.',
  RitualText.pageSaveFailure:
      'The page was not saved. Your answers are still here; you can retry.',
  RitualText.clearResponse: 'Clear response',
  RitualText.chooseResponse: 'Choose a response',
  RitualText.invalidNumber: 'Enter a valid number within the allowed range.',
  RitualText.fixInvalidAnswers: 'Fix the highlighted answers before saving.',
  RitualText.stepProgress: 'Step {current} of {total}',
  RitualText.back: 'Back',
  RitualText.next: 'Next',
  RitualText.close: 'Close',
  RitualText.saveDraft: 'Save draft',
  RitualText.saving: 'Saving…',
  RitualText.saveChanges: 'Save changes',
  RitualText.finish: 'Finish ritual',
  RitualText.editorTitle: 'My ritual template',
  RitualText.editorIntro:
      'Changes apply to new pages. Pages already started keep their questions.',
  RitualText.richTemplateHint: 'Questions, choices and conditions are defined by the app and will be preserved when you save.',
  RitualText.modelName: 'Template name',
  RitualText.requiredName: 'Give your template a name.',
  RitualText.modelPurpose: 'What will this ritual help you with?',
  RitualText.weeklyPage: 'One page per week',
  RitualText.cadenceHint:
      'Otherwise, one page per day. Start it whenever you want.',
  RitualText.questions: 'Questions',
  RitualText.questionHint: 'One question per line.',
  RitualText.steps: 'Checklist steps',
  RitualText.stepHint: 'One step per line.',
  RitualText.fieldCount: 'Add between 1 and 40 questions or steps.',
  RitualText.templateSaveFailure:
      'The template was not saved. Your changes are still here; try again.',
  RitualText.cancel: 'Cancel',
  RitualText.saveTemplate: 'Save template',
};

const _fr = {
  RitualText.daily: 'Quotidien',
  RitualText.weekly: 'Hebdomadaire',
  RitualText.weekPeriod: 'Semaine du {start} au {end}',
  RitualText.start: 'Commencer',
  RitualText.reread: 'Relire et modifier',
  RitualText.resume: 'Reprendre le brouillon',
  RitualText.customize: 'Personnaliser le modèle',
  RitualText.completed: 'Terminé pour cette période',
  RitualText.draft: 'Brouillon enregistré',
  RitualText.discardTitle: 'Quitter sans enregistrer ?',
  RitualText.discardMessage:
      'Tes dernières modifications ne sont pas enregistrées.',
  RitualText.continueWriting: 'Continuer à écrire',
  RitualText.discard: 'Quitter sans enregistrer',
  RitualText.pageIntro: 'Chaque réponse est facultative. Enregistre un brouillon pour reprendre plus tard.',
  RitualText.snapshot: 'Cette page garde le modèle utilisé à sa création.',
  RitualText.references: 'Éléments associés',
  RitualText.unavailableReference:
      'Un élément associé est indisponible ; son lien est conservé.',
  RitualText.pageSaveFailure: 'La page n’a pas été enregistrée. Tes réponses sont conservées ici ; tu peux réessayer.',
  RitualText.clearResponse: 'Effacer la réponse',
  RitualText.chooseResponse: 'Choisir une réponse',
  RitualText.invalidNumber:
      'Saisis un nombre valide dans les limites autorisées.',
  RitualText.fixInvalidAnswers:
      'Corrige les réponses signalées avant d’enregistrer.',
  RitualText.stepProgress: 'Étape {current} sur {total}',
  RitualText.back: 'Retour',
  RitualText.next: 'Suivant',
  RitualText.close: 'Fermer',
  RitualText.saveDraft: 'Enregistrer le brouillon',
  RitualText.saving: 'Enregistrement…',
  RitualText.saveChanges: 'Enregistrer les modifications',
  RitualText.finish: 'Terminer le rituel',
  RitualText.editorTitle: 'Mon modèle de rituel',
  RitualText.editorIntro: 'Ces changements serviront aux nouvelles pages. Tes pages déjà commencées gardent leurs questions.',
  RitualText.richTemplateHint: 'Les questions, choix et conditions sont définis par l’application et seront conservés à l’enregistrement.',
  RitualText.modelName: 'Nom du modèle',
  RitualText.requiredName: 'Donne un nom à ton modèle.',
  RitualText.modelPurpose: 'À quoi ce rituel va-t-il t’aider ?',
  RitualText.weeklyPage: 'Une page par semaine',
  RitualText.cadenceHint:
      'Sinon, une page par jour. Tu la commences quand tu veux.',
  RitualText.questions: 'Questions',
  RitualText.questionHint: 'Une question par ligne.',
  RitualText.steps: 'Étapes à cocher',
  RitualText.stepHint: 'Une étape par ligne.',
  RitualText.fieldCount: 'Ajoute entre 1 et 40 questions ou étapes.',
  RitualText.templateSaveFailure: 'Le modèle n’a pas été enregistré. Tes modifications restent ici ; réessaie.',
  RitualText.cancel: 'Annuler',
  RitualText.saveTemplate: 'Enregistrer le modèle',
};
