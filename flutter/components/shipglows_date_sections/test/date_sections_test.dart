import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_date_sections/shipglows_date_sections.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('draws headings and rows, skipping empty groups', (tester) async {
    await tester.pumpWidget(
      _app(
        DateSectionsView<String>(
          groups: const [
            DateGroup(id: 'none', title: 'Vide', items: []),
            DateGroup(id: 'today', title: 'Aujourd’hui', items: ['Note']),
          ],
          itemBuilder: (context, item) => Text(item),
        ),
      ),
    );
    expect(find.text('Vide'), findsNothing);
    expect(find.text('Aujourd’hui'), findsOneWidget);
    expect(find.text('Note'), findsOneWidget);
  });

  testWidgets('shows the empty widget when nothing is left', (tester) async {
    await tester.pumpWidget(
      _app(
        DateSectionsView<String>(
          groups: const [],
          itemBuilder: (context, item) => Text(item),
          empty: const Text('Rien ici'),
        ),
      ),
    );
    expect(find.text('Rien ici'), findsOneWidget);
  });

  testWidgets('the filter reports a named period and everything', (
    tester,
  ) async {
    final changes = <DatePeriod?>[];
    Widget filter(DatePeriod? value) => _app(
      DatePeriodFilter(
        value: value,
        onChanged: changes.add,
        strings: DateStrings.fr,
      ),
    );

    await tester.pumpWidget(filter(null));
    await tester.tap(find.text('Hier'));
    expect(changes.single?.id, 'yesterday');

    await tester.pumpWidget(filter(DatePeriod.yesterday));
    await tester.tap(find.text('Hier'));
    expect(changes, hasLength(1), reason: 'the same choice changes nothing');

    await tester.tap(find.text('Tout'));
    expect(changes.last, isNull);
  });

  testWidgets('the filter names the chosen range on the custom chip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        DatePeriodFilter(
          value: DatePeriod.range(
            DateSpan(first: DateTime(2026, 11, 3), last: DateTime(2026, 11, 7)),
          ),
          onChanged: (_) {},
          strings: DateStrings.fr,
        ),
      ),
    );
    expect(find.text('Du 3 novembre au 7 novembre 2026'), findsOneWidget);
    expect(find.text('Personnalisé'), findsNothing);
  });

  testWidgets('the custom chip opens the range picker', (tester) async {
    await tester.pumpWidget(
      _app(
        DatePeriodFilter(
          value: null,
          onChanged: (_) {},
          strings: DateStrings.en,
        ),
      ),
    );
    await tester.tap(find.text('Custom'));
    await tester.pumpAndSettle();
    expect(find.byType(DateRangePickerDialog), findsOneWidget);
  });
}
