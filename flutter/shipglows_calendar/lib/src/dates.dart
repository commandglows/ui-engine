import 'package:flutter/foundation.dart';

/// The ways a calendar can show its days.
enum CalendarView { day, week, month, agenda }

/// [value] as a civil day: its year, month and day, at midnight UTC.
DateTime calendarDay(DateTime value) =>
    DateTime.utc(value.year, value.month, value.day);

/// The civil day [days] days after [day] (before when negative).
DateTime calendarAddDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

/// Whether [a] and [b] are the same civil day, whatever their zones.
bool calendarSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

/// The civil day written `YYYY-MM-DD`, at UTC midnight like [calendarDay];
/// null when [value] is not one.
DateTime? parseCivilDate(String? value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value ?? '');
  if (match == null) return null;
  return DateTime.utc(
    int.parse(match[1]!),
    int.parse(match[2]!),
    int.parse(match[3]!),
  );
}

/// The date [step] periods of [view] away from [date]: one day, one week,
/// or the first day of another month.
DateTime calendarShift(CalendarView view, DateTime date, int step) =>
    switch (view) {
      CalendarView.day => calendarAddDays(date, step),
      CalendarView.month => DateTime.utc(date.year, date.month + step),
      CalendarView.week || CalendarView.agenda => calendarAddDays(date, step * 7),
    };

/// Consecutive civil days shown together.
@immutable
class CalendarRange {
  const CalendarRange(this.start, this.days);

  /// The days [view] shows around [date]: the day, its week from Monday, the
  /// six weeks holding its month, or seven days from it in the agenda
  /// ([singleDay] keeps the agenda to the day).
  factory CalendarRange.of(
    CalendarView view,
    DateTime date, {
    bool singleDay = false,
  }) {
    final day = calendarDay(date);
    switch (view) {
      case CalendarView.day:
        return CalendarRange(day, 1);
      case CalendarView.week:
        return CalendarRange.week(day);
      case CalendarView.month:
        final first = DateTime.utc(day.year, day.month);
        return CalendarRange(calendarAddDays(first, 1 - first.weekday), 42);
      case CalendarView.agenda:
        return CalendarRange(day, singleDay ? 1 : 7);
    }
  }

  /// The week holding [date], from Monday.
  factory CalendarRange.week(DateTime date) {
    final day = calendarDay(date);
    return CalendarRange(calendarAddDays(day, 1 - day.weekday), 7);
  }

  /// Every day of the month holding [date], and only those.
  factory CalendarRange.month(DateTime date) => CalendarRange(
    DateTime.utc(date.year, date.month),
    DateTime.utc(date.year, date.month + 1, 0).day,
  );

  /// First day, a civil day.
  final DateTime start;

  /// Number of days.
  final int days;

  /// The day after the last one.
  DateTime get end => calendarAddDays(start, days);

  /// Every day, first day first.
  List<DateTime> get dates =>
      List.generate(days, (index) => calendarAddDays(start, index));

  bool contains(DateTime day) {
    final value = calendarDay(day);
    return !value.isBefore(start) && value.isBefore(end);
  }

  @override
  bool operator ==(Object other) =>
      other is CalendarRange && other.start == start && other.days == days;

  @override
  int get hashCode => Object.hash(start, days);
}
