import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_date_groups/shipglows_date_groups.dart';

final _now = DateTime(2026, 11, 6, 15);

List<DateGroup<DateTime>> _group(List<DateTime> dates, {int max = 3}) =>
    groupByDensity<DateTime>(
      dates,
      dateOf: (date) => date,
      now: _now,
      strings: DateStrings.fr,
      maxPerGroup: max,
    );

List<String> _titles(List<DateGroup<DateTime>> groups) => [
  for (final group in groups) group.title,
];

void main() {
  test('a quiet history keeps wide headings', () {
    final groups = _group([
      DateTime(2026, 11, 6, 8),
      DateTime(2026, 11, 5),
      DateTime(2026, 11, 2),
      DateTime(2026, 10, 20),
      DateTime(2026, 3, 2),
    ]);
    expect(_titles(groups), [
      'Aujourd’hui',
      'Hier',
      '7 derniers jours',
      'Il y a quelques semaines',
      'Plus ancien',
    ]);
  });

  test('a busy day is cut into hours, joined two by two', () {
    final groups = _group([
      DateTime(2026, 11, 6, 14, 50),
      DateTime(2026, 11, 6, 13, 30),
      DateTime(2026, 11, 6, 10, 30),
      DateTime(2026, 11, 6, 9, 30),
      DateTime(2026, 11, 6, 7, 30),
      DateTime(2026, 11, 6, 2, 30),
    ]);
    expect(_titles(groups), [
      'Il y a moins de 2 h',
      'Il y a 4 à 5 h',
      'Il y a 7 à 12 h',
    ]);
    expect(groups.first.items, hasLength(2));
  });

  test('an hour with many items stays whole', () {
    final groups = _group([
      for (var minute = 0; minute < 5; minute++)
        DateTime(2026, 11, 6, 10, minute + 1),
    ]);
    expect(_titles(groups), ['Il y a 4 h']);
  });

  test('a busy yesterday is cut into parts of the day', () {
    final groups = _group([
      DateTime(2026, 11, 5, 20),
      DateTime(2026, 11, 5, 14),
      DateTime(2026, 11, 5, 9),
      DateTime(2026, 11, 5, 8),
    ]);
    expect(_titles(groups), ['Hier soir', 'Hier après-midi', 'Hier matin']);
  });

  test('a busy week is cut into days', () {
    final groups = _group([
      for (final day in [4, 4, 3, 3]) DateTime(2026, 11, day),
    ]);
    expect(_titles(groups), ['Mercredi 4 novembre', 'Mardi 3 novembre']);
  });

  test('busy older items are cut by year, then month', () {
    final groups = _group([
      DateTime(2026, 9, 2),
      DateTime(2026, 8, 2),
      DateTime(2025, 3, 3),
      DateTime(2025, 3, 2),
      DateTime(2025, 2, 2),
      DateTime(2025, 1, 2),
    ]);
    expect(_titles(groups), [
      '2026',
      'Mars 2025',
      'Février 2025',
      'Janvier 2025',
    ]);
  });

  test('every item is kept once and undated items stay last', () {
    final dates = <DateTime?>[
      null,
      for (var hour = 0; hour < 15; hour++) DateTime(2026, 11, 6, hour),
    ];
    final groups = groupByDensity<DateTime?>(
      dates,
      dateOf: (date) => date,
      now: _now,
      strings: DateStrings.en,
    );
    expect(groups.last.id, 'undated');
    expect(groups.expand((group) => group.items), hasLength(dates.length));
    expect(groups.map((group) => group.id).toSet(), hasLength(groups.length));
  });
}
