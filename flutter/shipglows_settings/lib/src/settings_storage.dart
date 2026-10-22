/// Device persistence for settings: one JSON object per bucket (`device`,
/// `account.local`, `account.<id>`).
///
/// [write] must be atomic: after a crash the bucket holds either the old or
/// the new object, never a mix.
abstract interface class SettingsStorage {
  /// The stored object, or `null` when the bucket was never written.
  Future<Map<String, Object?>?> read(String bucket);

  Future<void> write(String bucket, Map<String, Object?> data);

  Future<void> delete(String bucket);
}

/// In memory only: tests, previews, demo mode.
class MemorySettingsStorage implements SettingsStorage {
  MemorySettingsStorage([Map<String, Map<String, Object?>>? initial])
    : _buckets = {...?initial};

  final Map<String, Map<String, Object?>> _buckets;

  Map<String, Map<String, Object?>> get buckets => Map.unmodifiable(_buckets);

  @override
  Future<Map<String, Object?>?> read(String bucket) async {
    final data = _buckets[bucket];
    return data == null ? null : Map<String, Object?>.of(data);
  }

  @override
  Future<void> write(String bucket, Map<String, Object?> data) async {
    _buckets[bucket] = Map<String, Object?>.of(data);
  }

  @override
  Future<void> delete(String bucket) async {
    _buckets.remove(bucket);
  }
}

/// Plugs an existing store in (SharedPreferences, IndexedDB, secure storage)
/// without a dependency in this package.
class CallbackSettingsStorage implements SettingsStorage {
  const CallbackSettingsStorage({
    required Future<Map<String, Object?>?> Function(String bucket) read,
    required Future<void> Function(String bucket, Map<String, Object?> data)
    write,
    required Future<void> Function(String bucket) delete,
  }) : _read = read,
       _write = write,
       _delete = delete;

  final Future<Map<String, Object?>?> Function(String bucket) _read;
  final Future<void> Function(String bucket, Map<String, Object?> data) _write;
  final Future<void> Function(String bucket) _delete;

  @override
  Future<Map<String, Object?>?> read(String bucket) => _read(bucket);

  @override
  Future<void> write(String bucket, Map<String, Object?> data) =>
      _write(bucket, data);

  @override
  Future<void> delete(String bucket) => _delete(bucket);
}

/// A device settings read or write failed.
final class SettingsStorageException implements Exception {
  const SettingsStorageException(this.operation, this.bucket, this.cause);

  /// `read`, `write` or `delete`.
  final String operation;
  final String bucket;
  final Object cause;

  @override
  String toString() => 'Settings $operation failed for $bucket: $cause';
}
