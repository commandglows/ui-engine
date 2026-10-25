import 'package:flutter/widgets.dart';

/// One page of the introduction: the left column's texts and actions, the
/// right column's [preview].
@immutable
class OnboardingPage {
  const OnboardingPage({
    required this.id,
    this.title,
    this.eyebrow,
    this.leading,
    this.description,
    this.descriptionLines,
    this.note,
    this.body,
    this.preview,
    this.centered = false,
    this.scrollable = false,
    this.showBack = true,
    this.showSkip = true,
    this.showPrimary = true,
    this.primaryLabel,
    this.primaryArrow,
  });

  /// Stable id: keys the page transitions.
  final String id;

  /// Null when the [body] brings its own heading (an embedded sign-in form).
  final String? title;

  /// Small uppercase line above the title (`What you can do · 2/6`).
  final String? eyebrow;

  /// Above the title: an icon badge, the app's mark.
  final Widget? leading;
  final String? description;

  /// Lines kept for [description] even when it is shorter, so the pages of a
  /// series keep their title and actions in place.
  final int? descriptionLines;

  /// Quieter italic paragraph under the description (a word from the maker).
  final String? note;

  /// Anything else under the texts: a status, bullet points, links.
  final Widget? body;

  /// Right column on wide layouts; hidden on narrow ones.
  final WidgetBuilder? preview;

  /// Centers the texts vertically, for feature pages.
  final bool centered;

  /// Lets the texts scroll inside the card, for a page whose [body] can grow.
  final bool scrollable;
  final bool showBack;

  /// Shows Skip, which jumps to the last page. Never shown on the last page.
  final bool showSkip;

  /// Hides the primary action when the [body] owns the way forward (a sign-in
  /// form, a start-trial panel).
  final bool showPrimary;

  /// Primary label (default: Next, or Finish on the last page).
  final String? primaryLabel;

  /// Arrow after the primary label (default: on every page but the last).
  final bool? primaryArrow;
}

/// A language the user can pick on an [OnboardingLanguagePage].
@immutable
class OnboardingLanguageOption {
  const OnboardingLanguageOption({
    required this.locale,
    required this.label,
    required this.greeting,
  });

  final Locale locale;

  /// Button label, in its own language (`Français`).
  final String label;

  /// Word of the specimen in the preview (`Bonjour`).
  final String greeting;
}

/// First page: one button per language, no other action. Picking one calls
/// [onSelected] and moves to the next page.
@immutable
class OnboardingLanguagePage extends OnboardingPage {
  const OnboardingLanguagePage({
    required super.id,
    required String super.title,
    super.description,
    super.leading,
    required this.options,
    required this.onSelected,
  }) : super(showBack: false, showSkip: false);

  final List<OnboardingLanguageOption> options;
  final ValueChanged<Locale> onSelected;
}
