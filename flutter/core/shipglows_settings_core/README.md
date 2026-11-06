# shipglows_settings_core

Pure Dart half of the shared settings: `SettingKey`, `SettingsSchema` and migrations, the `SettingsStorage`, `SettingsRemote` and secret ports, the file and memory storages. A package that only needs storage depends on this one and pulls no Flutter. The controller and widgets live in [`shipglows_settings`](../../services/shipglows_settings/README.md), which re-exports this package.
