import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

/// The ids used in each scope, most recent first.
abstract interface class RecentsStore implements Listenable {
  /// Ids used in [scope], most recent first, at most [limit].
  List<String> recent(String scope, {int? limit});

  /// Records that [id] was just used in [scope].
  Future<void> markUsed(String scope, String id);

  /// Removes [id] from [scope] (deleted or archived item).
  Future<void> forget(String scope, String id);
}

/// The [items] (an app's known items) whose id is in [recent], in that order:
/// a recent id never shows an item that is gone or archived.
///
/// With [fill], the other items follow in their given order, so the quick
/// picks are never empty before the first use (a new account, a new device).
List<T> pickRecent<T>(
  List<String> recent,
  Iterable<T> items,
  String Function(T item) idOf, {
  int? limit,
  bool fill = false,
}) {
  final byId = {for (final item in items) idOf(item): item};
  final picked = <T>[
    for (final id in recent)
      if (byId[id] case final item?) item,
  ];
  if (fill) {
    final taken = {for (final item in picked) idOf(item)};
    picked.addAll(items.where((item) => !taken.contains(idOf(item))));
  }
  return limit == null || picked.length <= limit
      ? picked
      : picked.sublist(0, limit);
}

/// Last-use times kept in one synced account setting (a
/// [SettingKey.map] with `mergeFields`): `{scope: {id: epochMillis}}`.
///
/// Each use changes one nested field, so two devices recording different
/// items never overwrite each other, and the remote must deep-merge the map
/// and drop a nested field sent as `null` (pruned items).
class SettingsRecentsStore extends ChangeNotifier implements RecentsStore {
  SettingsRecentsStore(
    this.settings,
    this.key, {
    this.keepPerScope = 20,
    DateTime Function()? clock,
  }) : assert(key.isSynced, 'Recent items follow the account.'),
       assert(key.mergeFields, 'Each use must be sent on its own.'),
       _clock = clock ?? DateTime.now {
    _source = settings.listenable(key)..addListener(notifyListeners);
  }

  final SettingsController settings;
  final SettingKey<Map<String, Object?>> key;

  /// Ids kept per scope; the oldest go first.
  final int keepPerScope;

  final DateTime Function() _clock;
  late final ValueListenable<Map<String, Object?>> _source;

  @override
  List<String> recent(String scope, {int? limit}) {
    final ids = _ordered(_scope(settings.get(key), scope))
        .map(_decode)
        .toList(growable: false);
    return limit == null || ids.length <= limit ? ids : ids.sublist(0, limit);
  }

  @override
  Future<void> markUsed(String scope, String id) async {
    final all = _copy(settings.get(key));
    final uses = _copy(_scope(all, scope));
    final latest = uses.values.whereType<num>().fold<int>(
      0,
      (latest, time) => math.max(latest, time.toInt()),
    );
    // Strictly after the latest one, so two uses in the same millisecond, or
    // a device whose clock runs late, still put this id first.
    uses[_encode(id)] = math.max(_clock().millisecondsSinceEpoch, latest + 1);
    final ordered = _ordered(uses);
    for (final stale in ordered.skip(keepPerScope)) {
      uses.remove(stale);
    }
    all[_encode(scope)] = uses;
    await settings.set(key, all);
  }

  @override
  Future<void> forget(String scope, String id) async {
    final all = _copy(settings.get(key));
    final uses = _copy(_scope(all, scope));
    if (uses.remove(_encode(id)) == null) return;
    if (uses.isEmpty) {
      all.remove(_encode(scope));
    } else {
      all[_encode(scope)] = uses;
    }
    await settings.set(key, all);
  }

  @override
  void dispose() {
    _source.removeListener(notifyListeners);
    super.dispose();
  }

  static Map<String, Object?> _scope(Map<String, Object?> all, String scope) {
    final raw = all[_encode(scope)];
    return raw is Map ? raw.cast<String, Object?>() : const {};
  }

  /// Stored names, latest use first (ties by name, for a stable order).
  static List<String> _ordered(Map<String, Object?> uses) {
    final entries = [
      for (final entry in uses.entries)
        if (entry.value case final num time) (entry.key, time),
    ]..sort((a, b) {
        final byTime = b.$2.compareTo(a.$2);
        return byTime != 0 ? byTime : a.$1.compareTo(b.$1);
      });
    return [for (final entry in entries) entry.$1];
  }

  static Map<String, Object?> _copy(Map<String, Object?> map) => {
    for (final entry in map.entries)
      entry.key: entry.value is Map
          ? _copy((entry.value! as Map).cast<String, Object?>())
          : entry.value,
  };

  /// Nested setting names cannot hold `/`.
  static String _encode(String name) =>
      name.replaceAll('%', '%25').replaceAll('/', '%2F');

  static String _decode(String name) =>
      name.replaceAll('%2F', '/').replaceAll('%25', '%');
}

/// In memory, for tests and signed-out previews.
class MemoryRecentsStore extends ChangeNotifier implements RecentsStore {
  MemoryRecentsStore({this.keepPerScope = 20});

  final int keepPerScope;
  final Map<String, List<String>> _scopes = {};

  @override
  List<String> recent(String scope, {int? limit}) {
    final ids = _scopes[scope] ?? const <String>[];
    return List.unmodifiable(
      limit == null || ids.length <= limit ? ids : ids.sublist(0, limit),
    );
  }

  @override
  Future<void> markUsed(String scope, String id) async {
    final ids = _scopes.putIfAbsent(scope, () => [])
      ..remove(id)
      ..insert(0, id);
    if (ids.length > keepPerScope) ids.removeRange(keepPerScope, ids.length);
    notifyListeners();
  }

  @override
  Future<void> forget(String scope, String id) async {
    if (_scopes[scope]?.remove(id) ?? false) notifyListeners();
  }
}
