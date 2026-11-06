import 'setting_key.dart';

/// Rewrites stored values written by schema version `to - 1` into version
/// `to` (rename a field, split one, change its encoding).
typedef SettingsMigration =
    Map<String, Object?> Function(Map<String, Object?> values);

/// Every setting an app declares, with the version of their stored shape.
class SettingsSchema {
  SettingsSchema({
    required List<SettingKey<Object?>> keys,
    this.version = 1,
    Map<int, SettingsMigration> migrations = const {},
  }) : keys = List.unmodifiable(keys),
       migrations = Map.unmodifiable(migrations),
       _byId = {for (final key in keys) key.id: key} {
    if (_byId.length != keys.length) {
      throw ArgumentError('Two settings share the same id.');
    }
    for (final step in migrations.keys) {
      if (step < 2 || step > version) {
        throw ArgumentError('Migration $step is outside 2..$version.');
      }
    }
  }

  final List<SettingKey<Object?>> keys;
  final int version;

  /// Keyed by the version each migration produces.
  final Map<int, SettingsMigration> migrations;

  final Map<String, SettingKey<Object?>> _byId;

  SettingKey<Object?>? operator [](String id) => _byId[id];

  bool contains(SettingKey<Object?> key) => identical(_byId[key.id], key);

  Iterable<SettingKey<Object?>> inScope(SettingScope scope) =>
      keys.where((key) => key.scope == scope);

  /// Brings [values] stored at [from] up to [version]. A version newer than
  /// this app (downgrade) is kept as is: unknown fields are ignored on read.
  Map<String, Object?> migrate(Map<String, Object?> values, int from) {
    var current = Map<String, Object?>.of(values);
    for (var step = from + 1; step <= version; step++) {
      final migration = migrations[step];
      if (migration != null) {
        current = Map<String, Object?>.of(migration(current));
      }
    }
    return current;
  }
}
