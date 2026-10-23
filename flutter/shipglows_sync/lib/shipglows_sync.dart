/// Device-to-account sync for ShipGlows Flutter apps, ported from
/// CommunityGlows.
///
/// - [SyncStatus] / [SyncSource]: where a synced store stands (synced,
///   pending, needs review, unreachable, failed).
/// - [reconcileSnapshots]: the first sync of an account on a device unites
///   both copies; each value set differently on both sides is a
///   [SyncConflict] the user resolves ([SyncChoices]).
/// - [SyncReviewHost] / [SyncRecoveryHost]: a store that asks before its
///   first sync and keeps [SyncRecovery] copies of both sides.
/// - [SyncProgress]: the steps of a first sync after sign-in.
/// - Widgets: [SyncStatusChip], [SyncIssueBanner], [SyncReviewPrompt] and
///   [showSyncReviewDialog], [SyncProgressOverlay], [SyncRecoveryPanel],
///   worded by [SyncStrings] (French and English).
library;

export 'src/reconciliation.dart';
export 'src/sync_progress.dart';
export 'src/sync_progress_view.dart';
export 'src/sync_recovery_panel.dart';
export 'src/sync_review.dart';
export 'src/sync_review_dialog.dart';
export 'src/sync_status.dart';
export 'src/sync_status_widgets.dart';
export 'src/sync_strings.dart';
