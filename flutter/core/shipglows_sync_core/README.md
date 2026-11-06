# shipglows_sync_core

Device-to-account sync logic in pure Dart: statuses, `reconcileSnapshots`, `indexSyncCollection`, review and recovery models, `SyncProgress`, temporary ids. Hosts implement `SyncSource`, `SyncReviewHost` and `SyncRecoveryHost`; a `ChangeNotifier` satisfies their `SyncObservable` as is. Widgets and texts live in [`shipglows_sync`](../../features/shipglows_sync/README.md), which re-exports this package.
