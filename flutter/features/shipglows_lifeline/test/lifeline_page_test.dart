import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_lifeline/shipglows_lifeline.dart';

class _Launcher {
  _Launcher({this.reached = true});

  final bool reached;
  final List<String> calls = [];

  Future<bool> call(LifelineContact contact) async {
    calls.add(contact.number);
    return reached;
  }
}

LifelineContent _content({VoidCallback? onBreathe}) => LifelineContent(
  title: 'Un titre',
  message: 'Un message',
  reason: 'Une raison',
  dismissLabel: 'Pas maintenant',
  callFailed: (number) => 'Compose le $number',
  suggestions: [
    const LifelineSuggestion.contact(
      FrenchHelplines.suicidePrevention,
      emphasis: LifelineEmphasis.strong,
    ),
    LifelineSuggestion.action(
      title: 'Respirer',
      emphasis: LifelineEmphasis.quiet,
      onSelected: onBreathe ?? () {},
    ),
  ],
);

Widget _host(LifelineContent content, _Launcher launcher) => MaterialApp(
  home: Builder(
    builder: (context) => Scaffold(
      body: TextButton(
        onPressed: () => showLifelinePage(
          context: context,
          content: content,
          onContact: launcher.call,
        ),
        child: const Text('Ouvrir'),
      ),
    ),
  ),
);

Future<void> _open(WidgetTester tester) async {
  await tester.tap(find.text('Ouvrir'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('says what the app wrote, with the number in plain text', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_content(), _Launcher()));
    await _open(tester);

    expect(find.text('Un titre'), findsOneWidget);
    expect(find.text('Une raison'), findsOneWidget);
    expect(find.textContaining('3114'), findsOneWidget);
    expect(find.text('Pas maintenant'), findsOneWidget);
  });

  testWidgets('a contact calls and keeps the page open', (tester) async {
    final launcher = _Launcher();
    await tester.pumpWidget(_host(_content(), launcher));
    await _open(tester);

    await tester.tap(find.textContaining('3114'));
    await tester.pumpAndSettle();

    expect(launcher.calls, ['3114']);
    expect(find.text('Un titre'), findsOneWidget);
    expect(find.text('Compose le 3114'), findsNothing);
  });

  testWidgets('a failed call gives the number to dial by hand', (tester) async {
    await tester.pumpWidget(_host(_content(), _Launcher(reached: false)));
    await _open(tester);

    await tester.tap(find.textContaining('3114'));
    await tester.pumpAndSettle();

    expect(find.text('Compose le 3114'), findsOneWidget);
  });

  testWidgets('an action closes the page, then runs', (tester) async {
    var breathed = 0;
    await tester.pumpWidget(
      _host(_content(onBreathe: () => breathed++), _Launcher()),
    );
    await _open(tester);

    await tester.tap(find.text('Respirer'));
    await tester.pumpAndSettle();

    expect(breathed, 1);
    expect(find.text('Un titre'), findsNothing);
  });

  testWidgets('leaving takes one tap', (tester) async {
    await tester.pumpWidget(_host(_content(), _Launcher()));
    await _open(tester);

    await tester.tap(find.text('Pas maintenant'));
    await tester.pumpAndSettle();

    expect(find.text('Un titre'), findsNothing);
    expect(find.text('Ouvrir'), findsOneWidget);
  });

  testWidgets('the system back gesture also leaves', (tester) async {
    await tester.pumpWidget(_host(_content(), _Launcher()));
    await _open(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(find.text('Un titre'), findsNothing);
  });
}
