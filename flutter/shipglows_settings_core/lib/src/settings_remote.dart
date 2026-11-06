/// The remote copy of one account's settings, as the remote returns it.
class RemoteSettings {
  const RemoteSettings({
    required this.values,
    this.revision,
    this.updatedAt,
    this.schemaVersion,
  });

  /// Field name to JSON-safe value. Fields of other apps or unknown settings
  /// are ignored.
  final Map<String, Object?> values;

  /// Opaque server revision (timestamp, etag, counter), for diagnostics.
  final String? revision;

  /// Server time of the last write.
  final DateTime? updatedAt;

  /// Schema version of [values] when the remote stores it; older values are
  /// migrated before use.
  final int? schemaVersion;

  bool get isEmpty => values.isEmpty;
}

/// One account's remote settings document (Firestore, REST endpoint, S3
/// object...). The controller only ever sends the fields that changed.
abstract interface class SettingsRemote {
  /// The current document, or `null` when the account has none yet.
  Future<RemoteSettings?> fetch();

  /// Applies [changes] (field to new value, `null` meaning back to default)
  /// and returns the resulting document when the remote hands it back.
  ///
  /// Throws [SettingsRemoteAuthException] when the account cannot write.
  Future<RemoteSettings?> push(Map<String, Object?> changes);

  /// Live updates from other devices, or `null` when the remote cannot push
  /// them (the controller then pulls on resume and on its retry timer).
  Stream<RemoteSettings?>? watch();
}

/// The remote refused the account (signed out, expired token, no
/// entitlement). Retrying will not help until the account changes.
final class SettingsRemoteAuthException implements Exception {
  const SettingsRemoteAuthException([this.message = 'Not authorized']);

  final String message;

  @override
  String toString() => 'SettingsRemoteAuthException: $message';
}

/// Plugs an existing API client in (REST service, blob store).
class CallbackSettingsRemote implements SettingsRemote {
  const CallbackSettingsRemote({
    required Future<RemoteSettings?> Function() fetch,
    required Future<RemoteSettings?> Function(Map<String, Object?> changes)
    push,
    Stream<RemoteSettings?>? Function()? watch,
  }) : _fetch = fetch,
       _push = push,
       _watch = watch;

  final Future<RemoteSettings?> Function() _fetch;
  final Future<RemoteSettings?> Function(Map<String, Object?> changes) _push;
  final Stream<RemoteSettings?>? Function()? _watch;

  @override
  Future<RemoteSettings?> fetch() => _fetch();

  @override
  Future<RemoteSettings?> push(Map<String, Object?> changes) => _push(changes);

  @override
  Stream<RemoteSettings?>? watch() => _watch?.call();
}

/// In memory, shared by several controllers to stand for two devices in tests.
/// Nested maps are merged like Firestore `merge: true` or an API deep merge.
class MemorySettingsRemote implements SettingsRemote {
  MemorySettingsRemote({Map<String, Object?>? initial, DateTime Function()? clock})
    : _values = initial == null ? null : Map.of(initial),
      _clock = clock ?? DateTime.now;

  Map<String, Object?>? _values;
  final DateTime Function() _clock;
  int _revision = 0;
  DateTime? _updatedAt;

  /// Set to make every call fail, as when offline.
  Object? failWith;

  final List<Map<String, Object?>> pushes = [];

  Map<String, Object?>? get values => _values == null ? null : Map.of(_values!);

  RemoteSettings? get _document => _values == null
      ? null
      : RemoteSettings(
          values: Map.of(_values!),
          revision: '$_revision',
          updatedAt: _updatedAt,
        );

  @override
  Future<RemoteSettings?> fetch() async {
    if (failWith != null) throw failWith!;
    return _document;
  }

  @override
  Future<RemoteSettings?> push(Map<String, Object?> changes) async {
    if (failWith != null) throw failWith!;
    pushes.add(Map.of(changes));
    final values = _values ??= {};
    changes.forEach((id, value) {
      final current = values[id];
      if (value == null) {
        values.remove(id);
      } else if (value is Map && current is Map) {
        values[id] = _merge(current, value);
      } else {
        values[id] = value;
      }
    });
    _revision++;
    _updatedAt = _clock().toUtc();
    return _document;
  }

  @override
  Stream<RemoteSettings?>? watch() => null;

  static Map<String, Object?> _merge(Map<Object?, Object?> into, Map<Object?, Object?> from) => {
    for (final entry in into.entries) '${entry.key}': entry.value,
    for (final entry in from.entries)
      '${entry.key}': entry.value is Map && into[entry.key] is Map
          ? _merge(into[entry.key]! as Map, entry.value! as Map)
          : entry.value,
  };
}
