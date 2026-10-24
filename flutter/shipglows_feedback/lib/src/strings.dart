import 'package:flutter/widgets.dart';

import 'feedback_kind.dart';

/// The kind a screen reader says before a message (the icon and color say
/// it on screen). The app picks the language: [en], [fr], or its own values.
/// The close button tooltip comes from `MaterialLocalizations`.
@immutable
class FeedbackStrings {
  const FeedbackStrings({
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
  });

  final String info;
  final String success;
  final String warning;
  final String error;

  static const en = FeedbackStrings(
    info: 'Information',
    success: 'Success',
    warning: 'Warning',
    error: 'Error',
  );

  static const fr = FeedbackStrings(
    info: 'Information',
    success: 'Succès',
    warning: 'Avertissement',
    error: 'Erreur',
  );

  /// [fr] when the app locale is French, [en] otherwise.
  static FeedbackStrings of(BuildContext context) =>
      Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en;

  /// The spoken name of [kind].
  String labelOf(FeedbackKind kind) => switch (kind) {
    FeedbackKind.info => info,
    FeedbackKind.success => success,
    FeedbackKind.warning => warning,
    FeedbackKind.error => error,
  };

  FeedbackStrings copyWith({
    String? info,
    String? success,
    String? warning,
    String? error,
  }) => FeedbackStrings(
    info: info ?? this.info,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
  );
}
