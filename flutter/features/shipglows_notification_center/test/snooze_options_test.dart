import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_notification_center/shipglows_notification_center.dart';

/// A Friday afternoon.
final _now = DateTime(2026, 11, 6, 15, 33);

void main() {
  group('SnoozeOption.nextAt', () {
    test('a delay counts from now', () {
      expect(
        const SnoozeAfter(3, SnoozeUnit.hours).nextAt(_now),
        DateTime(2026, 11, 6, 18, 33),
      );
    });

    test('today has passed once its time is gone', () {
      const evening = SnoozeAt(SnoozeDay.today, ReminderTime(18, 0));
      expect(evening.nextAt(_now), DateTime(2026, 11, 6, 18));
      expect(evening.nextAt(DateTime(2026, 11, 6, 18)), isNull);
    });

    test('a weekday is the next one after today', () {
      const monday = SnoozeAt(SnoozeDay.monday, ReminderTime(9, 0));
      const friday = SnoozeAt(SnoozeDay.friday, ReminderTime(9, 0));
      expect(monday.nextAt(_now), DateTime(2026, 11, 9, 9));
      expect(friday.nextAt(_now), DateTime(2026, 11, 13, 9));
    });
  });

  group('SnoozeOptions', () {
    test('the menu is soonest first, without what has passed', () {
      final menu = SnoozeOptions().menu(DateTime(2026, 11, 6, 19));
      expect(menu.map((c) => c.option.id), [
        'after:1:hours',
        'after:3:hours',
        'at:tomorrow:09:00',
        'at:monday:09:00',
      ]);
    });

    test('two options on the same minute show once', () {
      final options = SnoozeOptions(const [
        SnoozeAfter(1, SnoozeUnit.hours),
        SnoozeAfter(60, SnoozeUnit.minutes),
      ]);
      expect(options.menu(_now), hasLength(1));
    });

    test('keeps a row and refuses to go over the limit', () {
      final one = SnoozeOptions(const [SnoozeAfter(1, SnoozeUnit.hours)]);
      expect(one.removingAt(0), one);
      var full = SnoozeOptions();
      while (full.canAdd) {
        full = full.adding(const SnoozeAfter(5, SnoozeUnit.minutes));
      }
      expect(
        full.adding(const SnoozeAfter(9, SnoozeUnit.minutes)).options,
        hasLength(SnoozeOptions.maxOptions),
      );
    });

    test('goes through JSON and skips unusable rows', () {
      final options = SnoozeOptions();
      expect(SnoozeOptions.fromJson(options.toJson()), options);
      expect(
        SnoozeOptions.fromJson(['after:0:hours', 'nope', 'at:friday:09:00'])!
            .options,
        const [SnoozeAt(SnoozeDay.friday, ReminderTime(9, 0))],
      );
      expect(SnoozeOptions.fromJson(['nope']), isNull);
    });
  });

  test('the label says the moment in words', () {
    const strings = SnoozeStrings.en;
    expect(strings.label(const SnoozeAfter(1, SnoozeUnit.hours)), 'In 1 hour');
    expect(
      strings.label(const SnoozeAt(SnoozeDay.today, ReminderTime(18, 0))),
      'This evening',
    );
    expect(
      strings.label(const SnoozeAt(SnoozeDay.monday, ReminderTime(9, 0))),
      'Next week',
    );
  });

  group('SnoozeOptionsEditor', () {
    Future<List<SnoozeOptions>> pump(
      WidgetTester tester,
      SnoozeOptions value,
    ) async {
      final changes = <SnoozeOptions>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SnoozeOptionsEditor(
                value: value,
                onChanged: changes.add,
                now: () => _now,
              ),
            ),
          ),
        ),
      );
      return changes;
    }

    testWidgets('shows the menu as it reads now', (tester) async {
      await pump(tester, SnoozeOptions());
      expect(
        find.text(
          'Menu now: In 1 hour · This evening · In 3 hours · Tomorrow · '
          'Next week',
        ),
        findsOneWidget,
      );
    });

    testWidgets('the stepper changes the amount', (tester) async {
      final changes = await pump(
        tester,
        SnoozeOptions(const [SnoozeAfter(1, SnoozeUnit.hours)]),
      );
      await tester.tap(find.byTooltip('More'));
      expect(changes.single.options.single, const SnoozeAfter(2, SnoozeUnit.hours));
    });

    testWidgets('the last row cannot be removed', (tester) async {
      final changes = await pump(
        tester,
        SnoozeOptions(const [SnoozeAfter(1, SnoozeUnit.hours)]),
      );
      await tester.tap(find.byTooltip('Remove In 1 hour'));
      expect(changes, isEmpty);
    });

    testWidgets('adds an option', (tester) async {
      final changes = await pump(tester, SnoozeOptions());
      await tester.tap(find.byKey(const ValueKey('snooze-option-add')));
      expect(changes.single.options, hasLength(6));
    });
  });

  testWidgets('SnoozeButton gives back the chosen moment', (tester) async {
    DateTime? chosen;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SnoozeButton(
            options: SnoozeOptions(),
            onSelected: (at) => chosen = at,
            now: () => _now,
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Snooze'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tomorrow'));
    await tester.pumpAndSettle();
    expect(chosen, DateTime(2026, 11, 7, 9));
  });
}
