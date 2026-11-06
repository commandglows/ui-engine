import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_patterns/shipglows_patterns.dart';

List<PatternObservation> _days(int count, double value, [Set<String>? tags]) =>
    List.generate(
      count,
      (_) => PatternObservation(value: value, tags: tags ?? const {}),
    );

void main() {
  test('stays silent below the minimum number of observations', () {
    final days = [
      ..._days(3, 0, {'work'}),
      ..._days(6, 1),
    ];
    expect(findPatterns(days), isEmpty);
  });

  test('stays silent when a side of the comparison is too small', () {
    final tooFewWith = [
      ..._days(2, 0, {'work'}),
      ..._days(10, 1),
    ];
    final tooFewWithout = [
      ..._days(10, 0, {'work'}),
      ..._days(2, 1),
    ];
    expect(findPatterns(tooFewWith), isEmpty);
    expect(findPatterns(tooFewWithout), isEmpty);
  });

  test('reports the two means and a negative gap', () {
    final days = [
      ..._days(4, 0, {'work'}),
      ..._days(6, 1),
    ];
    final finding = findPatterns(days).single;
    expect(finding.tag, 'work');
    expect(finding.countWith, 4);
    expect(finding.countWithout, 6);
    expect(finding.meanWith, 0);
    expect(finding.meanWithout, 1);
    expect(finding.gap, -1);
  });

  test('ignores a gap under the minimum and keeps one exactly at it', () {
    final small = [
      ..._days(5, 0.6, {'work'}),
      ..._days(5, 0.5),
    ];
    final exact = [
      ..._days(5, 0.75, {'work'}),
      ..._days(5, 0.5),
    ];
    expect(findPatterns(small), isEmpty);
    expect(findPatterns(exact).single.gap, closeTo(0.25, 1e-9));
  });

  test('orders by gap, then count, then tag', () {
    final days = [
      ..._days(4, 0, {'b', 'a'}),
      ..._days(1, 0, {'c'}),
      ..._days(3, 0.5, {'c'}),
      ..._days(8, 1),
    ];
    expect(findPatterns(days).map((f) => f.tag).toList(), ['a', 'b', 'c']);
  });

  test('ignores non-finite values', () {
    final days = [
      ..._days(4, 0, {'work'}),
      ..._days(6, 1),
      const PatternObservation(value: double.nan, tags: {'work'}),
    ];
    final finding = findPatterns(days).single;
    expect(finding.countWith, 4);
    expect(finding.gap, -1);
  });
}
