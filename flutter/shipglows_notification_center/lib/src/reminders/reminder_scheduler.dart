import 'package:flutter/foundation.dart';

/// One system notification planned for a moment.
@immutable
class ScheduledReminder {
  const ScheduledReminder({
    required this.at,
    required this.title,
    this.body,
    this.payload,
  });

  /// Local time it goes off.
  final DateTime at;
  final String title;
  final String? body;

  /// Handed back when the notification is opened.
  final String? payload;
}

/// Plans system notifications (Windows toasts, Android notifications) that
/// show even while the app is closed.
abstract interface class ReminderScheduler {
  /// False where nothing can be planned (web, unsupported platforms).
  bool get isSupported;

  /// Asks the system once (Android 13+); true when notifications may show.
  Future<bool> requestPermission();

  /// Replaces every notification this scheduler planned before by
  /// [reminders]; an empty list cancels them all.
  Future<void> replaceAll(List<ScheduledReminder> reminders);
}

/// Keeps the plan in memory: tests, demos, previews.
class MemoryReminderScheduler implements ReminderScheduler {
  MemoryReminderScheduler({this.isSupported = true, this.granted = true});

  @override
  final bool isSupported;

  /// What [requestPermission] answers.
  bool granted;

  List<ScheduledReminder> scheduled = const [];

  @override
  Future<bool> requestPermission() async => granted;

  @override
  Future<void> replaceAll(List<ScheduledReminder> reminders) async =>
      scheduled = List.unmodifiable(reminders);
}
