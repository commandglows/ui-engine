import 'package:flutter/widgets.dart';

import 'feedback_kind.dart';

/// Texts of the messages: the kind a screen reader says before a message
/// (the icon and color say it on screen) and the labels of the copy and
/// retry actions. The app picks the language: [en], [fr], or its own values,
/// once for the app with [FeedbackStringsScope]. The close button tooltip
/// comes from `MaterialLocalizations`.
@immutable
class FeedbackStrings {
  const FeedbackStrings({
    required this.info,
    required this.success,
    required this.warning,
    required this.error,
    this.copyDetails = 'Copy details',
    this.detailsCopied = 'Details copied',
    this.retry = 'Retry',
  });

  final String info;
  final String success;
  final String warning;
  final String error;

  /// Action of an error that has details to copy.
  final String copyDetails;

  /// Shown once the details are on the clipboard.
  final String detailsCopied;

  /// Default button of [FeedbackErrorState].
  final String retry;

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
    copyDetails: 'Copier le détail',
    detailsCopied: 'Détail copié',
    retry: 'Réessayer',
  );

  /// The [FeedbackStringsScope] above [context]; without one, [fr] when the
  /// app locale is French, [en] otherwise.
  static FeedbackStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<FeedbackStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

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
    String? copyDetails,
    String? detailsCopied,
    String? retry,
  }) => FeedbackStrings(
    info: info ?? this.info,
    success: success ?? this.success,
    warning: warning ?? this.warning,
    error: error ?? this.error,
    copyDetails: copyDetails ?? this.copyDetails,
    detailsCopied: detailsCopied ?? this.detailsCopied,
    retry: retry ?? this.retry,
  );
}

/// The app's own [FeedbackStrings] for every message below it, set once
/// (in `MaterialApp.builder`, say) instead of per call.
class FeedbackStringsScope extends InheritedWidget {
  const FeedbackStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final FeedbackStrings strings;

  @override
  bool updateShouldNotify(FeedbackStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
