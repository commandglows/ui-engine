import 'dart:ui';

import 'package:flutter/foundation.dart';

/// Texts of the guide card. The app picks the language: use [en], [fr],
/// [forLocale], or its own values.
@immutable
class GuideStrings {
  const GuideStrings({
    required this.progress,
    required this.tip,
    required this.previous,
    required this.next,
    required this.finish,
    required this.gotIt,
    required this.skip,
    required this.pause,
    required this.close,
    required this.open,
    required this.tryIt,
  });

  /// Header of a tour: `{current}`, `{total}`.
  final String progress;

  /// Header of a one-step tour.
  final String tip;
  final String previous;
  final String next;
  final String finish;

  /// Closes a one-step tour.
  final String gotIt;
  final String skip;

  /// Close button of a tour (it can be resumed).
  final String pause;

  /// Close button of a one-step tour.
  final String close;

  /// Opens the step's route: `{screen}`.
  final String open;

  /// Shown on steps that move on when the target is tapped.
  final String tryIt;

  static const en = GuideStrings(
    progress: 'Guided tour · {current}/{total}',
    tip: 'Tip',
    previous: 'Previous',
    next: 'Next',
    finish: 'Finish',
    gotIt: 'Got it',
    skip: 'Skip tour',
    pause: 'Pause tour',
    close: 'Close',
    open: 'Open {screen}',
    tryIt: 'Try it: use the highlighted control.',
  );

  static const fr = GuideStrings(
    progress: 'Visite guidée · {current}/{total}',
    tip: 'Astuce',
    previous: 'Précédent',
    next: 'Suivant',
    finish: 'Terminer',
    gotIt: 'Compris',
    skip: 'Passer la visite',
    pause: 'Mettre en pause la visite',
    close: 'Fermer',
    open: 'Ouvrir {screen}',
    tryIt: 'Essaie : utilise la commande en surbrillance.',
  );

  static GuideStrings forLocale(Locale locale) =>
      locale.languageCode == 'fr' ? fr : en;
}
