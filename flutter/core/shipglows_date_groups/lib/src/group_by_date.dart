import 'package:meta/meta.dart';

import 'date_period.dart';
import 'date_strings.dart';

/// What happens to dated items that fall in no period.
enum DateRest {
  /// One group per calendar month: « Octobre », « Mars 2025 ».
  months,

  /// One group per calendar year: « 2025 ».
  years,

  /// One group, [DateStrings.older].
  single,
}

/// A heading and its items, in order.
@immutable
final class DateGroup<T> {
  /// Creates a group.
  const DateGroup({required this.id, required this.title, required this.items});

  /// Stable id, unique in the result: a period's id, `month-2026-10`,
  /// `year-2025`, `older` or `undated`.
  final String id;

  /// Heading text.
  final String title;

  /// Items of the group, never empty when it comes from [groupByDate].
  final List<T> items;
}

/// Sorts [items] by date and cuts them into headed groups.
///
/// An item goes to the first of [periods] that contains it, then to a group
/// chosen by [rest]. Empty groups are left out, and items where [dateOf] returns
/// null come last, under [DateStrings.undated]. Items with the same date keep
/// their order.
///
/// [periods] defaults to [DatePeriod.sections]. Pass the same [now] to every
/// call of a screen, and refresh it when the day changes.
///
/// A UTC value from [dateOf] is an instant, shown on the device's calendar. To
/// group on another calendar, return a local `DateTime` holding that calendar's
/// date and pass [now] the same way.
List<DateGroup<T>> groupByDate<T>(
  Iterable<T> items, {
  required DateTime? Function(T item) dateOf,
  required DateTime now,
  required DateStrings strings,
  List<DatePeriod>? periods,
  DateRest rest = DateRest.months,
  bool newestFirst = true,
}) {
  final spans = [
    for (final period in periods ?? DatePeriod.sections)
      (period: period, span: period.spanAt(now)),
  ];
  final currentYear = now.toLocal().year;

  final dated = <({int index, T item, DateTime date})>[];
  final undated = <T>[];
  var index = 0;
  for (final item in items) {
    final date = dateOf(item);
    if (date == null) {
      undated.add(item);
    } else {
      dated.add((index: index++, item: item, date: date.toLocal()));
    }
  }
  dated.sort((a, b) {
    final byDate = newestFirst
        ? b.date.compareTo(a.date)
        : a.date.compareTo(b.date);
    return byDate != 0 ? byDate : a.index.compareTo(b.index);
  });

  final titles = <String, String>{};
  final grouped = <String, List<T>>{};
  for (final entry in dated) {
    final period = spans
        .where((candidate) => candidate.span.contains(entry.date))
        .firstOrNull
        ?.period;
    final String id;
    if (period != null) {
      id = period.id;
      titles[id] ??= period.titleIn(strings);
    } else {
      final date = entry.date;
      switch (rest) {
        case DateRest.months:
          id = 'month-${date.year}-${date.month.toString().padLeft(2, '0')}';
          titles[id] ??= strings.monthTitle(
            date.year,
            date.month,
            currentYear: currentYear,
          );
        case DateRest.years:
          id = 'year-${date.year}';
          titles[id] ??= '${date.year}';
        case DateRest.single:
          id = 'older';
          titles[id] ??= strings.older;
      }
    }
    (grouped[id] ??= []).add(entry.item);
  }

  return [
    for (final group in grouped.entries)
      DateGroup(id: group.key, title: titles[group.key]!, items: group.value),
    if (undated.isNotEmpty)
      DateGroup(id: 'undated', title: strings.undated, items: undated),
  ];
}
