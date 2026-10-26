import 'package:flutter/widgets.dart';

import 'dates.dart';

/// Texts of the calendar. The app picks the language: use [en], [fr],
/// [forLocale], or its own values through [copyWith]. `{title}`, `{label}`,
/// `{day}` and `{count}` are filled in.
@immutable
class CalendarStrings {
  const CalendarStrings({
    required this.languageCode,
    required this.weekdays,
    required this.weekdaysLong,
    required this.months,
    required this.monthsShort,
    required this.today,
    required this.previous,
    required this.next,
    required this.chooseDate,
    required this.viewDay,
    required this.viewWeek,
    required this.viewMonth,
    required this.viewAgenda,
    required this.allDay,
    required this.empty,
    required this.narrowNotice,
    required this.eventHint,
    required this.edit,
    required this.resize,
    required this.resizeHint,
    required this.resizeDays,
    required this.resizeDaysHint,
    required this.noEvents,
    required this.eventCount,
    required this.todayDay,
    required this.more,
  });

  /// `fr` writes « lundi 26 octobre », `en` « Monday, October 26 ».
  final String languageCode;

  /// Short weekday names, Monday first.
  final List<String> weekdays;
  final List<String> weekdaysLong;

  /// Month names, January first.
  final List<String> months;
  final List<String> monthsShort;

  final String today;
  final String previous;
  final String next;
  final String chooseDate;
  final String viewDay;
  final String viewWeek;
  final String viewMonth;
  final String viewAgenda;

  /// Label of the all-day row of the day and week grids.
  final String allDay;

  /// Agenda without events.
  final String empty;

  /// Shown when a narrow window turns the day or week view into the agenda.
  final String narrowNotice;

  /// Tooltip of an event card: `{label}`.
  final String eventHint;

  /// Edit button of an agenda row: `{title}`.
  final String edit;

  /// Resize handle of a timed event: `{title}`.
  final String resize;
  final String resizeHint;

  /// Resize handle of an all-day event: `{title}`.
  final String resizeDays;
  final String resizeDaysHint;

  /// Day without events, read after the day by screen readers.
  final String noEvents;

  /// Number of events on a day: `{count}`.
  final String eventCount;

  /// Today, read by screen readers: `{day}`.
  final String todayDay;

  /// Hidden events of a month cell: `{count}`.
  final String more;

  static const en = CalendarStrings(
    languageCode: 'en',
    weekdays: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
    weekdaysLong: [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ],
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
    monthsShort: [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ],
    today: 'Today',
    previous: 'Previous period',
    next: 'Next period',
    chooseDate: 'Choose a date',
    viewDay: 'Day',
    viewWeek: 'Week',
    viewMonth: 'Month',
    viewAgenda: 'List',
    allDay: 'All\nday',
    empty: 'Nothing planned in this period.',
    narrowNotice: 'The list keeps this narrow window easy to read.',
    eventHint: '{label} · Select for details, double-click to edit',
    edit: 'Edit {title}',
    resize: 'Resize {title}',
    resizeHint: 'Drag to change the end; click to enter the period',
    resizeDays: 'Resize the dates of {title}',
    resizeDaysHint: 'Drag to change the last day; click to enter the period',
    noEvents: 'nothing planned',
    eventCount: '{count} planned',
    todayDay: 'Today, {day}',
    more: '+{count}',
  );

  static const fr = CalendarStrings(
    languageCode: 'fr',
    weekdays: ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'],
    weekdaysLong: [
      'lundi',
      'mardi',
      'mercredi',
      'jeudi',
      'vendredi',
      'samedi',
      'dimanche',
    ],
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
    monthsShort: [
      'janv.',
      'févr.',
      'mars',
      'avr.',
      'mai',
      'juin',
      'juil.',
      'août',
      'sept.',
      'oct.',
      'nov.',
      'déc.',
    ],
    today: 'Aujourd’hui',
    previous: 'Période précédente',
    next: 'Période suivante',
    chooseDate: 'Choisir une date',
    viewDay: 'Jour',
    viewWeek: 'Semaine',
    viewMonth: 'Mois',
    viewAgenda: 'Liste',
    allDay: 'Journée\nentière',
    empty: 'Rien de prévu dans cette période.',
    narrowNotice:
        'La liste conserve une lecture confortable dans cette fenêtre.',
    eventHint: '{label} · Sélectionner pour les détails, double clic pour '
        'modifier',
    edit: 'Modifier {title}',
    resize: 'Redimensionner {title}',
    resizeHint:
        'Glisser pour changer la fin ; cliquer pour saisir la période',
    resizeDays: 'Redimensionner les dates de {title}',
    resizeDaysHint:
        'Glisser pour changer la date de fin ; cliquer pour saisir la période',
    noEvents: 'rien de prévu',
    eventCount: '{count} prévus',
    todayDay: 'Aujourd’hui, {day}',
    more: '+{count}',
  );

