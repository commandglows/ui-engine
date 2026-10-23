import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Texts of the introduction's frame. The app picks the language: use [en],
/// [fr], [forLocale], or its own values. Page texts come with the pages.
@immutable
class OnboardingStrings {
  const OnboardingStrings({
    required this.progress,
    required this.goToStep,
    required this.back,
    required this.next,
    required this.skip,
    required this.finish,
  });

  /// Screen-reader label of the progress bar.
  final String progress;

  /// Label of one progress segment: `{step}`.
  final String goToStep;
  final String back;
  final String next;

  /// Jumps to the last page.
  final String skip;

  /// Primary action of the last page.
  final String finish;

  static const en = OnboardingStrings(
    progress: 'Introduction progress',
    goToStep: 'Go to step {step}',
    back: 'Back',
    next: 'Next',
    skip: 'Skip introduction',
    finish: 'Let’s go!',
  );

  static const fr = OnboardingStrings(
    progress: 'Progression de l’introduction',
    goToStep: 'Aller à l’étape {step}',
    back: 'Retour',
    next: 'Suivant',
    skip: 'Passer l’introduction',
    finish: 'C’est parti !',
  );

  static OnboardingStrings forLocale(Locale locale) =>
      locale.languageCode == 'fr' ? fr : en;
}
