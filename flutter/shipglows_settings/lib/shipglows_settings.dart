/// User settings of the ShipGlows Flutter apps: each setting is declared once
/// as a typed [SettingKey], stored on the device first, and synced per account
/// through a [SettingsRemote] the app plugs in (Firestore, REST, S3...).
///
/// Business data stays out of this package: settings are small, owned by one
/// user, and merged key by key.
library;

// Sync types shared with every synced store; their widgets live in
// `package:shipglows_sync`.
export 'package:shipglows_sync/shipglows_sync.dart'
    show
        SyncChoices,
        SyncHealth,
        SyncIssue,
        SyncProgress,
        SyncRecovery,
        SyncReview,
        SyncReviewError,
        SyncReviewHost,
        SyncRecoveryHost,
        SyncSide,
        SyncSource,
        SyncStage,
        SyncStatus;

export 'src/file_settings_storage_stub.dart'
    if (dart.library.io) 'src/file_settings_storage_io.dart';
export 'src/secret_store.dart';
export 'src/setting_key.dart';
export 'src/settings_controller.dart';
export 'src/settings_remote.dart';
export 'src/settings_schema.dart';
export 'src/settings_storage.dart';
export 'src/settings_widgets.dart';
