import 'package:flutter/foundation.dart';

/// One explanation of a tour.
///
/// Texts are the app's own: plain text, or keys the [GuideScope]'s
/// `resolveText` turns into text in the current language.
@immutable
class GuideStep {
  const GuideStep({
    required this.id,
    required this.title,
    required this.body,
    this.hint,
    this.targetId,
    this.route,
    this.routeLabel,
    this.spotlight = true,
    this.advanceOnTargetTap = false,
  });

  final String id;
  final String title;
  final String body;

  /// Optional one-line call to action shown above the buttons.
  final String? hint;

  /// Id of the [GuideTarget] this step points at. When that target is not on
  /// screen, the card floats at the bottom instead.
  final String? targetId;

  /// Route opened when this step becomes active (null: stay where the user
  /// is). The card offers « Open {routeLabel} » when the user left it.
  final String? route;

  /// Name of the [route]'s screen for the « Open » button; the [title] when
  /// null.
  final String? routeLabel;

  /// Dims everything but the target, which stays usable. Off: only a ring
  /// around the target, the rest of the screen keeps working.
  final bool spotlight;

  /// Invites the user to try the target: tapping it moves to the next step.
  final bool advanceOnTargetTap;
}

/// A sequence of [GuideStep]s. A tour of one step is a tip: no progress bar,
/// « Got it » closes it for good.
@immutable
class GuideTour {
  const GuideTour({required this.id, required this.steps});

  /// Stable id, used to persist progress.
  final String id;

  /// Never empty.
  final List<GuideStep> steps;

  bool get isTip => steps.length == 1;
}
