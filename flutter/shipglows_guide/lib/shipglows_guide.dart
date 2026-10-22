/// In-app guidance for ShipGlows Flutter apps.
///
/// - [GuideTour] and [GuideStep]: a sequence of explanations, each one
///   optionally pointing at a [GuideTarget] and opening a route.
/// - [GuideController]: the running tour, progress kept in a [GuideStore].
/// - [GuideScope]: draws the card, the spotlight around the target and keeps
///   the targets of the screens below it.
/// - [GuideTarget]: marks a widget a step can point at.
/// - [GuideTrigger]: starts a tour the first time a screen is shown.
library;

export 'src/guide_controller.dart';
export 'src/guide_progress.dart';
export 'src/guide_scope.dart';
export 'src/guide_step.dart';
export 'src/guide_strings.dart';
export 'src/guide_theme.dart';
