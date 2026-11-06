import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_bulk_delete/shipglows_bulk_delete.dart';
import 'package:shipglows_date_sections/shipglows_date_sections.dart';

void main() {
  final now = DateTime.now();
  final recent = now.subtract(const Duration(minutes: 5));
  final old = now.subtract(const Duration(days: 40));

  final entries = [
    BulkDeleteEntry(id: 'v1', category: 'voice', date: recent),
    BulkDeleteEntry(id: 'v2', category: 'voice', date: old),
    BulkDeleteEntry(id: 'c1', category: 'clip', date: recent, protected: true),
    BulkDeleteEntry(id: 's1', category: 'snip', date: recent),
    const BulkDeleteEntry(id: 'n1', category: 'voice', date: null),
  ];

  Future<List<BulkDeleteEntry>?> Function() open(WidgetTester tester) {
    return () async {
      List<BulkDeleteEntry>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                result = await showBulkDeleteDialog(
                  context: context,
                  categories: const [
                    BulkDeleteCategory(id: 'voice', label: 'Voix'),
                    BulkDeleteCategory(id: 'clip', label: 'Copies'),
                    BulkDeleteCategory(
                      id: 'snip',
                      label: 'Snippets',
                      selected: false,
                    ),
                  ],
                  entries: entries,
                );
              },
              child: const Text('Ouvrir'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Ouvrir'));
      await tester.pumpAndSettle();
      return result;
    };
  }

  testWidgets('starts on the last hour, unpinned, chosen types only', (
    tester,
  ) async {
    await open(tester)();
    expect(find.text('Supprimer 1 élément'), findsOneWidget);
    expect(find.text('Voix · 1'), findsOneWidget);
    expect(find.text('Snippets · 1'), findsOneWidget);
    expect(find.text('Inclure l’élément épinglé'), findsOneWidget);
  });

  testWidgets('Tout reaches old and undated items', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Tout'));
    await tester.pump();
    expect(find.text('Supprimer 3 éléments'), findsOneWidget);
  });

  testWidgets('pinned items count once included', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Inclure l’élément épinglé'));
    await tester.pump();
    expect(find.text('Supprimer 2 éléments'), findsOneWidget);
  });

  testWidgets('nothing chosen disables the button', (tester) async {
    await open(tester)();
    await tester.tap(find.text('Voix · 1'));
    await tester.pump();
    expect(find.text('Rien à supprimer'), findsOneWidget);
    final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
    expect(button.onPressed, isNull);
  });

  test('the last hour is measured in time, not days', () {
    final at = DateTime(2026, 11, 6, 15);
    final period = DatePeriod.lastHour;
    expect(period.contains(DateTime(2026, 11, 6, 14, 30), now: at), isTrue);
    expect(period.contains(DateTime(2026, 11, 6, 13, 59), now: at), isFalse);
  });
}
