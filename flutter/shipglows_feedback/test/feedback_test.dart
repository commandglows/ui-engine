import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';

Future<BuildContext> _pumpApp(WidgetTester tester) async {
  late BuildContext context;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (c) {
            context = c;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );
  return context;
}

void main() {
  testWidgets('each kind shows its icon and is read with its name', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    context.showError('Could not save');
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    expect(find.bySemanticsLabel('Error: Could not save'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsOneWidget, reason: 'errors close');
  });

  testWidgets('the same message is not queued twice', (tester) async {
    final context = await _pumpApp(tester);
    final first = showFeedback(context, 'Offline', kind: FeedbackKind.warning);
    final again = showFeedback(context, 'Offline', kind: FeedbackKind.warning);
    expect(again, same(first));

    first!.close();
    await tester.pumpAndSettle();
    expect(find.text('Offline'), findsNothing, reason: 'nothing queued');

    final later = showFeedback(context, 'Offline', kind: FeedbackKind.warning);
    expect(later, isNot(same(first)), reason: 'shown again once closed');
  });

  testWidgets('replaceCurrent closes the message on screen', (tester) async {
    final context = await _pumpApp(tester);
    context.showInfo('Saved draft');
    await tester.pumpAndSettle();
    showFeedback(
      context,
      'Published',
      kind: FeedbackKind.success,
      replaceCurrent: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Saved draft'), findsNothing);
    expect(find.text('Published'), findsOneWidget);
  });

  testWidgets('the action runs and the kind sets the duration', (tester) async {
    final context = await _pumpApp(tester);
    var retried = 0;
    context.showWarning('Sync paused', actionLabel: 'Retry', onAction: () {
      retried++;
    });
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(retried, 1);

    context.showSuccess('Synced');
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Synced'), findsNothing);
  });

  test('French texts', () {
    expect(FeedbackStrings.fr.labelOf(FeedbackKind.warning), 'Avertissement');
  });
}
