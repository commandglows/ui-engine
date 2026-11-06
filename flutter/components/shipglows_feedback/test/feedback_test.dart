import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_icons/shipglows_icons.dart';

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

    expect(find.byIcon(ShipglowsIcons.error), findsOneWidget);
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

  testWidgets('a messenger read before an await shows after the widget is gone', (
    tester,
  ) async {
    final context = await _pumpApp(tester);
    final feedback = FeedbackMessenger.of(context);
    await tester.pumpWidget(const SizedBox.shrink());
    feedback.showSuccess('Saved');
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsNothing, reason: 'its messenger is gone');
  });

  testWidgets('an error with details offers to copy them', (tester) async {
    final context = await _pumpApp(tester);
    context.showError('Could not publish', details: () => 'HTTP 500');
    await tester.pumpAndSettle();
    expect(find.text('Copy details'), findsOneWidget);
  });

  testWidgets('the app scope sets the texts', (tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        builder: (_, child) =>
            FeedbackStringsScope(strings: FeedbackStrings.fr, child: child!),
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
    context.showError('Échec');
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Erreur: Échec'), findsOneWidget);
  });

  testWidgets('inline message and error state', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              const FeedbackInline(
                message: 'Check the address',
                kind: FeedbackKind.warning,
              ),
              Expanded(
                child: FeedbackErrorState(
                  message: 'Could not load',
                  onRetry: () => retried++,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Warning: Check the address'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    expect(retried, 1);
  });

  testWidgets('an appearance scope sets the colors and the placement', (
    tester,
  ) async {
    late BuildContext context;
    const margin = EdgeInsets.fromLTRB(8, 0, 300, 120);
    await tester.pumpWidget(
      MaterialApp(
        home: FeedbackAppearanceScope(
          appearance: FeedbackAppearance(
            background: const Color(0xFF000001),
            foreground: const Color(0xFF000002),
            iconColorOf: (_) => const Color(0xFF000003),
            margin: () => margin,
          ),
          child: Scaffold(
            body: Builder(
              builder: (c) {
                context = c;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      ),
    );
    context.showInfo('Moved');
    await tester.pumpAndSettle();

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.margin, margin);
    expect(bar.width, isNull);
    expect(bar.backgroundColor, const Color(0xFF000001));
    expect(
      tester.widget<Text>(find.text('Moved')).style?.color,
      const Color(0xFF000002),
    );
    expect(
      tester.widget<Icon>(find.byIcon(ShipglowsIcons.info)).color,
      const Color(0xFF000003),
    );
  });

  test('French texts', () {
    expect(FeedbackStrings.fr.labelOf(FeedbackKind.warning), 'Avertissement');
  });
}
