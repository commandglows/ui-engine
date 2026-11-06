import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_timeline/shipglows_timeline.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('draws groups, entries and tags, skipping empty groups', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const TimelineView(
          groups: [
            TimelineGroup(id: 'none', title: 'Empty group', entries: []),
            TimelineGroup(
              id: 'g',
              title: 'November',
              entries: [
                TimelineEntry(
                  id: 'e',
                  title: 'Friday',
                  subtitle: 'Fine',
                  tags: ['Calm'],
                ),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Empty group'), findsNothing);
    expect(find.text('November'), findsOneWidget);
    expect(find.text('Friday'), findsOneWidget);
    expect(find.text('Fine'), findsOneWidget);
    expect(find.text('Calm'), findsOneWidget);
  });

  testWidgets('shows the header and the empty widget without entries', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(
        const TimelineView(
          groups: [],
          header: Text('Header'),
          empty: Text('Nothing yet'),
        ),
      ),
    );

    expect(find.text('Header'), findsOneWidget);
    expect(find.text('Nothing yet'), findsOneWidget);
  });

  testWidgets('a tappable entry reports the tap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _app(
        TimelineView(
          groups: [
            TimelineGroup(
              id: 'g',
              title: 'November',
              entries: [
                TimelineEntry(id: 'e', title: 'Friday', onTap: () => taps++),
              ],
            ),
          ],
        ),
      ),
    );

    await tester.tap(find.text('Friday'));
    expect(taps, 1);
  });

  testWidgets('builds rows lazily', (tester) async {
    await tester.pumpWidget(
      _app(
        TimelineView(
          groups: [
            TimelineGroup(
              id: 'g',
              title: 'Long',
              entries: [
                for (var i = 0; i < 2000; i++)
                  TimelineEntry(id: '$i', title: 'Row $i'),
              ],
            ),
          ],
        ),
      ),
    );

    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text('Row 1999'), findsNothing);
  });
}
