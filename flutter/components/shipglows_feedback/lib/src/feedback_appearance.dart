import 'package:flutter/widgets.dart';

import 'feedback_kind.dart';

/// How an app dresses and places its message snack bars, where the shared look
/// does not suit it. Anything left null keeps the default.
@immutable
class FeedbackAppearance {
  const FeedbackAppearance({
    this.background,
    this.foreground,
    this.border,
    this.action,
    this.iconColorOf,
    this.margin,
  });

  /// Fill of the snack bar; defaults to `surfaceRaised`.
  final Color? background;

  /// Message text and close icon; defaults to `text` and `icon`.
  final Color? foreground;

  /// Outline; defaults to `border`.
  final Color? border;

  /// Action labels; defaults to `accent`.
  final Color? action;

  /// Icon color of each kind; defaults to [FeedbackKind.colorOf]. Set it with
  /// [background]: the kind colors are chosen for `surfaceRaised`.
  final Color Function(FeedbackKind kind)? iconColorOf;

  /// Where the snack bar floats inside its scaffold, read as each one is built
  /// (a side panel may come and go). Null keeps it centered, at most
  /// `kFeedbackMaxWidth` wide.
  final EdgeInsetsGeometry? Function()? margin;
}

/// Gives the messages below it an app's [FeedbackAppearance].
class FeedbackAppearanceScope extends InheritedWidget {
  const FeedbackAppearanceScope({
    super.key,
    required this.appearance,
    required super.child,
  });

  final FeedbackAppearance appearance;

  /// The appearance above [context], null without a scope. Safe outside build:
  /// a message is built once, so nothing needs to depend on it.
  static FeedbackAppearance? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<FeedbackAppearanceScope>()
      ?.appearance;

  @override
  bool updateShouldNotify(FeedbackAppearanceScope oldWidget) =>
      appearance != oldWidget.appearance;
}
