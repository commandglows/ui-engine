import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_reflection_prompt/shipglows_reflection_prompt.dart';

Widget _app({
  required Future<bool> Function(String) onKeep,
  required ValueChanged<String> onMoveOn,
  String question = 'Question ?',
}) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: ReflectionPrompt(
        question: question,
        onKeep: onKeep,
        onMoveOn: onMoveOn,
      ),
    ),
  ),
);

void main() {
  const strings = ReflectionPromptStrings.fr;

  testWidgets('moving on needs no answer', (tester) async {
    String? draft;
    await tester.pumpWidget(
      _app(onKeep: (_) async => true, onMoveOn: (text) => draft = text),
    );

    expect(find.text(strings.keep), findsNothing);
    await tester.tap(find.text(strings.moveOn));
    expect(draft, '');
  });

  testWidgets('keeps a trimmed answer', (tester) async {
    String? kept;
    await tester.pumpWidget(
      _app(
        onKeep: (text) async {
          kept = text;
          return true;
        },
        onMoveOn: (_) {},
      ),
    );

    await tester.enterText(find.byType(TextField), '  ma réponse ');
    await tester.pump();
    await tester.tap(find.text(strings.keep));
    await tester.pump();
    expect(kept, 'ma réponse');
  });

  testWidgets('a failed keep leaves the text and says so', (tester) async {
    await tester.pumpWidget(
      _app(onKeep: (_) async => false, onMoveOn: (_) {}),
    );

    await tester.enterText(find.byType(TextField), 'ma réponse');
    await tester.pump();
    await tester.tap(find.text(strings.keep));
    await tester.pump();
    expect(find.text(strings.keepFailed), findsOneWidget);
    expect(find.text('ma réponse'), findsOneWidget);
  });

  testWidgets('moving on hands over the draft and forgets it', (tester) async {
    String? draft;
    await tester.pumpWidget(
      _app(onKeep: (_) async => true, onMoveOn: (text) => draft = text),
    );

    await tester.enterText(find.byType(TextField), 'brouillon');
    await tester.pump();
    await tester.tap(find.text(strings.moveOnWithoutKeeping));
    await tester.pump();
    expect(draft, 'brouillon');
    expect(find.text('brouillon'), findsNothing);
  });

  testWidgets('a new question forgets the draft', (tester) async {
    Widget app(String question) => _app(
      onKeep: (_) async => true,
      onMoveOn: (_) {},
      question: question,
    );
    await tester.pumpWidget(app('Première ?'));
    await tester.enterText(find.byType(TextField), 'brouillon');
    await tester.pumpWidget(app('Seconde ?'));
    expect(find.text('brouillon'), findsNothing);
  });

  testWidgets('leaving the foreground forgets the draft', (tester) async {
    await tester.pumpWidget(
      _app(onKeep: (_) async => true, onMoveOn: (_) {}),
    );
    await tester.enterText(find.byType(TextField), 'brouillon');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text('brouillon'), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  });
}
