import 'package:flutter/foundation.dart';

import 'feedback_kind.dart';

/// A message as it was shown, for a history of past messages (an error
/// that went by too fast).
@immutable
class FeedbackRecord {
  const FeedbackRecord({
    required this.message,
    required this.kind,
    required this.shownAt,
    this.details,
  });

  final String message;
  final FeedbackKind kind;
  final DateTime shownAt;

  /// The technical details of an error, read when the message was shown.
  final String? details;
}

/// Hears every message shown through [FeedbackMessenger.show] (and so
/// `showFeedback`, `context.showError`…), once, when it reaches the queue:
/// a repeat that is not queued is not heard again. The snack bars an app
/// builds itself with `feedbackSnackBar` are not heard.
///
/// `shipglows_notification_center` keeps them in its `FeedbackHistory`.
abstract final class FeedbackLog {
  static final List<void Function(FeedbackRecord record)> _listeners = [];

  static void addListener(void Function(FeedbackRecord record) listener) =>
      _listeners.add(listener);

  static void removeListener(void Function(FeedbackRecord record) listener) =>
      _listeners.remove(listener);

  /// Whether anyone listens: details are only read then.
  static bool get hasListeners => _listeners.isNotEmpty;

  static void record(FeedbackRecord record) {
    for (final listener in List.of(_listeners)) {
      listener(record);
    }
  }
}
