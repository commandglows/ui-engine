import 'package:flutter/foundation.dart';

import 'reconciliation.dart';

/// Two different records claiming the same identity within one snapshot.
/// Callers retain the original records and decide how to expose the conflict.
@immutable
class SyncCollectionCollision<T> {
  const SyncCollectionCollision({
    required this.id,
    required this.first,
    required this.duplicate,
  });

  final String id;
  final T first;
  final T duplicate;
}

/// Records indexed for [SyncSnapshot.collections], without hiding collisions.
@immutable
class SyncCollectionIndex<T> {
  SyncCollectionIndex({
    required Map<String, T> records,
    required List<SyncCollectionCollision<T>> collisions,
  }) : records = Map.unmodifiable(records),
       collisions = List.unmodifiable(collisions);

  final Map<String, T> records;
  final List<SyncCollectionCollision<T>> collisions;

  /// A conflicting collection must not be applied until the caller resolves it.
  bool get isConsistent => collisions.isEmpty;
}

/// Converts JSON-safe records into the stable-id map reconciliation expects.
///
/// Equal duplicates are represented once. Different values for an id are
/// reported in [SyncCollectionIndex.collisions]; the first value is retained
/// for inspection, never silently replaced. Inputs are not mutated. An empty
/// id is rejected. Normalization and business identity belong to [idOf].
SyncCollectionIndex<T> indexSyncCollection<T>(
  Iterable<T> records, {
  required String Function(T record) idOf,
}) {
  final indexed = <String, T>{};
  final collisions = <SyncCollectionCollision<T>>[];
  for (final record in records) {
    final id = idOf(record);
    if (id.trim().isEmpty) {
      throw ArgumentError.value(id, 'idOf', 'A stable record id is required.');
    }
    if (!indexed.containsKey(id)) {
      indexed[id] = record;
      continue;
    }
    final first = indexed[id] as T;
    if (!sameJson(first, record)) {
      collisions.add(
        SyncCollectionCollision(id: id, first: first, duplicate: record),
      );
    }
  }
  return SyncCollectionIndex(records: indexed, collisions: collisions);
}
