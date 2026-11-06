/// In-app messages for ShipGlows Flutter apps: info, success, warning and
/// error, one look and one queue everywhere.
///
/// - [showFeedback] (or `context.showInfo` / `showSuccess` / `showWarning` /
///   `showError`): a floating snack bar drawn from `ShipglowsTheme`; the
///   same message already on screen is not queued twice; errors can offer
///   « Copy details ».
/// - [FeedbackMessenger]: read before an await, show after.
/// - [feedbackSnackBar]: the same snack bar for code that shows it itself
///   (the « Undo » snack bar of `shipglows_undo_trash`).
/// - [FeedbackInline]: a message shown in place, announced.
/// - [FeedbackErrorState]: a screen whose loading failed, with « Retry ».
/// - [FeedbackContent]: icon and text of a message, for an app's own surface.
/// - [FeedbackStrings] and [FeedbackStringsScope]: the app's texts.
/// - [FeedbackAppearance] and [FeedbackAppearanceScope]: an app's own colors
///   and placement for the snack bar.
/// - [FeedbackLog]: every message shown, for a history of past messages.
library;

export 'src/feedback_appearance.dart';
export 'src/feedback_content.dart';
export 'src/feedback_error_state.dart';
export 'src/feedback_kind.dart';
export 'src/feedback_log.dart';
export 'src/feedback_snack_bar.dart';
export 'src/strings.dart';
