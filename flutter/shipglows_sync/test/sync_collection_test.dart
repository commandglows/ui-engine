import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_sync/shipglows_sync.dart';

void main() {
  SyncCollectionIndex<Map<String, Object?>> index(
    List<Map<String, Object?>> rows,
  ) => indexSyncCollection(rows, idOf: (row) => row['id'] as String);

  test(
    'empty and disjoint collections reconcile without changing their input',
    () {
      expect(index([]).records, isEmpty);
      final device = [
        {'id': 'a', 'content': 'A'},
      ];
      final account = [
        {'id': 'b', 'content': 'B'},
      ];
      final plan = reconcileSnapshots(
        SyncSnapshot(collections: {'items': index(device).records}),
        SyncSnapshot(collections: {'items': index(account).records}),
      );
      expect(plan.isComplete, isTrue);
      expect(plan.merged.collections['items']!.keys, ['a', 'b']);
      expect(device, hasLength(1));
      expect(account, hasLength(1));
    },
  );

  test('identical duplicates fold once, independent of JSON key order', () {
    final result = index([
      {
        'id': 'a',
        'value': {'one': 1, 'two': 2},
      },
      {
        'value': {'two': 2, 'one': 1},
        'id': 'a',
      },
    ]);
    expect(result.isConsistent, isTrue);
    expect(result.records, hasLength(1));
    expect(() => result.records.clear(), throwsUnsupportedError);
  });

  test(
    'contradictory duplicates retain the original and report every collision',
    () {
      final rows = [
        {'id': 'a', 'content': 'Original'},
        {'id': 'a', 'content': 'Different'},
        {'id': 'a', 'content': 'Third'},
      ];
      final result = index(rows);
      expect(result.isConsistent, isFalse);
      expect(result.records['a'], rows.first);
      expect(result.collisions.map((collision) => collision.id), ['a', 'a']);
      expect(result.collisions.first.first, rows.first);
      expect(result.collisions.first.duplicate, rows[1]);
      expect(rows, hasLength(3));
      expect(() => result.collisions.clear(), throwsUnsupportedError);
    },
  );

  test('missing identities fail instead of merging unrelated rows', () {
    expect(
      () => index([
        {'id': ' '},
      ]),
      throwsArgumentError,
    );
  });

  test('normalization is supplied by the caller', () {
    final result = indexSyncCollection([
      ' A ',
      'a',
    ], idOf: (row) => row.trim().toLowerCase());
    expect(result.collisions.single.id, 'a');
    expect(result.records['a'], ' A ');
  });

  test('null JSON values are present records, not missing keys', () {
    final result = indexSyncCollection<Object?>([
      null,
      null,
      'value',
    ], idOf: (_) => 'id');
    expect(result.records.containsKey('id'), isTrue);
    expect(result.collisions.single.first, isNull);
  });

  test('conflicts still require explicit choices and replay stays stable', () {
    final device = SyncSnapshot(
      collections: {
        'items': index([
          {'id': 'a', 'content': 'Local'},
        ]).records,
      },
    );
    final account = SyncSnapshot(
      collections: {
        'items': index([
          {'id': 'a', 'content': 'Cloud'},
        ]).records,
      },
    );
    final unresolved = reconcileSnapshots(device, account);
    expect(unresolved.isComplete, isFalse);
    expect(unresolved.conflicts.single.key, 'items/a');
    final resolved = reconcileSnapshots(
      device,
      account,
      choices: {'items/a': SyncSide.account},
    );
    expect(resolved.isComplete, isTrue);
    expect(
      reconcileSnapshots(resolved.merged, account).merged.fingerprint,
      resolved.merged.fingerprint,
    );
  });
}
