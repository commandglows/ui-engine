import 'dart:convert';

import 'package:flutter/foundation.dart';

/// One of the two copies compared before the first sync of an account.
enum SyncSide {
  /// The copy on this device.
  device,

  /// The copy in the user's account (cloud).
  account,
}

/// Every choice made in a review, keyed by [SyncConflict.key].
typedef SyncChoices = Map<String, SyncSide>;

/// Everything one side holds for an account, as JSON-safe values:
/// - [fields]: single values (settings), field id to value, absent when
///   unset;
/// - [collections]: records with a stable id (profiles, links), collection
///   name to record id to record.
@immutable
class SyncSnapshot {
  const SyncSnapshot({this.fields = const {}, this.collections = const {}});

  factory SyncSnapshot.fromJson(Map<String, Object?> json) {
    final fields = json['fields'];
    final collections = json['collections'];
    return SyncSnapshot(
      fields: fields is Map ? fields.cast<String, Object?>() : const {},
      collections: collections is Map
          ? {
              for (final entry in collections.entries)
                if (entry.value is Map)
                  '${entry.key}': (entry.value as Map).cast<String, Object?>(),
            }
          : const {},
    );
  }

  /// Section name of [fields] in conflict keys (`fields/theme`).
  static const fieldsSection = 'fields';

  final Map<String, Object?> fields;
  final Map<String, Map<String, Object?>> collections;

  bool get isEmpty =>
      fields.isEmpty && collections.values.every((records) => records.isEmpty);

  /// Same text for the same content, whatever the key order: tells whether a
  /// side changed between the review and its confirmation.
  String get fingerprint => canonicalJson(toJson());

  Map<String, Object?> toJson() => {
    'fields': fields,
    'collections': collections,
  };
}

/// One value that differs between the two sides.
@immutable
class SyncConflict {
  const SyncConflict({
    required this.section,
    required this.id,
    required this.device,
    required this.account,
  });

  /// [SyncSnapshot.fieldsSection] or a collection name.
  final String section;

  /// Field id or record id.
  final String id;
  final Object? device;
  final Object? account;

  /// Stable key of the choice (`fields/theme`, `profiles/p1`).
  String get key => '$section/$id';

  bool get isField => section == SyncSnapshot.fieldsSection;

  Object? valueOf(SyncSide side) => side == SyncSide.device ? device : account;
}

/// The union of both sides, with the differences the user must decide.
@immutable
class SyncPlan {
  const SyncPlan({
    required this.merged,
    required this.conflicts,
    required this.choices,
  });

  /// Both sides together; each conflict takes its chosen side, the device
  /// until chosen.
  final SyncSnapshot merged;
  final List<SyncConflict> conflicts;
  final SyncChoices choices;

  bool get hasConflicts => conflicts.isNotEmpty;

  /// Every conflict has a choice: the plan can be applied.
  bool get isComplete =>
      conflicts.every((conflict) => choices.containsKey(conflict.key));

  /// Chooses [side] for every conflict.
  SyncChoices chooseAll(SyncSide side) => {
    for (final conflict in conflicts) conflict.key: side,
  };
}

/// Unites [device] and [account]: a value present on one side only is kept;
/// a value present on both sides with different content becomes a
/// [SyncConflict] resolved by [choices]. Records are compared whole, by id,
/// never merged field by field.
SyncPlan reconcileSnapshots(
  SyncSnapshot device,
  SyncSnapshot account, {
  SyncChoices choices = const {},
}) {
  final conflicts = <SyncConflict>[];

  Map<String, Object?> unite(
    String section,
    Map<String, Object?> left,
    Map<String, Object?> right,
  ) {
    final ids = {...left.keys, ...right.keys}.toList()..sort();
    final result = <String, Object?>{};
    for (final id in ids) {
      final inLeft = left.containsKey(id);
      final inRight = right.containsKey(id);
      final a = left[id];
      final b = right[id];
      if (!inRight || (inLeft && sameJson(a, b))) {
        result[id] = a;
      } else if (!inLeft) {
        result[id] = b;
      } else {
        final conflict = SyncConflict(
          section: section,
          id: id,
          device: a,
          account: b,
        );
        conflicts.add(conflict);
        result[id] = choices[conflict.key] == SyncSide.account ? b : a;
      }
    }
    return result;
  }

  final fields = unite(
    SyncSnapshot.fieldsSection,
    device.fields,
    account.fields,
  );
  final names = {
    ...device.collections.keys,
    ...account.collections.keys,
  }.toList()..sort();
  final collections = {
    for (final name in names)
      name: unite(
        name,
        device.collections[name] ?? const {},
        account.collections[name] ?? const {},
      ),
  };
  return SyncPlan(
    merged: SyncSnapshot(fields: fields, collections: collections),
    conflicts: List.unmodifiable(conflicts),
    choices: Map.unmodifiable({
      for (final conflict in conflicts)
        if (choices[conflict.key] case final side?) conflict.key: side,
    }),
  );
}

/// JSON text with sorted keys, so equal content gives equal text.
String canonicalJson(Object? value) => jsonEncode(_sorted(value));

/// Whether two JSON-safe values hold the same content.
bool sameJson(Object? a, Object? b) {
  if (identical(a, b) || a == b) return true;
  if (a == null || b == null) return false;
  return canonicalJson(a) == canonicalJson(b);
}

Object? _sorted(Object? value) => switch (value) {
  final Map<Object?, Object?> map => {
    for (final key in map.keys.map((key) => '$key').toList()..sort())
      key: _sorted(map[key]),
  },
  final List<Object?> list => list.map(_sorted).toList(),
  _ => value,
};
