import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_organize/shipglows_organize.dart';

void main() {
  group('normalizeLabels', () {
    test('keeps case and inner spaces, drops empties and duplicates', () {
      expect(normalizeLabels(' SEO Tips, , seo tips,Growth '), [
        'SEO Tips',
        'Growth',
      ]);
    });

    test('accepts a list and caps the count', () {
      expect(normalizeLabels(['a', 'b', 'c'], maxCount: 2), ['a', 'b']);
      expect(normalizeLabels(null), isEmpty);
    });
  });

  group('sortedBy', () {
    test('sorts both ways, stable, null keys last', () {
      final items = [('a', 2), ('b', null), ('c', 1), ('d', 2)];
      expect(sortedBy(items, (i) => i.$2).map((i) => i.$1), [
        'c',
        'a',
        'd',
        'b',
      ]);
      expect(
        sortedBy(
          items,
          (i) => i.$2,
          direction: SortDirection.descending,
        ).map((i) => i.$1),
        ['a', 'd', 'c', 'b'],
      );
    });

    test('works with dates', () {
      final dates = [DateTime(2026, 2), DateTime(2026, 1)];
      expect(sortedBy(dates, (d) => d), [DateTime(2026, 1), DateTime(2026, 2)]);
    });
  });
}
