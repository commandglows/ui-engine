/// Widgets and texts of the device-to-account sync: [SyncStatusChip],
/// [SyncIssueBanner], [SyncReviewPrompt] and [showSyncReviewDialog],
/// [SyncProgressOverlay], [SyncRecoveryPanel], worded by [SyncStrings]
/// (French and English). Re-exports the logic of `shipglows_sync_core`.
library;

export 'package:shipglows_sync_core/shipglows_sync_core.dart';

export 'src/sync_listenable.dart';
export 'src/sync_progress_view.dart';
export 'src/sync_recovery_panel.dart';
export 'src/sync_review_dialog.dart';
export 'src/sync_status_widgets.dart';
export 'src/sync_strings.dart';
