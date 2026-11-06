/// Device-to-account sync logic in pure Dart: no Flutter import, so it runs in
/// any Dart program and is tested headlessly.
///
/// - [SyncStatus] / [SyncSource]: where a synced store stands.
/// - [reconcileSnapshots]: the first sync of an account on a device unites both
///   copies; each value set differently on both sides is a [SyncConflict].
/// - [indexSyncCollection]: indexes JSON-safe records by stable id.
/// - [SyncReviewHost] / [SyncRecoveryHost]: a store that asks before its first
///   sync and keeps [SyncRecovery] copies of both sides.
/// - [SyncProgress]: the steps of a first sync after sign-in.
/// - [rewriteSyncIds] / [holdsTemporaryId]: values pointing at a record created
///   offline wait for its server id.
///
/// Widgets and texts live in `shipglows_sync`.
library;

export 'src/reconciliation.dart';
export 'src/sync_collection.dart';
export 'src/sync_ids.dart';
export 'src/sync_observable.dart';
export 'src/sync_progress.dart';
export 'src/sync_review.dart';
export 'src/sync_status.dart';
