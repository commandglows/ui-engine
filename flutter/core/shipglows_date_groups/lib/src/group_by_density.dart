import 'date_period.dart';
import 'date_strings.dart';
import 'group_by_date.dart';

/// Sorts [items] by date and picks headings that fit how many there are: a
/// quiet history reads « Aujourd’hui », « Hier », « 7 derniers jours », a busy
/// day reads « Il y a moins de 3 h », « Il y a 5 h ».
///
/// It starts from wide sections (à venir, aujourd’hui, hier, the rest of the
/// week, a few weeks ago, older). A section with more than [maxPerGroup] items
/// is cut further:
///
/// - today into hours, measured from [now], with neighbouring hours joined
///   until each group holds [minPerGroup] items;
/// - yesterday into morning, afternoon and evening;
/// - the rest of the week and the coming days into single days;
/// - a few weeks ago into weeks, then days;
/// - older into years, then months, then days.
///
/// Items without a date come last. Headings about hours age: refresh [now]
/// regularly while the list stays on screen. Dates read as in [groupByDate].
List<DateGroup<T>> groupByDensity<T>(
  Iterable<T> items, {
  required DateTime? Function(T item) dateOf,
  required DateTime now,
  required DateStrings strings,
  int maxPerGroup = 4,
  int minPerGroup = 2,
  bool newestFirst = true,
}) {
  assert(maxPerGroup >= 1);
  assert(minPerGroup >= 1 && minPerGroup <= maxPerGroup);

  final currentYear = now.toLocal().year;
  DateTime dayOf(T item) => dateOf(item)!.toLocal();
  bool dense(DateGroup<T> group) => group.items.length > maxPerGroup;

  List<DateGroup<T>> byDay(DateGroup<T> group) => _cut(group.items, (item) {
    final date = dayOf(item);
    return (
      id: 'day-${_month(date)}-${_two(date.day)}',
      title: strings.dayTitle(date, currentYear: currentYear),
    );
  });

  List<DateGroup<T>> byMonth(DateGroup<T> group) => [
    for (final month in _cut(group.items, (item) {
      final date = dayOf(item);
      return (
        id: 'month-${_month(date)}',
        title: strings.monthTitle(
          date.year,
          date.month,
          currentYear: currentYear,
        ),
      );
    }))
      ...dense(month) ? byDay(month) : [month],
  ];

  List<DateGroup<T>> byYear(DateGroup<T> group) {
    final years = _cut(group.items, (item) {
      final year = dayOf(item).year;
      return (id: 'year-$year', title: '$year');
    });
    if (years.length == 1) return byMonth(years.single);
    return [
      for (final year in years) ...dense(year) ? byMonth(year) : [year],
    ];
  }

  List<DateGroup<T>> byWeek(DateGroup<T> group) => [
    for (final week in groupByDate<T>(
      group.items,
      dateOf: dateOf,
      now: now,
      strings: strings,
      periods: [
        DatePeriod.oneWeekAgo,
        DatePeriod.twoWeeksAgo,
        DatePeriod.threeWeeksAgo,
      ],
      newestFirst: newestFirst,
    ))
      ...dense(week) ? byDay(week) : [week],
  ];

  List<DateGroup<T>> byPartOfDay(DateGroup<T> group) =>
      _cut(group.items, (item) {
        final hour = dayOf(item).hour;
        if (hour < 12) {
          return (id: 'yesterday-morning', title: strings.yesterdayMorning);
        }
        if (hour < 18) {
          return (id: 'yesterday-afternoon', title: strings.yesterdayAfternoon);
        }
        return (id: 'yesterday-evening', title: strings.yesterdayEvening);
      });

  List<DateGroup<T>> refine(DateGroup<T> group) => switch (group.id) {
    'today' => _byHours(
      group.items,
      hoursAgo: (item) {
        final hours = now.difference(dateOf(item)!).inHours;
        return hours < 0 ? 0 : hours;
      },
      strings: strings,
      minPerGroup: minPerGroup,
      maxPerGroup: maxPerGroup,
    ),
    'yesterday' => byPartOfDay(group),
    'few-weeks-ago' => byWeek(group),
    'older' => byYear(group),
    _ => byDay(group),
  };

  return [
    for (final group in groupByDate<T>(
      items,
      dateOf: dateOf,
      now: now,
      strings: strings,
      periods: [
        DatePeriod.upcoming,
        DatePeriod.today,
        DatePeriod.yesterday,
        DatePeriod.earlierThisWeek,
        DatePeriod.fewWeeksAgo,
      ],
      rest: DateRest.single,
      newestFirst: newestFirst,
    ))
      ...!dense(group) || group.id == 'undated' ? [group] : refine(group),
  ];
}

/// Cuts items in order, one group per distinct id, in order of appearance.
List<DateGroup<T>> _cut<T>(
  List<T> items,
  ({String id, String title}) Function(T item) keyOf,
) {
  final titles = <String, String>{};
  final grouped = <String, List<T>>{};
  for (final item in items) {
    final key = keyOf(item);
    titles[key.id] = key.title;
    (grouped[key.id] ??= []).add(item);
  }
  return [
    for (final group in grouped.entries)
      DateGroup(id: group.key, title: titles[group.key]!, items: group.value),
  ];
}

/// One group per hour of age, neighbours joined until each reaches
/// [minPerGroup] without passing [maxPerGroup]. An hour alone may pass it: it is
/// the smallest cut there is.
List<DateGroup<T>> _byHours<T>(
  List<T> items, {
  required int Function(T item) hoursAgo,
  required DateStrings strings,
  required int minPerGroup,
  required int maxPerGroup,
}) {
  final hours = <int, List<T>>{};
  for (final item in items) {
    (hours[hoursAgo(item)] ??= []).add(item);
  }

  final runs = <_HourRun<T>>[];
  var run = _HourRun<T>();
  for (final hour in hours.entries) {
    if (run.items.isNotEmpty &&
        run.items.length + hour.value.length > maxPerGroup) {
      runs.add(run);
      run = _HourRun<T>();
    }
    run.hours.add(hour.key);
    run.items.addAll(hour.value);
    if (run.items.length >= minPerGroup) {
      runs.add(run);
      run = _HourRun<T>();
    }
  }
  if (run.items.isNotEmpty) {
    final previous = runs.isEmpty ? null : runs.last;
    if (previous != null &&
        previous.items.length + run.items.length <= maxPerGroup) {
      previous.hours.addAll(run.hours);
      previous.items.addAll(run.items);
    } else {
      runs.add(run);
    }
  }

  return [
    for (final run in runs)
      DateGroup<T>(
        id: 'hours-${run.youngest}-${run.oldest}',
        title: strings.hoursTitle(run.youngest, run.oldest),
        items: run.items,
      ),
  ];
}

/// Neighbouring hours of age and their items.
final class _HourRun<T> {
  final hours = <int>[];
  final items = <T>[];

  int get youngest => hours.reduce((a, b) => a < b ? a : b);

  int get oldest => hours.reduce((a, b) => a > b ? a : b);
}

String _month(DateTime date) => '${date.year}-${_two(date.month)}';

String _two(int value) => value.toString().padLeft(2, '0');