  /// French for a French [locale], English otherwise.
  static CalendarStrings forLocale(Locale locale) =>
      locale.languageCode == 'fr' ? fr : en;

  bool get _french => languageCode == 'fr';

  /// [template] with each `{key}` replaced by its value.
  static String fill(String template, Map<String, Object> values) {
    var result = template;
    values.forEach((key, value) {
      result = result.replaceAll('{$key}', '$value');
    });
    return result;
  }

  /// « 26 octobre 2026 », « October 26, 2026 ».
  String date(DateTime day) => _french
      ? '${day.day} ${months[day.month - 1]} ${day.year}'
      : '${months[day.month - 1]} ${day.day}, ${day.year}';

  /// « lundi 26 octobre 2026 », « Monday, October 26, 2026 ».
  String longDate(DateTime day) => _french
      ? '${weekdaysLong[day.weekday - 1]} ${date(day)}'
      : '${weekdaysLong[day.weekday - 1]}, ${date(day)}';

  /// « octobre 2026 », « October 2026 ».
  String month(DateTime day) => '${months[day.month - 1]} ${day.year}';

  /// Column title of the week grid: « Lun 26/10 », « Mon 10/26 ».
  String column(DateTime day) => _french
      ? '${weekdays[day.weekday - 1]} ${day.day}/${day.month}'
      : '${weekdays[day.weekday - 1]} ${day.month}/${day.day}';

  /// Titles of a column of the week grid, the fullest first: « lun. 19 oct. »,
  /// « lun. 19 », « 19 » (English « Mon, Oct 19 », « Mon 19 », « 19 »). The
  /// grid draws the first one that fits the column.
  List<String> columnLabels(DateTime day, {DateTime? reference}) {
    final weekday = _french
        ? '${weekdays[day.weekday - 1].toLowerCase()}.'
        : weekdays[day.weekday - 1];
    return [
      shortDay(day, reference: reference),
      '$weekday ${day.day}',
      '${day.day}',
    ];
  }

  /// Day of the day strip: « Lun 26 ».
  String stripDay(DateTime day) => '${weekdays[day.weekday - 1]} ${day.day}';

  /// Title of the period [view] shows around [day]: the date, the week
  /// (« 20 – 26 oct. 2026 ») or the month.
  String period(CalendarView view, DateTime day) {
    switch (view) {
      case CalendarView.day || CalendarView.agenda:
        return date(day);
      case CalendarView.month:
        return month(day);
      case CalendarView.week:
        final range = CalendarRange.week(day);
        return span(range.start, calendarAddDays(range.start, 6));
    }
  }

  /// Two days as a short span: « 28 sept. – 4 oct. 2026 ».
  String span(DateTime first, DateTime last) {
    final sameYear = first.year == last.year;
    final sameMonth = sameYear && first.month == last.month;
    if (_french) {
      final start = sameMonth
          ? '${first.day}'
          : '${first.day} ${monthsShort[first.month - 1]}'
                '${sameYear ? '' : ' ${first.year}'}';
      return '$start – ${last.day} ${monthsShort[last.month - 1]} ${last.year}';
    }
    final start =
        '${monthsShort[first.month - 1]} ${first.day}'
        '${sameYear ? '' : ', ${first.year}'}';
    final end = sameMonth
        ? '${last.day}'
        : '${monthsShort[last.month - 1]} ${last.day}';
    return '$start – $end, ${last.year}';
  }

