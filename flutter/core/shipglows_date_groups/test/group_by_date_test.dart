import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_date_groups/shipglows_date_groups.dart';

/// A Friday afternoon.
final _now = DateTime(2026, 11, 6, 15);

List<DateGroup<DateTime>> _group(
  List<DateTime> dates, {
  DateTime? now,
  List<DatePeriod>? periods,
  DateRest rest = DateRest.months,
  bool newestFirst = true,
}) => groupByDate<DateTime>(
  dates,
  dateOf: (date) => date,
  now: now ?? _now,
  strings: DateStrings.fr,
  periods: periods,
  rest: rest,
  newestFirst: newestFirst,
);

void main() {
  test('cuts a history into the default sections, newest first', () {
    final groups = _group([
      DateTime(2025, 3, 2),
      DateTime(2026, 10, 1),
      DateTime(2026, 10, 15),
      DateTime(2026, 10, 22),
      DateTime(2026, 10, 30),
      DateTime(2026, 11, 3),
      DateTime(2026, 11, 5),
      DateTime(2026, 11, 6, 8),
      DateTime(2026, 11, 7),
    ]);
    expect(groups.map((group) => group.title), [
      'À venir',
      'Aujourd’hui',
      'Hier',
      '7 derniers jours',
      'Il y a une semaine',
      'Il y a deux semaines',
      'Il y a trois semaines',
      'Octobre',
      'Mars 2025',
    ]);
  });

  test('yesterday is a calendar day, not 24 hours', () {
    final groups = _group([
      DateTime(2026, 11, 5, 23, 59),
    ], now: DateTime(2026, 11, 6, 0, 1));
    expect(groups.single.id, 'yesterday');
  });

  test('counts calendar days across a daylight saving change', () {
    final groups = _group([
      DateTime(2026, 3, 28, 23, 30),
    ], now: DateTime(2026, 3, 30, 0, 30));
    expect(groups.single.id, 'earlier-this-week');
  });

  test('leaves empty groups out and puts undated items last', () {
    final groups = groupByDate<DateTime?>(
      [null, DateTime(2026, 11, 6)],
      dateOf: (date) => date,
      now: _now,
      strings: DateStrings.en,
    );
    expect(groups.map((group) => group.id), ['today', 'undated']);
    expect(groups.last.title, 'No date');
  });

  test('keeps the given order for equal dates', () {
    final items = ['a', 'b', 'c'];
    final groups = groupByDate<String>(
      items,
      dateOf: (_) => DateTime(2026, 11, 6),
      now: _now,
      strings: DateStrings.fr,
    );
    expect(groups.single.items, items);
  });

  test('goes oldest first on request', () {
    final groups = _group([
      DateTime(2026, 11, 6),
      DateTime(2026, 11, 5),
    ], newestFirst: false);
    expect(groups.map((group) => group.id), ['yesterday', 'today']);
  });

  test('the first matching period wins and custom periods are welcome', () {
    final holidays = DatePeriod.custom(
      id: 'holidays',
      title: 'Vacances',
      span: (today) => DateSpan(
        first: DateTime(today.year, 10, 17),
        last: DateTime(today.year, 11, 1),
      ),
    );
    final groups = _group(
      [DateTime(2026, 11, 6), DateTime(2026, 10, 20)],
      periods: [DatePeriod.today, DatePeriod.last7Days, holidays],
    );
    expect(groups.map((group) => group.title), ['Aujourd’hui', 'Vacances']);
  });

  test('groups the rest by year or as one', () {
    final dates = [DateTime(2025, 3, 2), DateTime(2024, 1, 1)];
    expect(
      _group(dates, rest: DateRest.years).map((group) => group.title),
      ['2025', '2024'],
    );
    expect(_group(dates, rest: DateRest.single).single.title, 'Plus ancien');
  });

  group('DatePeriod', () {
    test('this week follows the first weekday', () {
      final monday = DatePeriod.thisWeek().spanAt(_now);
      expect(monday.first, DateTime(2026, 11, 2));
      expect(monday.last, DateTime(2026, 11, 8));
      final sunday = DatePeriod.thisWeek(
        firstWeekday: DateTime.sunday,
      ).spanAt(_now);
      expect(sunday.first, DateTime(2026, 11, 1));
      expect(DatePeriod.lastWeek().spanAt(_now).last, DateTime(2026, 11, 1));
    });

    test('last month crosses a year', () {
      final span = DatePeriod.lastMonth.spanAt(DateTime(2027, 1, 15));
      expect(span.first, DateTime(2026, 12, 1));
      expect(span.last, DateTime(2026, 12, 31));
    });

    test('last 7 days stops today and starts six days ago', () {
      final period = DatePeriod.last7Days;
      expect(period.contains(DateTime(2026, 10, 31), now: _now), isTrue);
      expect(period.contains(DateTime(2026, 10, 30), now: _now), isFalse);
      expect(period.contains(DateTime(2026, 11, 7), now: _now), isFalse);
    });

    test('a range ignores the clock and titles itself', () {
      final period = DatePeriod.range(
        DateSpan(first: DateTime(2026, 11, 1), last: DateTime(2026, 11, 7)),
      );
      expect(period.id, DatePeriod.rangeId);
      expect(period.contains(DateTime(2026, 11, 3), now: DateTime(2030)), isTrue);
      expect(
        period.titleIn(DateStrings.fr),
        'Du 1er novembre au 7 novembre 2026',
      );
      expect(
        period.titleIn(DateStrings.en),
        'From November 1 to November 7, 2026',
      );
    });
  });

  test('a span formats its open sides', () {
    final day = DateTime(2026, 11, 3);
    expect(DateStrings.fr.formatSpan(DateSpan.day(day)), '3 novembre 2026');
    expect(
      DateStrings.fr.formatSpan(DateSpan(first: day)),
      'Depuis le 3 novembre 2026',
    );
    expect(DateStrings.en.formatSpan(DateSpan(last: day)), 'Until November 3, 2026');
  });
}
