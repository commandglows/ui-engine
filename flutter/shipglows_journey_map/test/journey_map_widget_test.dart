import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_journey_map/shipglows_journey_map.dart';

import 'support/fixtures.dart';

Finder nodeKey(String id) => find.byKey(ValueKey('journey-node-$id'));

void main() {
  group('JourneyMap (column)', () {
    testWidgets('draws chapters and nodes and reports taps by id', (
      tester,
    ) async {
      String? tapped;
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: JourneyMap(
              chapters: [chapterOf('a', 3, current: 1)],
              animateCurrent: false,
              onSelect: (id) => tapped = id,
            ),
          ),
        ),
      );
      expect(find.text('Chapter a'), findsOneWidget);
      expect(find.text('Node 2'), findsOneWidget);
      await tester.tap(nodeKey('na-2'));
      expect(tapped, 'na-2');
    });

    testWidgets('nodes are inert without onSelect', (tester) async {
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: JourneyMap(
              chapters: [chapterOf('a', 2)],
              animateCurrent: false,
            ),
          ),
        ),
      );
      final semantics = tester.getSemantics(nodeKey('na-0'));
      expect(
        semantics.getSemanticsData().hasAction(SemanticsAction.tap),
        isFalse,
      );
    });

    testWidgets('semantics carry label, caption, state and position', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: JourneyMap(
              chapters: [chapterOf('a', 3, current: 1)],
              animateCurrent: false,
              selectedId: 'na-1',
              onSelect: (_) {},
              labels: JourneyMapLabels.en,
            ),
          ),
        ),
      );
      final done = tester.getSemantics(nodeKey('na-0'));
      expect(done.label, 'Node 0, Caption 0, done, 1 of 3');
      final current = tester.getSemantics(nodeKey('na-1'));
      expect(current.label, 'Node 1, Caption 1, current, 2 of 3');
      expect(
        current.getSemanticsData().flagsCollection.isSelected,
        Tristate.isTrue,
      );
      expect(current.getSemanticsData().flagsCollection.isButton, isTrue);
      final upcoming = tester.getSemantics(nodeKey('na-2'));
      expect(upcoming.label, 'Node 2, Caption 2, upcoming, 3 of 3');
      expect(
        tester.getSemantics(find.text('Chapter a')).label,
        'Chapter a, 3 stops',
      );
      handle.dispose();
    });

    testWidgets('a custom semantic label replaces the default', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        host(
          const JourneyMap(
            animateCurrent: false,
            chapters: [
              JourneyChapter(
                id: 'c',
                title: 'c',
                nodes: [
                  JourneyNode(id: 'x', label: 'X', semanticLabel: 'Custom'),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.getSemantics(nodeKey('x')).label, 'Custom');
      handle.dispose();
    });

    testWidgets('French labels come from the ambient locale', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Localizations.override(
              context: context,
              locale: const Locale('fr', 'FR'),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: JourneyMap(
                    chapters: [chapterOf('a', 2, current: 0)],
                    animateCurrent: false,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(nodeKey('na-0')).label,
        'Node 0, Caption 0, en cours, 1 sur 2',
      );
      handle.dispose();
    });

    testWidgets('right-to-left mirrors node positions', (tester) async {
      Future<double> centerOf(TextDirection direction) async {
        await tester.pumpWidget(
          host(
            SingleChildScrollView(
              child: JourneyMap(
                chapters: [chapterOf('a', 3)],
                animateCurrent: false,
              ),
            ),
            direction: direction,
          ),
        );
        return tester.getCenter(nodeKey('na-1')).dx;
      }

      final ltr = await centerOf(TextDirection.ltr);
      final rtl = await centerOf(TextDirection.rtl);
      expect(ltr + rtl, closeTo(420, 1));
      expect(ltr, isNot(closeTo(210, 1)));
    });

    testWidgets('large text, dark theme, tiny and huge widths never overflow', (
      tester,
    ) async {
      for (final size in const [
        Size(180, 800),
        Size(420, 900),
        Size(2200, 900),
      ]) {
        for (final scale in [1.0, 2.0, 3.0]) {
          await tester.pumpWidget(
            host(
              SingleChildScrollView(
                child: JourneyMap(
                  chapters: [
                    chapterOf('a', 4, current: 2),
                    JourneyChapter(
                      id: 'long',
                      title: 'A very long chapter title ' * 6,
                      nodes: [
                        JourneyNode(
                          id: 'l',
                          label: 'An extremely long node label ' * 8,
                          caption: 'And a long caption ' * 4,
                          marker: '2019',
                        ),
                      ],
                    ),
                  ],
                  animateCurrent: false,
                  onSelect: (_) {},
                ),
              ),
              size: size,
              textScale: scale,
              theme: ThemeData.dark(),
            ),
          );
          expect(tester.takeException(), isNull, reason: '$size x$scale');
        }
      }
    });

    testWidgets('content stays within the maximum width on large screens', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(2000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        host(
          SingleChildScrollView(
            child: JourneyMap(
              chapters: [chapterOf('a', 6)],
              animateCurrent: false,
            ),
          ),
          size: const Size(2000, 900),
        ),
      );
      for (var i = 0; i < 6; i++) {
        final x = tester.getCenter(nodeKey('na-$i')).dx;
        expect(x, inInclusiveRange(1000 - 280, 1000 + 280));
      }
    });

    testWidgets('a repeated id does not break the build', (tester) async {
      await tester.pumpWidget(
        host(
          const JourneyMap(
            animateCurrent: false,
            selectedId: 'same',
            chapters: [
              JourneyChapter(
                id: 'x',
                title: 'x',
                nodes: [
                  JourneyNode(id: 'same', label: 'one'),
                  JourneyNode(id: 'same', label: 'two'),
                ],
              ),
            ],
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty label and title fall back to untitled', (tester) async {
      await tester.pumpWidget(
        host(
          const JourneyMap(
            animateCurrent: false,
            labels: JourneyMapLabels.en,
            chapters: [
              JourneyChapter(
                id: 'x',
                title: '',
                nodes: [JourneyNode(id: 'a', label: '')],
              ),
            ],
          ),
        ),
      );
      expect(find.text('Untitled'), findsNWidgets(2));
    });

    testWidgets('a chapter without nodes shows its notice', (tester) async {
      await tester.pumpWidget(
        host(
          const JourneyMap(
            labels: JourneyMapLabels.en,
            chapters: [JourneyChapter(id: 'e', title: 'E', nodes: [])],
          ),
        ),
      );
      expect(find.text('Nothing in this chapter yet.'), findsOneWidget);
    });

    testWidgets('custom node builder replaces the cell', (tester) async {
      await tester.pumpWidget(
        host(
          JourneyMap(
            chapters: [chapterOf('a', 2)],
            nodeBuilder: (context, node, slot) => GestureDetector(
              onTap: slot.onTap,
              child: SizedBox(
                key: ValueKey('custom-${node.id}'),
                height: 48,
                child: Text('custom ${slot.position}/${slot.total}'),
              ),
            ),
            onSelect: (_) {},
          ),
        ),
      );
      expect(find.text('custom 1/2'), findsOneWidget);
      expect(nodeKey('na-0'), findsNothing);
    });
  });

  group('status states', () {
    testWidgets('empty, loading and error replace the map', (tester) async {
      var retried = 0;
      await tester.pumpWidget(
        host(const JourneyMap(chapters: [], labels: JourneyMapLabels.en)),
      );
      expect(find.text('Nothing here yet.'), findsOneWidget);

      await tester.pumpWidget(
        host(
          JourneyMap(
            chapters: [chapterOf('a', 2)],
            loading: true,
            labels: JourneyMapLabels.en,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Node 0'), findsNothing);

      await tester.pumpWidget(
        host(
          JourneyMap(
            chapters: const [],
            error: StateError('boom'),
            onRetry: () => retried++,
            labels: JourneyMapLabels.en,
          ),
        ),
      );
      await tester.tap(find.text('Try again'));
      expect(retried, 1);

      await tester.pumpWidget(
        host(
          JourneyMap(
            chapters: const [],
            emptyBuilder: (_) => const Text('custom empty'),
          ),
        ),
      );
      expect(find.text('custom empty'), findsOneWidget);
    });
  });

  group('motion', () {
    testWidgets('the current node pulses, and stops when motion is reduced', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(JourneyMap(chapters: [chapterOf('a', 3, current: 1)])),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isTrue);

      await tester.pumpWidget(
        host(
          JourneyMap(chapters: [chapterOf('a', 3, current: 1)]),
          disableAnimations: true,
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('SliverJourneyMap', () {
    final big = [
      for (var c = 0; c < 100; c++) chapterOf('$c', 100, current: 50),
    ];

    testWidgets('builds only the rows near the viewport', (tester) async {
      await tester.pumpWidget(
        host(
          JourneyMapView(chapters: big, animateCurrent: false),
          size: const Size(420, 900),
        ),
      );
      final built = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            '${(w.key! as ValueKey).value}'.startsWith('journey-node-'),
      );
      expect(built.evaluate().length, lessThan(40));
      expect(tester.takeException(), isNull);
    });

    testWidgets('controller scrolls to a node thousands of rows away', (
      tester,
    ) async {
      final controller = JourneyMapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          JourneyMapView(
            chapters: big,
            controller: controller,
            animateCurrent: false,
          ),
        ),
      );
      expect(nodeKey('n77-40'), findsNothing);
      expect(controller.offsetOfNode('n77-40'), isNotNull);
      final ok = await tester.runAsync(
        () => controller.scrollToNode('n77-40', duration: Duration.zero),
      );
      expect(ok, isTrue);
      await tester.pump();
      expect(nodeKey('n77-40'), findsOneWidget);
      final y = tester.getCenter(nodeKey('n77-40')).dy;
      expect(y, inInclusiveRange(0, 900));
    });

    testWidgets('unknown nodes and detached controllers return false', (
      tester,
    ) async {
      final controller = JourneyMapController();
      addTearDown(controller.dispose);
      expect(await controller.scrollToNode('x'), isFalse);
      expect(await controller.scrollToCurrent(), isFalse);
      await tester.pumpWidget(
        host(
          JourneyMapView(
            chapters: big,
            controller: controller,
            animateCurrent: false,
          ),
        ),
      );
      expect(await controller.scrollToNode('nope'), isFalse);
    });

    testWidgets('initialScrollToCurrent opens on the current node', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          JourneyMapView(
            chapters: [chapterOf('a', 200, current: 150)],
            initialScrollToCurrent: true,
            animateCurrent: false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(nodeKey('na-150'), findsOneWidget);
    });

    testWidgets('reduced motion jumps instead of animating', (tester) async {
      final controller = JourneyMapController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        host(
          JourneyMapView(
            chapters: [chapterOf('a', 300, current: 250)],
            controller: controller,
            animateCurrent: false,
          ),
          disableAnimations: true,
        ),
      );
      final future = controller.scrollToCurrent();
      await tester.pump();
      expect(nodeKey('na-250'), findsOneWidget);
      await future;
    });

    testWidgets('selection and taps work on a virtualised map', (tester) async {
      String? tapped;
      await tester.pumpWidget(
        host(
          JourneyMapView(
            chapters: [chapterOf('a', 50, current: 0)],
            animateCurrent: false,
            onSelect: (id) => tapped = id,
            selectedId: 'na-1',
          ),
        ),
      );
      await tester.tap(nodeKey('na-1'));
      expect(tapped, 'na-1');
    });

    testWidgets('loading and empty also work inside the sliver', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const JourneyMapView(chapters: [], labels: JourneyMapLabels.en)),
      );
      expect(find.text('Nothing here yet.'), findsOneWidget);
      await tester.pumpWidget(
        host(
          const JourneyMapView(
            chapters: [],
            loading: true,
            labels: JourneyMapLabels.en,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });

  group('goldens', () {
    for (final dark in [false, true]) {
      testWidgets('map ${dark ? 'dark' : 'light'}', (tester) async {
        await tester.binding.setSurfaceSize(const Size(420, 1000));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(
          RepaintBoundary(
            key: const ValueKey('golden'),
            child: host(
              SingleChildScrollView(
                child: JourneyMap(
                  chapters: [chapterOf('a', 4, current: 2), chapterOf('b', 2)],
                  animateCurrent: false,
                  selectedId: 'na-3',
                ),
              ),
              size: const Size(420, 1000),
              theme: dark ? ThemeData.dark() : ThemeData.light(),
            ),
          ),
        );
        await expectLater(
          find.byKey(const ValueKey('golden')),
          matchesGoldenFile('goldens/map_${dark ? 'dark' : 'light'}.png'),
        );
      });
    }
  });
}
