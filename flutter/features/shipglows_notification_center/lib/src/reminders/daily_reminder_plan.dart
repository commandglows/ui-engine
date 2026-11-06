import 'package:flutter/foundation.dart';

/// A time of day a reminder goes off, in local time.
@immutable
class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime(this.hour, this.minute)
    : assert(hour >= 0 && hour < 24),
      assert(minute >= 0 && minute < 60);

  final int hour;
  final int minute;

  /// « 09:30 », the stored form.
  String get id =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  /// Reads [id]; anything else is `null`.
  static ReminderTime? parse(Object? data) {
    if (data is! String) return null;
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(data.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!);
    final minute = int.parse(match[2]!);
    if (hour > 23 || minute > 59) return null;
    return ReminderTime(hour, minute);
  }

  @override
  int compareTo(ReminderTime other) =>
      (hour * 60 + minute) - (other.hour * 60 + other.minute);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);

  @override
  String toString() => id;
}

/// The daily reminders a person chose: off by default, one to [maxTimes]
/// times a day, the same every day. No streak and no catching up: a missed
/// reminder is simply gone.
@immutable
class DailyReminderPlan {
  DailyReminderPlan({
    this.enabled = false,
    List<ReminderTime> times = const [ReminderTime(9, 0)],
  }) : times = List.unmodifiable(_tidy(times));

  static const maxTimes = 3;

  final bool enabled;

  /// Sorted, without duplicates, never empty, at most [maxTimes].
  final List<ReminderTime> times;

  bool get canAddTime => times.length < maxTimes;

  static List<ReminderTime> _tidy(List<ReminderTime> times) {
    final tidy = times.toSet().toList()..sort();
    if (tidy.isEmpty) return const [ReminderTime(9, 0)];
    return tidy.take(maxTimes).toList();
  }

  DailyReminderPlan copyWith({bool? enabled, List<ReminderTime>? times}) =>
      DailyReminderPlan(
        enabled: enabled ?? this.enabled,
        times: times ?? this.times,
      );

  /// Adds [time], unless the plan is full or already has it.
  DailyReminderPlan withTime(ReminderTime time) =>
      canAddTime ? copyWith(times: [...times, time]) : this;

  /// Removes [time]; the last time stays.
  DailyReminderPlan withoutTime(ReminderTime time) => times.length > 1
      ? copyWith(times: [...times.where((t) => t != time)])
      : this;

  /// Moves [from] to [to].
  DailyReminderPlan replacing(ReminderTime from, ReminderTime to) =>
      copyWith(times: [for (final t in times) t == from ? to : t]);

  /// The reminders still to come from [from] over [days] days, today
  /// included, in local time. Each one is computed from the calendar day,
  /// so a daylight-saving change never shifts it.
  List<DateTime> upcoming(DateTime from, {int days = 7}) {
    if (!enabled) return const [];
    final local = from.toLocal();
    return [
      for (var day = 0; day < days; day++)
        for (final time in times)
          DateTime(
            local.year,
            local.month,
            local.day + day,
            time.hour,
            time.minute,
          ),
    ].where((at) => at.isAfter(local)).toList();
  }

  /// JSON-safe form, for the app's settings store.
  Map<String, Object?> toJson() => {
    'enabled': enabled,
    'times': [for (final time in times) time.id],
  };

  /// Reads [toJson]; unusable data is `null`.
  static DailyReminderPlan? fromJson(Object? data) {
    if (data is! Map) return null;
    final times = data['times'];
    return DailyReminderPlan(
      enabled: data['enabled'] == true,
      times: times is List
          ? [for (final t in times) ?ReminderTime.parse(t)]
          : const [ReminderTime(9, 0)],
    );
  }

  @override
  bool operator ==(Object other) =>
      other is DailyReminderPlan &&
      other.enabled == enabled &&
      listEquals(other.times, times);

  @override
  int get hashCode => Object.hash(enabled, Object.hashAll(times));
}
