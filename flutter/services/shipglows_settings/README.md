# shipglows_settings

User settings (not business data), merged from CommandGlows (sync engine),
ContentGlows (offline queue, per-account cache, partial writes), BeatGlows
(atomic files, secrets apart) and DreamGlows (web storage, test isolation).

- Each setting is declared once as a `SettingKey` (id, type, default,
  `SettingScope.device` or `.account`). The id is the field name everywhere:
  device file, Firestore document, REST payload. Bad stored data reads as the
  default.
- `SettingsSchema(version:, migrations:)` upgrades stored values, device and
  remote, before use.
- `SettingsController.open(importLegacy:)` loads the device copy; on a fresh
  device it imports the old storage once (secure storage keys,
  SharedPreferences).
- `set`, `reset`, `edit` (batch): saved on the device before returning
  (throws `SettingsStorageException`), then only the changed fields are
  pushed. A pending field keeps its device value until the remote accepts it;
  every other field follows the remote.
- `setAccount(SettingsAccount(id:, remote:))`: one device copy per account,
  never mixed. The first sign-in on a device unites the signed-out values with
  the account's (`shipglows_sync`): a value set on one side only is kept;
  values set differently on both sides put the status in `needsReview` until
  `resolveReview(choices)`, and the device values stay in use meanwhile.
  `reviewFirstSync: false` keeps the former rule (the account replaces the
  signed-out values). `forgetAccount` deletes a copy and its recovery.
- Before applying a review, copies of both sides are saved as a
  `SyncRecovery` (bucket `recovery.account.<id>`, never sent);
  `restoreRecovery(side)` puts one back here and in the account,
  `dropRecovery` deletes them.
- `progress` (`SyncProgress`): steps of an account's first sync on this device
  (waiting, received, applied, ready), for `SyncProgressOverlay`.
- Retry: 30 s doubling to 5 min, on app resume and on `sync()`;
  `SettingsRemoteAuthException` stops until the account changes.
- Map settings (`SettingKey.map(id)`, `mergeFields` on by default): a change
  marks only the nested fields that differ, `setField(key, path, value)`
  edits one of them, the push sends a partial map (the remote deep-merges:
  Firestore `merge: true`, an API merge), and a pull keeps the pending nested
  fields while taking the others.
- Records created offline: `isTemporaryId` (`(id) => id.startsWith(
  'offline-')`) holds every pending field pointing at one; it is shown but
  not sent until `rewriteIds({tempId: serverId})`, which rewrites the stored
  values and sends them. The value helpers (`rewriteSyncIds`,
  `holdsTemporaryId`) live in `shipglows_sync` for data stores too.
- `status` (`SyncStatus`: also `unreachable` when the account was never read
  on this device), `listenable(key)` (notifies only for that key),
  `SettingBuilder`, `SettingSwitchTile`. The controller is a `SyncSource`,
  `SyncReviewHost` and `SyncRecoveryHost`: the sync widgets come from
  `shipglows_sync`.
- Storage ports: `FileSettingsStorage(directory)` (native, temp file then
  rename), `MemorySettingsStorage`, `CallbackSettingsStorage` (IndexedDB,
  SharedPreferences). Remote ports: `CallbackSettingsRemote` (REST client,
  blob store), `MemorySettingsRemote` (tests, two devices).
- Several windows (one Flutter engine each: command bar, quick capture):
  `FileSettingsStorage` is a `WatchableSettingsStorage`, so every
  controller on the same folder reloads a bucket another window wrote;
  `reload()` does it by hand for other storages. Fields pending in a window
  keep its value.
- Secrets never go in a `SettingKey`: `SecretStore` (`read`, `write`,
  `delete`, from BeatGlows) is the interface for the app's secure storage,
  plugged in with `CallbackSecretStore` over `flutter_secure_storage`;
  `MemorySecretStore` for tests. The app deletes the secrets a setting no
  longer needs (S3 keys when the storage choice leaves S3).
