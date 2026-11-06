/// Pure Dart half of the shared settings: each setting is declared once as a
/// typed [SettingKey]; [SettingsStorage], [SettingsRemote] and secret storage
/// are ports. The controller and widgets live in `shipglows_settings`.
library;

export 'src/file_settings_storage_stub.dart'
    if (dart.library.io) 'src/file_settings_storage_io.dart';
export 'src/secret_store.dart';
export 'src/setting_key.dart';
export 'src/settings_remote.dart';
export 'src/settings_schema.dart';
export 'src/settings_storage.dart';
