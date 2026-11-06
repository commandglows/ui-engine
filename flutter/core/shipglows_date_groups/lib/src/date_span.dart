import 'package:meta/meta.dart';

/// Whole calendar days from [first] to [last], both included. A missing bound
/// leaves that side open.
///
/// Bounds are calendar dates: their year, month and day are read as written.
/// Days are counted as numbers, so a daylight saving change never moves one.
@immutable
final class DateSpan {
  /// Creates a span. A [last] before [first] contains nothing.
  DateSpan({DateTime? first, DateTime? last})
    : _first = first == null ? null : _dayNumber(first),
      _last = last == null ? null : _dayNumber(last),
      _since = null;

  /// Everything from the instant [moment] on, to the minute: « the last hour ».
  DateSpan.since(DateTime moment)
    : _first = _dayNumber(moment.toLocal()),
      _last = null,
      _since = moment;

  /// A span of one day.
  factory DateSpan.day(DateTime day) => DateSpan(first: day, last: day);

  final int? _first;
  final int? _last;
  final DateTime? _since;

  /// First day, as a local date; null when open.
  DateTime? get first => _dateOf(_first);

  /// Last day, as a local date; null when open.
  DateTime? get last => _dateOf(_last);

  /// Whether [moment] falls in the span, on the device's calendar. A UTC value
  /// is an instant and is converted first; to compare a stored calendar date,
  /// pass it as a local `DateTime(year, month, day)`.
  bool contains(DateTime moment) {
    final day = _dayNumber(moment.toLocal());
    final first = _first;
    final last = _last;
    final since = _since;
    if (since != null && moment.isBefore(since)) return false;
    return (first == null || day >= first) && (last == null || day <= last);
  }

  @override
  bool operator ==(Object other) =>
      other is DateSpan && other._first == _first &&
      other._last == _last &&
      other._since == _since;

  @override
  int get hashCode => Object.hash(_first, _last, _since);

  @override
  String toString() => 'DateSpan($first, $last)';
}

int _dayNumber(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/
    Duration.millisecondsPerDay;

DateTime? _dateOf(int? number) {
  if (number == null) return null;
  final utc = DateTime.fromMillisecondsSinceEpoch(
    number * Duration.millisecondsPerDay,
    isUtc: true,
  );
  return DateTime(utc.year, utc.month, utc.day);
}
