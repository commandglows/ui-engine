import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_journey_map/shipglows_journey_map.dart';

void main() {
  group('default palette contrast', () {
    for (final brightness in Brightness.values) {
      test('node content is readable on ${brightness.name} schemes', () {
        for (final seed in [
          Colors.teal,
          Colors.indigo,
          Colors.orange,
          Colors.pink,
          Colors.brown,
        ]) {
          final scheme = ColorScheme.fromSeed(
            seedColor: seed,
            brightness: brightness,
          );
          final palette = JourneyPalette.resolve(
            scheme,
            const JourneyMapTheme(),
          );
          for (final state in JourneyNodeState.values) {
            final paint = palette.paintFor(state);
            expect(
              journeyContrastRatio(paint.fill, paint.onFill),
              greaterThanOrEqualTo(4.5),
              reason: '${seed.toARGB32()} $state ${brightness.name}',
            );
          }
          expect(
            journeyContrastRatio(scheme.surface, palette.label),
            greaterThanOrEqualTo(4.5),
          );
        }
      });
    }

    test(
      'a custom fill without onNodeColor picks the more readable content',
      () {
        final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
        for (final fill in [
          Colors.black,
          Colors.white,
          const Color(0xFFF0B35B),
          const Color(0xFF3F6B55),
        ]) {
          final palette = JourneyPalette.resolve(
            scheme,
            JourneyMapTheme(neutralColor: fill),
          );
          final chosen = palette.paintFor(JourneyNodeState.neutral).onFill;
          const white = Color(0xFFFFFFFF);
          final other = chosen == white ? const Color(0xFF000000) : white;
          expect(
            journeyContrastRatio(fill, chosen),
            greaterThanOrEqualTo(
              journeyContrastRatio(fill, Color.alphaBlend(other, fill)) - 1.0,
            ),
          );
        }
      },
    );

    test('node border separates a filled node from the page', () {
      final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
      final palette = JourneyPalette.resolve(scheme, const JourneyMapTheme());
      expect(palette.paintFor(JourneyNodeState.done).border, scheme.surface);
      expect(
        palette.paintFor(JourneyNodeState.upcoming).border,
        scheme.outline,
      );
    });
  });

  group('JourneyMapTheme', () {
    test('merge lets the later theme win and keeps the rest', () {
      const base = JourneyMapTheme(pathWidth: 10, nodeRadius: 20);
      final merged = base.merge(const JourneyMapTheme(nodeRadius: 30));
      expect(merged.pathWidth, 10);
      expect(merged.nodeRadius, 30);
      expect(base.merge(null), same(base));
    });

    test('copyWith and lerp behave', () {
      const a = JourneyMapTheme(pathColor: Color(0xFF000000), pathWidth: 10);
      final b = a.copyWith(pathColor: const Color(0xFFFFFFFF), pathWidth: 20);
      final mid = a.lerp(b, 0.5);
      expect(mid.pathWidth, 15);
      expect(mid.pathColor, isNot(a.pathColor));
      expect(a.lerp(null, 0.5), same(a));
    });

    testWidgets('is read from the app theme and overridden by the widget', (
      tester,
    ) async {
      late JourneyMapTheme seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: const [JourneyMapTheme(pathWidth: 22, nodeRadius: 40)],
          ),
          home: Builder(
            builder: (context) {
              seen = JourneyMapTheme.of(
                context,
              ).merge(const JourneyMapTheme(nodeRadius: 33));
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen.pathWidth, 22);
      expect(seen.nodeRadius, 33);
    });
  });

  group('JourneyMapLabels', () {
    test('picks French or English from the locale', () {
      expect(
        JourneyMapLabels.forLocale(const Locale('fr', 'FR')).done,
        'terminé',
      );
      expect(JourneyMapLabels.forLocale(const Locale('de')).done, 'done');
    });

    test('fills placeholders and copies', () {
      expect(
        JourneyMapLabels.fill('{title}, {count} stops', {
          'title': 'A',
          'count': 3,
        }),
        'A, 3 stops',
      );
      final custom = JourneyMapLabels.en.copyWith(current: 'latest');
      expect(custom.stateName(JourneyNodeState.current), 'latest');
      expect(custom.stateName(JourneyNodeState.neutral), '');
    });
  });
}