  /// Short day: « sam. 18 oct. », or « sam. 18 oct. 2025 » outside
  /// [reference]'s year (today by default). English: « Sat, Oct 18 ».
  String shortDay(DateTime day, {DateTime? reference, bool weekday = true}) {
    final sameYear = (reference ?? DateTime.now()).year == day.year;
    if (_french) {
      final year = sameYear ? '' : ' ${day.year}';
      final date = '${day.day} ${monthsShort[day.month - 1]}$year';
      // French weekday abbreviations are the lower-case first letters, dotted.
      final name = '${weekdays[day.weekday - 1].toLowerCase()}.';
      return weekday ? '$name $date' : date;
    }
    final year = sameYear ? '' : ', ${day.year}';
    final date = '${monthsShort[day.month - 1]} ${day.day}$year';
    return weekday ? '${weekdays[day.weekday - 1]}, $date' : date;
  }

  /// « sam. 18 oct. à 14:05 », or « Sat, Oct 18 at 14:05 ».
  String shortDateTime(DateTime date, {DateTime? reference}) {
    final time = '${_two(date.hour)}:${_two(date.minute)}';
    final day = shortDay(date, reference: reference);
    return _french ? '$day à $time' : '$day at $time';
  }

  /// « lundi 26 octobre 2026 à 09:00 », « Monday, October 26, 2026 at 09:00 ».
  String longDateTime(DateTime date) {
    final time = '${_two(date.hour)}:${_two(date.minute)}';
    return _french ? '${longDate(date)} à $time' : '${longDate(date)} at $time';
  }

  /// « 12 – 18 oct. », « 28 sept. – 4 oct. » across months. English days
  /// stay whole on both sides: « Oct 12 – Oct 18 ».
  String shortRange(DateTime start, DateTime end, {DateTime? reference}) {
    final sameYear = start.year == end.year;
    if (!_french) {
      return '${shortDay(start, reference: reference, weekday: false)} – '
          '${shortDay(end, reference: reference, weekday: false)}';
    }
    final last = shortDay(end, reference: reference, weekday: false);
    if (sameYear && start.month == end.month) {
      return '${start.day} – $last';
    }
    final first = sameYear
        ? '${start.day} ${monthsShort[start.month - 1]}'
        : shortDay(start, reference: reference, weekday: false);
    return '$first – $last';
  }

  CalendarStrings copyWith({
    String? languageCode,
    List<String>? weekdays,
    List<String>? weekdaysLong,
    List<String>? months,
    List<String>? monthsShort,
    String? today,
    String? previous,
    String? next,
    String? chooseDate,
    String? viewDay,
    String? viewWeek,
    String? viewMonth,
    String? viewAgenda,
    String? allDay,
    String? empty,
    String? narrowNotice,
    String? eventHint,
    String? edit,
    String? resize,
    String? resizeHint,
    String? resizeDays,
    String? resizeDaysHint,
    String? noEvents,
    String? eventCount,
    String? todayDay,
    String? more,
  }) => CalendarStrings(
    languageCode: languageCode ?? this.languageCode,
    weekdays: weekdays ?? this.weekdays,
    weekdaysLong: weekdaysLong ?? this.weekdaysLong,
    months: months ?? this.months,
    monthsShort: monthsShort ?? this.monthsShort,
    today: today ?? this.today,
    previous: previous ?? this.previous,
    next: next ?? this.next,
    chooseDate: chooseDate ?? this.chooseDate,
    viewDay: viewDay ?? this.viewDay,
    viewWeek: viewWeek ?? this.viewWeek,
    viewMonth: viewMonth ?? this.viewMonth,
    viewAgenda: viewAgenda ?? this.viewAgenda,
    allDay: allDay ?? this.allDay,
    empty: empty ?? this.empty,
    narrowNotice: narrowNotice ?? this.narrowNotice,
    eventHint: eventHint ?? this.eventHint,
    edit: edit ?? this.edit,
    resize: resize ?? this.resize,
    resizeHint: resizeHint ?? this.resizeHint,
    resizeDays: resizeDays ?? this.resizeDays,
    resizeDaysHint: resizeDaysHint ?? this.resizeDaysHint,
    noEvents: noEvents ?? this.noEvents,
    eventCount: eventCount ?? this.eventCount,
    todayDay: todayDay ?? this.todayDay,
    more: more ?? this.more,
  );

  /// The label of [view] in the view switch.
  String view(CalendarView view) => switch (view) {
    CalendarView.day => viewDay,
    CalendarView.week => viewWeek,
    CalendarView.month => viewMonth,
    CalendarView.agenda => viewAgenda,
  };
}

String _two(int value) => value.toString().padLeft(2, '0');
