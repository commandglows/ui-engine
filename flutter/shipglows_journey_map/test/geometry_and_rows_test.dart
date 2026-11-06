import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_journey_map/shipglows_journey_map.dart';

import 'support/fixtures.dart';

void main() {
  group('JourneyGeometry', () {
    test('keeps every node inside the margins for any width', () {
      for (final width in [120.0, 200, 320, 420, 800, 2000]) {
        for (var i = 0; i < 200; i++) {
          final x = JourneyGeometry.centerX(
            i,
            width.toDouble(),
            nodeRadius: 28,
          );
          final inset = width > 160 ? 24.0 + 28 : 0.0;
          expect(x, inInclusiveRange(inset - 1e-9, width - inset + 1e-9));
        }
      }
    });

    test('first node is centred', () {
      expect(JourneyGeometry.centerX(0, 400, nodeRadius: 28), 200);
    });

    test('rtl mirrors every node around the centre', () {
      for (var i = 0; i < 30; i++) {
        final ltr = JourneyGeometry.centerX(i, 400, nodeRadius: 28);
        final rtl = JourneyGeometry.centerX(i, 400, nodeRadius: 28, rtl: true);
        expect(ltr + rtl, closeTo(400, 1e-9));
      }
    });

    test('segment starts and ends on the two centres', () {
      final path = JourneyGeometry.segment(
        const Offset(10, 20),
        const Offset(90, 160),
      );
      final bounds = path.getBounds();
      expect(bounds.top, closeTo(20, 1e-6));
      expect(bounds.bottom, closeTo(160, 1e-6));
      expect(bounds.left, closeTo(10, 1e-6));
      expect(bounds.right, closeTo(90, 1e-6));
    });

    test('metrics grow with the text scale and keep rows disjoint', () {
      final small = JourneyMetrics.from(nodeRadius: 28, scaleOf: (s) => s);
      final large = JourneyMetrics.from(nodeRadius: 28, scaleOf: (s) => s * 2);
      expect(large.rowExtent, greaterThan(small.rowExtent));
      expect(large.headerExtent, greaterThan(small.headerExtent));
      expect(large.cellWidth, greaterThan(small.cellWidth));
      // Two label lines and a caption must end inside the row.
      for (final scale in [1.0, 2.0]) {
        final m = JourneyMetrics.from(
          nodeRadius: 28,
          scaleOf: (s) => s * scale,
        );
        final labelBottom = m.centerY + m.nodeRadius + 4 + 3 * 14 * scale * 1.4;
        expect(labelBottom, lessThanOrEqualTo(m.rowExtent));
      }
    });
  });

  group('JourneyRows', () {
    final chapters = [
      chapterOf('a', 3, current: 1),
      const JourneyChapter(id: 'e', title: 'Empty', nodes: []),
      chapterOf('b', 2),
    ];
    final rows = JourneyRows.from(chapters);

    test('flattens headers, nodes and the empty notice in order', () {
      expect(rows.rows.map((r) => r.kind).toList(), [
        JourneyRowKind.header,
        JourneyRowKind.node,
        JourneyRowKind.node,
        JourneyRowKind.node,
        JourneyRowKind.header,
        JourneyRowKind.emptyChapter,
        JourneyRowKind.header,
        JourneyRowKind.node,
        JourneyRowKind.node,
      ]);
      expect(rows.nodeCount, 5);
    });

    test('links previous and next nodes inside a chapter only', () {
      final first = rows.rows[1];
      expect(first.previous, isNull);
      expect(first.next?.id, 'na-1');
      final last = rows.rows[3];
      expect(last.previous?.id, 'na-1');
      expect(last.next, isNull);
      expect(rows.rows[7].previous, isNull);
    });

    test('offsets are prefix sums of header and row extents', () {
      const h = 60.0;
      const r = 140.0;
      expect(rows.offsetOf(0, h, r), 0);
      expect(rows.offsetOf(1, h, r), h);
      expect(rows.offsetOf(3, h, r), h + 2 * r);
      expect(rows.offsetOf(7, h, r), 4 * h + 3 * r);
      expect(rows.totalExtent(h, r), 4 * h + 5 * r);
      expect(
        rows.totalExtent(h, r),
        List.generate(
          rows.length,
          (i) => rows.extentOf(i, h, r),
        ).reduce((a, b) => a + b),
      );
    });

    test('finds the current node and the first row of an id', () {
      expect(rows.currentNodeId, 'na-1');
      expect(rows.indexOfNode('nb-1'), 8);
      expect(rows.indexOfNode('missing'), isNull);
    });

    test('a repeated id resolves to its first row without failing', () {
      final dup = JourneyRows.from([
        const JourneyChapter(
          id: 'x',
          title: 'x',
          nodes: [
            JourneyNode(id: 'same', label: 'one'),
            JourneyNode(id: 'same', label: 'two'),
          ],
        ),
      ]);
      expect(dup.indexOfNode('same'), 1);
      expect(dup.nodeCount, 2);
    });

    test('flattens a hundred thousand nodes quickly', () {
      final big = [for (var c = 0; c < 1000; c++) chapterOf('$c', 100)];
      final watch = Stopwatch()..start();
      final flat = JourneyRows.from(big);
      watch.stop();
      expect(flat.nodeCount, 100000);
      expect(flat.length, 101000);
      expect(watch.elapsedMilliseconds, lessThan(2000));
      expect(flat.offsetOf(flat.length, 60, 140), 1000 * 60 + 100000 * 140);
    });
  });
}
