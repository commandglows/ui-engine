import 'settings_storage.dart';

/// Files are not available on the web: use [CallbackSettingsStorage] over
/// IndexedDB or SharedPreferences there.
class FileSettingsStorage implements SettingsStorage {
  FileSettingsStorage(Object directory, {this.prefix = 'settings.'}) {
    throw UnsupportedError('FileSettingsStorage needs dart:io.');
  }

  final String prefix;

  @override
  Future<Map<String, Object?>?> read(String bucket) =>
      throw UnsupportedError('FileSettingsStorage needs dart:io.');

  @override
  Future<void> write(String bucket, Map<String, Object?> data) =>
      throw UnsupportedError('FileSettingsStorage needs dart:io.');

  @override
  Future<void> delete(String bucket) =>
      throw UnsupportedError('FileSettingsStorage needs dart:io.');
}
