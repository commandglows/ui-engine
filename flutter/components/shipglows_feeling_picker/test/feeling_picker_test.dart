import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feeling_picker/shipglows_feeling_picker.dart';
import 'package:shipglows_feelings/shipglows_feelings.dart';

/// Holds the selection like an app would.
class _Host extends StatefulWidget {
  const _Host({required this.seen, this.initial = const {}, this.max});

  final List<Set<String>> seen;
  final Set<String> initial;
  final int? max;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late Set<String> _selected = widget.initial;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: FeelingPicker(
        bank: FeelingBank.standard,
        suggestions: const ['calm', 'fatigue'],
        selected: _selected,
        maxSelected: widget.max,
        languageCode: 'fr',
        onChanged: (next) {
          widget.seen.add(next);
          setState(() => _selected = next);
        },
      ),
    ),
  );
}

Future<void> _openSheet(WidgetTester tester) async {
  await tester.tap(find.text('Voir tous les mots'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows suggestions, and a picked word outside them', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(seen: [], initial: const {'guilt'}));

    expect(find.text('Calme'), findsOneWidget);
    expect(find.text('Fatigue'), findsOneWidget);
    expect(find.text('Culpabilité'), findsOneWidget);
  });

  testWidgets('the sheet opens on families, closed, with examples', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(seen: []));
    await _openSheet(tester);

    expect(find.text('Joie et plaisir'), findsOneWidget);
    expect(find.textContaining('Joie, Bonheur'), findsOneWidget);
    expect(find.text('Ravissement'), findsNothing);
  });

  testWidgets('opening a family lets the person pick a word', (tester) async {
    final seen = <Set<String>>[];
    await tester.pumpWidget(_Host(seen: seen));
    await _openSheet(tester);

    await tester.tap(find.text('Joie et plaisir'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ravissement'));
    await tester.pumpAndSettle();

    expect(seen.last, {'delight'});
    expect(find.text('Mes mots'), findsOneWidget);
  });

  testWidgets('search finds a noun from an adjective', (tester) async {
    final seen = <Set<String>>[];
    await tester.pumpWidget(_Host(seen: seen));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'coupable');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Culpabilité'));
    await tester.pumpAndSettle();

    expect(seen.last, {'guilt'});
  });

  testWidgets('the person can add a word of their own', (tester) async {
    final seen = <Set<String>>[];
    await tester.pumpWidget(_Host(seen: seen));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'barbouillée');
    await tester.pumpAndSettle();
    expect(find.text('Aucun mot de la liste ne correspond.'), findsOneWidget);

    await tester.tap(find.text('Ajouter « barbouillée » comme mon mot'));
    await tester.pumpAndSettle();

    expect(seen.last, {'custom:barbouillée'});
    expect(find.text('barbouillée'), findsWidgets);
  });

  testWidgets('an exact word cannot be added again as a custom one', (
    tester,
  ) async {
    await tester.pumpWidget(_Host(seen: []));
    await _openSheet(tester);

    await tester.enterText(find.byType(TextField), 'colère');
    await tester.pumpAndSettle();

    expect(find.textContaining('comme mon mot'), findsNothing);
  });

  testWidgets('at the limit, says why and blocks a custom word', (tester) async {
    final seen = <Set<String>>[];
    await tester.pumpWidget(
      _Host(seen: seen, initial: const {'calm', 'fatigue'}, max: 2),
    );
    await _openSheet(tester);

    expect(find.textContaining('2 mots au plus'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'barbouillée');
    await tester.pumpAndSettle();
    final add = tester.widget<OutlinedButton>(
      find.ancestor(
        of: find.textContaining('comme mon mot'),
        matching: find.bySubtype<OutlinedButton>(),
      ),
    );
    expect(add.onPressed, isNull);
    expect(seen, isEmpty);
  });
}
