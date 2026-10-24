/// In-app messages for ShipGlows Flutter apps: info, success, warning and
/// error, one look and one queue everywhere.
///
/// - [showFeedback] (or `context.showInfo` / `showSuccess` / `showWarning` /
///   `showError`): a floating snack bar drawn from `ShipglowsTheme`; the
///   same message already on screen is not queued twice.
/// - [feedbackSnackBar]: the same snack bar for code that shows it itself
///   (the « Undo » snack bar of `shipglows_undo_trash`).
/// - [FeedbackContent]: icon and text of a message, for an app's own surface.
/// - [FeedbackStrings]: what a screen reader says before the message.
library;

export 'src/feedback_content.dart';
export 'src/feedback_kind.dart';
export 'src/feedback_snack_bar.dart';
export 'src/strings.dart';
