import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_undo_trash/shipglows_undo_trash.dart';

class _Item {
  const _Item(this.id, this.title, this.kind, this.deletedAt);

  final String id;
  final String title;
  final String kind;
  final DateTime deletedAt;
}

Future<void> _ctrl(
  WidgetTester tester,
  LogicalKeyboardKey key, {
  bool shift = false,
}) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

void main() {
  group('UndoRedoHistory', () {
    test('undo then redo walks the snapshots and a new record clears redo', () {
      final history = UndoRedoHistory<int>(limit: 2);
      history.record(0, label: 'first');
      history.record(1);
      history.record(2);
      expect(history.undoCount, 2, reason: 'oldest step dropped at limit');

      expect(history.undo(3)!.state, 2);
      expect(history.canRedo, isTrue);
      expect(history.redo(2)!.state, 3);

      history.undo(3);
      history.record(9);
      expect(history.canRedo, isFalse);
    });

    test('group records one step, and none for a no-op', () {
      final history = UndoRedoHistory<int>();
      var value = 0;
      final recorded = history.group(value, () {
        history.record(value);
        value = 1;
        history.record(value);
        value = 2;
      }, changed: () => value != 0);
      expect(recorded, isTrue);
      expect(history.undoCount, 1);
      expect(history.undo(value)!.state, 0);

      expect(history.group(5, () {}, changed: () => false), isFalse);
      expect(history.canUndo, isFalse);
    });
  });

  group('UndoWindow', () {
    test(
      'undoLast reverts the latest open action without committing',
      () async {
        final window = UndoWindow<String>();
        final commits = <String>[];
        var undone = 0;
        window.start('a', commit: () => commits.add('a'));
        window.start(
          'b',
          commit: () => commits.add('b'),
          onUndo: () => undone++,
        );
        expect(window.isHidden('a') && window.isHidden('b'), isTrue);

        expect(window.undoLast(), isTrue);
        expect(undone, 1);
        expect(window.isHidden('b'), isFalse);

        await window.flush();
        expect(commits, ['a']);
        expect(window.isHidden('a'), isFalse);
      },
    );

    test(
      'a failed commit shows the item again even when kept hidden',
      () async {
        final window = UndoWindow<String>();
        Object? reported;
        final pending = window.start(
          'a',
          keepHiddenAfterCommit: true,
          commit: () async => throw StateError('offline'),
          onError: (error, _) => reported = error,
        );
        await pending.commit();
        expect(reported, isA<StateError>());
        expect(window.isHidden('a'), isFalse);

        final kept = window.start(
          'b',
          keepHiddenAfterCommit: true,
          commit: () {},
        );
        await kept.commit();
        expect(window.isHidden('b'), isTrue);
        window.retainCommitted(const []);
        expect(window.isHidden('b'), isFalse);
      },
    );
  });

  testWidgets('undo snack bar: Undo reverts, timeout commits once', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    var undone = 0;
    var committed = 0;
    showUndoSnackBar(
      context,
      message: 'Moved',
      pending: PendingUndo(onUndo: () => undone++, onCommit: () => committed++),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();
    expect((undone, committed), (1, 0));

    showUndoSnackBar(
      context,
      message: 'Moved again',
      pending: PendingUndo(onUndo: () => undone++, onCommit: () => committed++),
      duration: const Duration(seconds: 1),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect((undone, committed), (1, 1));
  });

  testWidgets('UndoShortcuts: Ctrl+Z undoes, Ctrl+Y and Ctrl+Shift+Z redo, '
      'text fields keep their keys', (tester) async {
    var undos = 0;
    var redos = 0;
    final field = FocusNode();
    addTearDown(field.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UndoShortcuts(
            autofocus: true,
            onUndo: () => undos++,
            onRedo: () => redos++,
            child: Column(children: [TextField(focusNode: field)]),
          ),
        ),
      ),
    );
    await tester.pump();

    await _ctrl(tester, LogicalKeyboardKey.keyZ);
    await _ctrl(tester, LogicalKeyboardKey.keyY);
    await _ctrl(tester, LogicalKeyboardKey.keyZ, shift: true);
    expect((undos, redos), (1, 2));

    field.requestFocus();
    await tester.pump();
    await _ctrl(tester, LogicalKeyboardKey.keyZ);
    await _ctrl(tester, LogicalKeyboardKey.keyY);
    expect((undos, redos), (1, 2));
  });

  testWidgets(
    'UndoShortcuts lets the key through when the action is disabled',
    (tester) async {
      var undos = 0;
      var outer = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CallbackShortcuts(
            bindings: {
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                control: true,
              ): () =>
                  outer++,
            },
            child: UndoShortcuts(
              autofocus: true,
              canUndo: false,
              onUndo: () => undos++,
              child: const SizedBox(),
            ),
          ),
        ),
      );
      await tester.pump();
      await _ctrl(tester, LogicalKeyboardKey.keyZ);
      expect((undos, outer), (0, 1));
    },
  );

  group('TrashView', () {
    final now = DateTime.utc(2026, 10, 20, 12);
    final items = [
      _Item(
        '1',
        'Écran de démarrage',
        'video',
        now.subtract(const Duration(days: 2)),
      ),
      _Item(
        '2',
        'Newsletter retirée',
        'mail',
        now.subtract(const Duration(days: 1)),
      ),
    ];

    Future<void> pump(
      WidgetTester tester, {
      required Future<void> Function(_Item) onRestore,
      Future<void> Function(_Item)? onDelete,
      List<_Item>? list,
    }) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TrashView<_Item>(
            items: list ?? items,
            now: () => now,
            strings: TrashStrings.fr,
            entryOf: (item) => TrashEntry(
              id: item.id,
              title: item.title,
              deletedAt: item.deletedAt,
              purgeAt: item.deletedAt.add(const Duration(days: 30)),
            ),
            filters: [
              TrashFilter(
                label: 'Vidéos',
                test: (item) => item.kind == 'video',
              ),
            ],
            onRestore: onRestore,
            onDeletePermanently: onDelete,
          ),
        ),
      ),
    );

    testWidgets('restore shows a spinner on the row and calls back once', (
      tester,
    ) async {
      final gate = Completer<void>();
      final restored = <String>[];
      await pump(
        tester,
        onRestore: (item) {
          restored.add(item.id);
          return gate.future;
        },
      );

      // Most recent first.
      final titles = tester
          .widgetList<ListTile>(find.byType(ListTile))
          .map((tile) => (tile.title! as Text).data)
          .toList();
      expect(titles, ['Newsletter retirée', 'Écran de démarrage']);
      expect(find.textContaining('encore 29 jours'), findsOneWidget);

      await tester.tap(find.text('Restaurer').last);
      await tester.pump();
      expect(restored, ['1']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Restaurer'), findsOneWidget);

      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Restaurer'), findsNWidgets(2));
    });

    testWidgets('restore errors go to FlutterError without breaking the row', (
      tester,
    ) async {
      await pump(tester, onRestore: (_) async => throw StateError('offline'));
      await tester.tap(find.text('Restaurer').first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isA<StateError>());
      expect(find.text('Restaurer'), findsNWidgets(2));
    });

    testWidgets('search folds accents and filters narrow the list', (
      tester,
    ) async {
      await pump(tester, onRestore: (_) async {});
      await tester.enterText(find.byType(TextField), 'ecran');
      await tester.pump();
      expect(find.text('Écran de démarrage'), findsOneWidget);
      expect(find.text('Newsletter retirée'), findsNothing);

      await tester.enterText(find.byType(TextField), '');
      await tester.tap(find.text('Tout'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Vidéos').last);
      await tester.pumpAndSettle();
      expect(find.text('Newsletter retirée'), findsNothing);
      expect(find.text('Écran de démarrage'), findsOneWidget);
    });

    testWidgets('delete permanently asks first', (tester) async {
      final deleted = <String>[];
      await pump(
        tester,
        onRestore: (_) async {},
        onDelete: (item) async => deleted.add(item.id),
      );
      await tester.tap(find.byTooltip('Supprimer définitivement').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Annuler'));
      await tester.pumpAndSettle();
      expect(deleted, isEmpty);

      await tester.tap(find.byTooltip('Supprimer définitivement').first);
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(FilledButton, 'Supprimer définitivement'),
      );
      await tester.pumpAndSettle();
      expect(deleted, ['2']);
    });

    testWidgets('empty states', (tester) async {
      await pump(tester, onRestore: (_) async {}, list: const []);
      expect(find.text('La corbeille est vide'), findsOneWidget);
    });
  });
}
