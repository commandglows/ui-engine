/// API keys and tokens: never in a [SettingKey], never synced, never in a
/// diagnostic report. Apps back it with `flutter_secure_storage` (or DPAPI).
abstract interface class SecretStore {
  Future<String?> read(String name);

  /// An empty or `null` [value] deletes the secret.
  Future<void> write(String name, String? value);
}

/// In memory only: tests and demo mode.
class MemorySecretStore implements SecretStore {
  final Map<String, String> _values = {};

  @override
  Future<String?> read(String name) async => _values[name];

  @override
  Future<void> write(String name, String? value) async {
    if (value == null || value.isEmpty) {
      _values.remove(name);
    } else {
      _values[name] = value;
    }
  }
}
