/// API keys and tokens: never in a [SettingKey], never synced, never in a
/// diagnostic report. Apps back it with the system's secret store
/// (`flutter_secure_storage`: Credential Manager on Windows, Keystore on
/// Android) through [CallbackSecretStore].
///
/// A setting can say which secrets go with it (S3 keys with the S3 storage
/// choice); the app deletes them when the setting no longer needs them.
abstract interface class SecretStore {
  Future<String?> read(String name);

  Future<void> write(String name, String value);

  Future<void> delete(String name);
}

/// Plugs an existing secret store in without a dependency in this package.
class CallbackSecretStore implements SecretStore {
  const CallbackSecretStore({
    required Future<String?> Function(String name) read,
    required Future<void> Function(String name, String value) write,
    required Future<void> Function(String name) delete,
  }) : _read = read,
       _write = write,
       _delete = delete;

  final Future<String?> Function(String name) _read;
  final Future<void> Function(String name, String value) _write;
  final Future<void> Function(String name) _delete;

  @override
  Future<String?> read(String name) => _read(name);

  @override
  Future<void> write(String name, String value) => _write(name, value);

  @override
  Future<void> delete(String name) => _delete(name);
}

/// In memory only: tests and demo mode.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String value) async {
    _values[name] = value;
  }

  @override
  Future<void> delete(String name) async {
    _values.remove(name);
  }
}
