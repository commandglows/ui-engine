import 'package:flutter/foundation.dart';

import 'daily_reminder_plan.dart';
import 'reminder_scheduler.dart';

/// Title, text and payload of the reminder planned at a [ReminderTime].
typedef ReminderContent =
    ({String title, String? body, String? payload}) Function(
      ReminderTime time,
    );

/// The person's [DailyReminderPlan], kept by the app ([load], [save]) and
/// turned into system notifications by a [ReminderScheduler].
///
/// Call [start] once the app runs: it plans the next [days] days, so the
/// reminders keep coming as long as the app is opened now and then.
class DailyReminders extends ChangeNotifier {
  DailyReminders({
    required this.scheduler,
    required this.load,
    required this.save,
    required this.content,
    this.days = 7,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ReminderScheduler scheduler;
  final Future<DailyReminderPlan> Function() load;
  final Future<void> Function(DailyReminderPlan plan) save;
  final ReminderContent content;

  /// How far ahead reminders are planned.
  final int days;
  final DateTime Function() _now;

  DailyReminderPlan _plan = DailyReminderPlan();
  DailyReminderPlan get plan => _plan;

  bool _permissionDenied = false;

  /// The system refused notifications when they were turned on.
  bool get permissionDenied => _permissionDenied;

  Object? _error;

  /// The last failure to plan, cleared by the next success.
  Object? get error => _error;

  bool get isSupported => scheduler.isSupported;

  /// Reads the plan and plans the coming days again.
  Future<void> start() async {
    if (!isSupported) return;
    _plan = await load();
    notifyListeners();
    await _schedule();
  }

  /// Applies [next] at once, then saves and plans it. Turning reminders on
  /// asks the system first; a refusal leaves them off.
  Future<void> update(DailyReminderPlan next) async {
    if (next == _plan) return;
    final turningOn = next.enabled && !_plan.enabled;
    _plan = next;
    _permissionDenied = false;
    notifyListeners();
    if (turningOn && !await scheduler.requestPermission()) {
      _plan = next.copyWith(enabled: false);
      _permissionDenied = true;
      notifyListeners();
      return;
    }
    await _schedule(save: true);
  }

  Future<void> _schedule({bool save = false}) async {
    try {
      if (save) await this.save(_plan);
      await scheduler.replaceAll([
        for (final at in _plan.upcoming(_now(), days: days))
          _reminder(at, content(ReminderTime(at.hour, at.minute))),
      ]);
      _error = null;
    } on Object catch (error) {
      _error = error;
    }
    notifyListeners();
  }

  static ScheduledReminder _reminder(
    DateTime at,
    ({String title, String? body, String? payload}) text,
  ) => ScheduledReminder(
    at: at,
    title: text.title,
    body: text.body,
    payload: text.payload,
  );
}
