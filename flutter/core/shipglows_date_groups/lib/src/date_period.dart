import 'package:meta/meta.dart';

import 'date_span.dart';
import 'date_strings.dart';

/// A named stretch of days measured from today: a section of a list, or a
/// choice of a filter.
@immutable
final class DatePeriod {
  const DatePeriod._(this.id, this._title, this._span, [this._window]);

  /// A period of your own. [span] receives today, at local noon, and is called
  /// each time the period is resolved.
  factory DatePeriod.custom({
    required String id,
    required String title,
    required DateSpan Function(DateTime today) span,
  }) => DatePeriod._(id, (_) => title, span);

  /// From [from] to [to] days ago, both included; a negative number is in the
  /// future. [id] defaults to one built from the two numbers.
  factory DatePeriod.daysAgo({
    required int from,
    required int to,
    required String title,
    String? id,
  }) => DatePeriod._(
    id ?? 'days-$from-$to',
    (_) => title,
    _daysAgo(from, to),
  );

  /// Fixed dates, as chosen in a date range picker. Its id is [rangeId]; without
  /// [title], it reads « Du 3 novembre au 7 novembre 2026 ».
  factory DatePeriod.range(DateSpan span, {String? title}) => DatePeriod._(
    rangeId,
    (strings) => title ?? strings.formatSpan(span),
    (_) => span,
  );

  /// The id of every [DatePeriod.range].
  static const rangeId = 'range';

  /// The last hour, to the minute.
  static final lastHour = DatePeriod._(
    'last-hour',
    (s) => s.lastHour,
    (_) => DateSpan(),
    const Duration(hours: 1),
  );

  /// Today.
  static final today = DatePeriod._(
    'today',
    (s) => s.today,
    _daysAgo(0, 0),
  );

  /// Yesterday.
  static final yesterday = DatePeriod._(
    'yesterday',
    (s) => s.yesterday,
    _daysAgo(1, 1),
  );

  /// Tomorrow.
  static final tomorrow = DatePeriod._(
    'tomorrow',
    (s) => s.tomorrow,
    _daysAgo(-1, -1),
  );

  /// Every day after today.
  static final upcoming = DatePeriod._(
    'upcoming',
    (s) => s.upcoming,
    (today) => DateSpan(first: _shift(today, 1)),
  );

  /// The last five days, today included.
  static final last5Days = DatePeriod._(
    'last-5-days',
    (s) => s.last5Days,
    _daysAgo(0, 4),
  );

  /// The last seven days, today included.
  static final last7Days = DatePeriod._(
    'last-7-days',
    (s) => s.last7Days,
    _daysAgo(0, 6),
  );

  /// The last thirty days, today included.
  static final last30Days = DatePeriod._(
    'last-30-days',
    (s) => s.last30Days,
    _daysAgo(0, 29),
  );

  /// The rest of the last seven days once today and yesterday have their own
  /// section. Titled like [last7Days].
  static final earlierThisWeek = DatePeriod._(
    'earlier-this-week',
    (s) => s.last7Days,
    _daysAgo(2, 6),
  );

  /// Seven to thirteen days ago.
  static final oneWeekAgo = DatePeriod._(
    'one-week-ago',
    (s) => s.oneWeekAgo,
    _daysAgo(7, 13),
  );

  /// Fourteen to twenty days ago.
  static final twoWeeksAgo = DatePeriod._(
    'two-weeks-ago',
    (s) => s.twoWeeksAgo,
    _daysAgo(14, 20),
  );

  /// Twenty-one to twenty-seven days ago.
  static final threeWeeksAgo = DatePeriod._(
    'three-weeks-ago',
    (s) => s.threeWeeksAgo,
    _daysAgo(21, 27),
  );

  /// Seven to twenty-seven days ago, before it is cut into weeks.
  static final fewWeeksAgo = DatePeriod._(
    'few-weeks-ago',
    (s) => s.fewWeeksAgo,
    _daysAgo(7, 27),
  );

  /// The calendar month of today, all of it.
  static final thisMonth = DatePeriod._(
    'this-month',
    (s) => s.thisMonth,
    (today) => _month(today, 0),
  );

  /// The calendar month before today's.
  static final lastMonth = DatePeriod._(
    'last-month',
    (s) => s.lastMonth,
    (today) => _month(today, -1),
  );

  /// The calendar year of today, all of it.
  static final thisYear = DatePeriod._(
    'this-year',
    (s) => s.thisYear,
    (today) => _year(today, 0),
  );

  /// The calendar year before today's.
  static final lastYear = DatePeriod._(
    'last-year',
    (s) => s.lastYear,
    (today) => _year(today, -1),
  );

  /// The default sections of a list.
  static final sections = List<DatePeriod>.unmodifiable([
    upcoming,
    today,
    yesterday,
    earlierThisWeek,
    oneWeekAgo,
    twoWeeksAgo,
    threeWeeksAgo,
  ]);

  /// The default choices of a filter.
  static final filters = List<DatePeriod>.unmodifiable([
    today,
    yesterday,
    last7Days,
    last30Days,
    thisMonth,
    thisYear,
  ]);

  /// The calendar week of today, all of it, starting on [firstWeekday]:
  /// [DateTime.monday] in France, [DateTime.sunday] in the United States.
  static DatePeriod thisWeek({int firstWeekday = DateTime.monday}) =>
      DatePeriod._(
        'this-week',
        (s) => s.thisWeek,
        (today) => _week(today, firstWeekday, 0),
      );

  /// The calendar week before today's, starting on [firstWeekday].
  static DatePeriod lastWeek({int firstWeekday = DateTime.monday}) =>
      DatePeriod._(
        'last-week',
        (s) => s.lastWeek,
        (today) => _week(today, firstWeekday, -1),
      );

  /// Stable id, the value to store.
  final String id;

  final String Function(DateStrings strings) _title;
  final DateSpan Function(DateTime today) _span;

  /// Set for a period counted back from the clock rather than in whole days.
  final Duration? _window;

  /// The text to show, in the language of [strings].
  String titleIn(DateStrings strings) => _title(strings);

  /// The days this period covers when the clock reads [now].
  DateSpan spanAt(DateTime now) {
    final window = _window;
    if (window != null) return DateSpan.since(now.subtract(window));
    final local = now.toLocal();
    return _span(DateTime(local.year, local.month, local.day, 12));
  }

  /// Whether [moment] falls in this period when the clock reads [now]. To
  /// filter many items, resolve [spanAt] once and use [DateSpan.contains].
  bool contains(DateTime moment, {required DateTime now}) =>
      spanAt(now).contains(moment);
}

DateTime _shift(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

DateSpan Function(DateTime) _daysAgo(int from, int to) =>
    (today) => DateSpan(first: _shift(today, -to), last: _shift(today, -from));

DateSpan _week(DateTime today, int firstWeekday, int weeks) {
  final sinceStart = (today.weekday - firstWeekday) % DateTime.daysPerWeek;
  final start = -sinceStart + weeks * DateTime.daysPerWeek;
  return DateSpan(first: _shift(today, start), last: _shift(today, start + 6));
}

DateSpan _month(DateTime today, int months) => DateSpan(
  first: DateTime.utc(today.year, today.month + months),
  last: DateTime.utc(today.year, today.month + months + 1, 0),
);

DateSpan _year(DateTime today, int years) => DateSpan(
  first: DateTime.utc(today.year + years),
  last: DateTime.utc(today.year + years, 12, 31),
);
