import 'package:meta/meta.dart';

import 'date_span.dart';

/// Every text of the package. Use [fr] or [en], or build your own for another
/// language.
@immutable
final class DateStrings {
  /// Creates the texts of one language.
  const DateStrings({
    required this.today,
    required this.yesterday,
    required this.tomorrow,
    required this.upcoming,
    required this.last7Days,
    required this.last30Days,
    required this.oneWeekAgo,
    required this.twoWeeksAgo,
    required this.threeWeeksAgo,
    required this.thisWeek,
    required this.lastWeek,
    required this.thisMonth,
    required this.lastMonth,
    required this.thisYear,
    required this.lastYear,
    required this.older,
    required this.undated,
    required this.all,
    required this.custom,
    required this.months,
    required this.firstOfMonth,
    required this.dayTemplate,
    required this.dayWithYearTemplate,
    required this.rangeTemplate,
    required this.sinceTemplate,
    required this.untilTemplate,
  });

  /// French.
  static const fr = DateStrings(
    today: 'Aujourd’hui',
    yesterday: 'Hier',
    tomorrow: 'Demain',
    upcoming: 'À venir',
    last7Days: '7 derniers jours',
    last30Days: '30 derniers jours',
    oneWeekAgo: 'Il y a une semaine',
    twoWeeksAgo: 'Il y a deux semaines',
    threeWeeksAgo: 'Il y a trois semaines',
    thisWeek: 'Cette semaine',
    lastWeek: 'La semaine dernière',
    thisMonth: 'Ce mois-ci',
    lastMonth: 'Le mois dernier',
    thisYear: 'Cette année',
    lastYear: 'L’année dernière',
    older: 'Plus ancien',
    undated: 'Sans date',
    all: 'Tout',
    custom: 'Personnalisé',
    months: [
      'janvier',
      'février',
      'mars',
      'avril',
      'mai',
      'juin',
      'juillet',
      'août',
      'septembre',
      'octobre',
      'novembre',
      'décembre',
    ],
    firstOfMonth: '1er',
    dayTemplate: '{day} {month}',
    dayWithYearTemplate: '{day} {month} {year}',
    rangeTemplate: 'Du {start} au {end}',
    sinceTemplate: 'Depuis le {date}',
    untilTemplate: 'Jusqu’au {date}',
  );

  /// English.
  static const en = DateStrings(
    today: 'Today',
    yesterday: 'Yesterday',
    tomorrow: 'Tomorrow',
    upcoming: 'Upcoming',
    last7Days: 'Last 7 days',
    last30Days: 'Last 30 days',
    oneWeekAgo: 'A week ago',
    twoWeeksAgo: 'Two weeks ago',
    threeWeeksAgo: 'Three weeks ago',
    thisWeek: 'This week',
    lastWeek: 'Last week',
    thisMonth: 'This month',
    lastMonth: 'Last month',
    thisYear: 'This year',
    lastYear: 'Last year',
    older: 'Older',
    undated: 'No date',
    all: 'All',
    custom: 'Custom',
    months: [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ],
    firstOfMonth: '1',
    dayTemplate: '{month} {day}',
    dayWithYearTemplate: '{month} {day}, {year}',
    rangeTemplate: 'From {start} to {end}',
    sinceTemplate: 'Since {date}',
    untilTemplate: 'Until {date}',
  );

  final String today;
  final String yesterday;
  final String tomorrow;
  final String upcoming;
  final String last7Days;
  final String last30Days;
  final String oneWeekAgo;
  final String twoWeeksAgo;
  final String threeWeeksAgo;
  final String thisWeek;
  final String lastWeek;
  final String thisMonth;
  final String lastMonth;
  final String thisYear;
  final String lastYear;

  /// Heading of the single group for older items.
  final String older;

  /// Heading of the group for items without a date.
  final String undated;

  /// The filter choice that keeps everything.
  final String all;

  /// The filter choice that opens the date range picker.
  final String custom;

  /// Twelve names, January first, as they read inside a sentence.
  final List<String> months;

  /// The first day of a month: « 1er » in French.
  final String firstOfMonth;

  /// A day in the current sentence, with `{day}` and `{month}`.
  final String dayTemplate;

  /// The same with `{year}`.
  final String dayWithYearTemplate;

  /// Two days, with `{start}` and `{end}`.
  final String rangeTemplate;

  /// A span with no end, with `{date}`.
  final String sinceTemplate;

  /// A span with no start, with `{date}`.
  final String untilTemplate;

  /// Heading for a month: « Octobre », with its year unless it is [currentYear].
  String monthTitle(int year, int month, {required int currentYear}) {
    final name = months[month - 1];
    final title = name.substring(0, 1).toUpperCase() + name.substring(1);
    return year == currentYear ? title : '$title $year';
  }

  /// One day: « 3 novembre 2026 ».
  String formatDay(DateTime day, {bool withYear = true}) =>
      (withYear ? dayWithYearTemplate : dayTemplate)
          .replaceAll('{day}', day.day == 1 ? firstOfMonth : '${day.day}')
          .replaceAll('{month}', months[day.month - 1])
          .replaceAll('{year}', '${day.year}');

  /// A span: « Du 3 novembre au 7 novembre 2026 ». One day reads as that day,
  /// and a span open on both sides as [all].
  String formatSpan(DateSpan span) {
    final first = span.first;
    final last = span.last;
    if (first == null && last == null) return all;
    if (first == null) {
      return untilTemplate.replaceAll('{date}', formatDay(last!));
    }
    if (last == null) {
      return sinceTemplate.replaceAll('{date}', formatDay(first));
    }
    if (first == last) return formatDay(first);
    return rangeTemplate
        .replaceAll(
          '{start}',
          formatDay(first, withYear: first.year != last.year),
        )
        .replaceAll('{end}', formatDay(last));
  }
}
