import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_guide/shipglows_guide.dart';

const _tour = GuideTour(
  id: 'tour',
  steps: [
    GuideStep(id: 'one', title: 'Title', body: 'Body', targetId: 'target'),
  ],
);

void main() {
  testWidgets('the card follows a moving target, reduce-motion stays idle', (
    tester,
  ) async {
    final controller = GuideController(tours: const [_tour]);
    final targetTop = ValueNotifier<double?>(50);
    addTearDown(controller.dispose);
    addTearDown(targetTop.dispose);

    await tester.pumpWidget(_app(controller, targetTop, reduceMotion: true));
    await controller.start('tour');
    await tester.pumpAndSettle();

    // Below the target: its bottom (90) + spotlight padding (6) + gap (10).
    expect(_cardRect(tester).top, 106);

    targetTop.value = 200;
    await tester.pumpAndSettle();

    expect(_cardRect(tester).top, 256);
  });

  testWidgets('an absent target or an ended tour leaves the screen idle', (
    tester,
  ) async {
    final controller = GuideController(tours: const [_tour]);
    final targetTop = ValueNotifier<double?>(null);
    addTearDown(controller.dispose);
    addTearDown(targetTop.dispose);

    await tester.pumpWidget(_app(controller, targetTop));
    await controller.start('tour');
    // Settles although the step waits for its target.
    await tester.pumpAndSettle();

    // Floating at the bottom: 600 - floating bottom offset (96).
    expect(_cardRect(tester).bottom, 504);

    // Measured after the frame that shows it; the card then fades in again.
    targetTop.value = 50;
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    expect(_cardRect(tester).top, 106);

    // The halo pulses around the shown target until the tour ends.
    controller.pause();
    await tester.pumpAndSettle();

    expect(find.text('Title'), findsNothing);
  });
}

Rect _cardRect(WidgetTester tester) => tester.getRect(
  find.ancestor(of: find.text('Title'), matching: find.byType(Material)).first,
);

Widget _app(
  GuideController controller,
  ValueNotifier<double?> targetTop, {
  bool reduceMotion = false,
}) {
  return MaterialApp(
    home: Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(disableAnimations: reduceMotion),
        child: GuideScope(
          controller: controller,
          child: Scaffold(
            body: ValueListenableBuilder<double?>(
              valueListenable: targetTop,
              builder: (context, top, _) => Stack(
                children: [
                  if (top != null)
                    Positioned(
                      left: 20,
                      top: top,
                      width: 100,
                      height: 40,
                      child: const GuideTarget(
                        id: 'target',
                        child: ColoredBox(color: Colors.blue),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
