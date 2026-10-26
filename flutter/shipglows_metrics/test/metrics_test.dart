import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_metrics/shipglows_metrics.dart';

void main() {
  test('a change is good or bad as its polarity says', () {
    expect(const MetricDelta(0.12).isFavorable, isTrue);
    expect(const MetricDelta(-0.12).isFavorable, isFalse);
    expect(
      const MetricDelta(0.12, polarity: MetricPolarity.lowerIsBetter)
          .isFavorable,
      isFalse,
    );
    expect(const MetricDelta(0.001).direction, MetricDirection.flat);
    expect(const MetricDelta(0.001).isFavorable, isNull);
  });

  test('a default percentage is signed and localized', () {
    expect(MetricStrings.en.formatDelta(const MetricDelta(0.12)), '+12%');
    expect(
      MetricStrings.fr.formatDelta(const MetricDelta(-0.04)),
      '−4 %',
    );
    expect(
      MetricStrings.fr.formatDelta(const MetricDelta(-0.025)),
      '−2,5 %',
    );
    expect(
      MetricStrings.en.formatDelta(const MetricDelta(0.5, label: '+340')),
      '+340',
    );
  });

  testWidgets('a tile is read as one sentence', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: MetricTile(
            Metric(
              label: 'Revenue',
              value: '1,240 €',
              delta: MetricDelta(0.12),
              series: [1, 3, 2, 5],
              caption: 'vs. last week',
            ),
          ),
        ),
      ),
    );
    expect(
      find.bySemanticsLabel('Revenue, 1,240 €, up +12%, vs. last week'),
      findsOneWidget,
    );
  });
}
