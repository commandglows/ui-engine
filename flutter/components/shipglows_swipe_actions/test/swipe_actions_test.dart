import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_swipe_actions/shipglows_swipe_actions.dart';

Widget row({
  FutureOr<void> Function()? action,
  VoidCallback? tap,
  bool commit = false,
  void Function(Object, StackTrace)? error,
  SwipeActionsController? controller,
}) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topLeft,
      child: SizedBox(
        width: 400,
        child: ShipglowsSwipeActions(
          revealLabel: 'Actions',
          closeLabel: 'Close',
          controller: controller,
          commitStart: commit,
          onError: error,
          clickBindings: const [
            SwipeClickBinding(
              side: SwipeActionSide.start,
              alt: true,
              shift: true,
            ),
          ],
          startActions: [
            SwipeRowAction(
              label: 'Archive',
              icon: Icons.archive,
              onInvoke: action ?? () {},
            ),
          ],
          endActions: [
            SwipeRowAction(label: 'Copy', icon: Icons.copy, onInvoke: () {}),
          ],
          child: SizedBox(
            height: 80,
            child: InkWell(
              onTap: tap,
              child: const Center(child: Text('Message')),
            ),
          ),
        ),
      ),
    ),
  ),
);

void main() {
  testWidgets('Escape closes after long press without clicking an action', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(row(action: () => calls++));
    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long press reveals without invoking or activating the child', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(row(action: () => calls++, tap: () => calls++));
    await tester.longPress(find.text('Message'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsOneWidget);
    expect(calls, 0);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(find.text('Copy'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'modifier click claims child tap only for the exact combination',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(row(tap: () => taps++));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.tap(find.text('Message'));
      await tester.pumpAndSettle();
      expect(taps, 1);
      expect(find.text('Archive'), findsOneWidget);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('short drag reveals; reversing a full drag cancels execution', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(row(commit: true, action: () => calls++));
    final gesture = await tester.startGesture(const Offset(40, 40));
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(260, 0));
    await tester.pump(const Duration(milliseconds: 80));
    expect(find.text('Archive'), findsOneWidget);
    await gesture.moveBy(const Offset(-250, 0));
    await tester.pump(const Duration(milliseconds: 100));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(calls, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'full swipe runs once and stays locked while callback is pending',
    (tester) async {
      final pending = Completer<void>();
      var calls = 0;
      await tester.pumpWidget(
        row(
          commit: true,
          action: () {
            calls++;
            return pending.future;
          },
        ),
      );
      await tester.timedDragFrom(
        tester.getCenter(find.text('Message')),
        const Offset(300, 0),
        const Duration(milliseconds: 400),
      );
      for (var frame = 0; frame < 12; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(calls, 1);
      await tester.tapAt(const Offset(40, 40));
      await tester.pump();
      expect(calls, 1);
      pending.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed action restores revealed controls and reports the error',
    (tester) async {
      final controller = SwipeActionsController();
      Object? reported;
      await tester.pumpWidget(
        row(
          controller: controller,
          action: () => throw StateError('offline'),
          error: (error, _) => reported = error,
        ),
      );
      controller.reveal(SwipeActionSide.start);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();
      expect(reported, isA<StateError>());
      expect(find.text('Archive'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    },
  );
}
