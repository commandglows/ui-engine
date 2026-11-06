import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_tag_picker/shipglows_tag_picker.dart';

const _options = [
  TagOption(id: 'a', label: 'Alpha'),
  TagOption(id: 'b', label: 'Beta'),
  TagOption(id: 'c', label: 'Gamma'),
];

Widget _app(Set<String> selected, ValueChanged<Set<String>> onChanged) =>
    MaterialApp(
      home: Scaffold(
        body: TagPicker(
          title: 'Words',
          options: _options,
          selected: selected,
          onChanged: onChanged,
          maxSelected: 2,
          limitMessage: 'Two at most',
        ),
      ),
    );

void main() {
  testWidgets('adds and removes a word', (tester) async {
    Set<String>? changed;
    await tester.pumpWidget(_app({'a'}, (next) => changed = next));

    await tester.tap(find.text('Beta'));
    expect(changed, {'a', 'b'});

    await tester.tap(find.text('Alpha'));
    expect(changed, <String>{});
  });

  testWidgets('at the limit, says why and blocks only new words', (
    tester,
  ) async {
    Set<String>? changed;
    await tester.pumpWidget(_app({'a', 'b'}, (next) => changed = next));

    expect(find.text('Two at most'), findsOneWidget);
    await tester.tap(find.text('Gamma'), warnIfMissed: false);
    expect(changed, isNull);

    await tester.tap(find.text('Alpha'));
    expect(changed, {'b'});
  });

  testWidgets('keeps a selected id missing from the options', (tester) async {
    Set<String>? changed;
    await tester.pumpWidget(_app({'retired'}, (next) => changed = next));

    await tester.tap(find.text('Alpha'));
    expect(changed, {'retired', 'a'});
  });
}
