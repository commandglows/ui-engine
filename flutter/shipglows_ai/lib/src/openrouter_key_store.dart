import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Where the user's OpenRouter key lives. The client reads it before every
/// request, so a key changed in the settings applies at once.
abstract interface class OpenRouterKeyStore {
  /// The key, or null when none is saved.
  Future<String?> read();

  /// Saves [key], trimmed. An empty key clears the store.
  Future<void> write(String key);

  Future<void> clear();
}

/// The system keychain (Keychain, Android Keystore, Windows Credential
/// Manager, libsecret, or the browser's storage on the web) through
/// `flutter_secure_storage`.
class SecureOpenRouterKeyStore implements OpenRouterKeyStore {
  const SecureOpenRouterKeyStore({
    FlutterSecureStorage storage = const FlutterSecureStorage(),
    this.storageKey = 'shipglows_ai.openrouter_api_key',
  }) : _storage = storage;

  final FlutterSecureStorage _storage;

  /// Name of the entry, to keep two apps or two profiles apart.
  final String storageKey;

  /// A keychain that cannot be read counts as no key: the client then
  /// raises [AiMissingKey] instead of crashing.
  @override
  Future<String?> read() async {
    try {
      final key = await _storage.read(key: storageKey);
      return key == null || key.trim().isEmpty ? null : key.trim();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) return clear();
    await _storage.write(key: storageKey, value: trimmed);
  }

  @override
  Future<void> clear() => _storage.delete(key: storageKey);
}

/// Keeps the key in memory only: tests, or a key typed for one session.
class MemoryOpenRouterKeyStore implements OpenRouterKeyStore {
  MemoryOpenRouterKeyStore([String? key]) : _key = _clean(key);

  String? _key;

  @override
  Future<String?> read() async => _key;

  @override
  Future<void> write(String key) async => _key = _clean(key);

  @override
  Future<void> clear() async => _key = null;

  static String? _clean(String? key) {
    final trimmed = key?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Plugs the app's own storage in (its settings store, a backend-held key)
/// without a dependency in this package.
class CallbackOpenRouterKeyStore implements OpenRouterKeyStore {
  const CallbackOpenRouterKeyStore({
    required Future<String?> Function() read,
    required Future<void> Function(String key) write,
    required Future<void> Function() clear,
  }) : _read = read,
       _write = write,
       _clear = clear;

  final Future<String?> Function() _read;
  final Future<void> Function(String key) _write;
  final Future<void> Function() _clear;

  @override
  Future<String?> read() async {
    final key = (await _read())?.trim();
    return key == null || key.isEmpty ? null : key;
  }

  @override
  Future<void> write(String key) {
    final trimmed = key.trim();
    return trimmed.isEmpty ? _clear() : _write(trimmed);
  }

  @override
  Future<void> clear() => _clear();
}
