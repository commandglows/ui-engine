# shipglows_sync

Shared Flutter snapshot reconciliation, sync status, review, progress and recovery
primitives. Apps own authentication, account association, storage, transport,
idempotent writes and domain policy. This package does not supply a backend or a
multi-device edit/delete protocol.

## Collections

Use `indexSyncCollection(records, idOf:)` before building a collection snapshot.
The caller provides the stable business identity and any normalization. Records
must be JSON-safe, as for `SyncSnapshot`.

```dart
final device = indexSyncCollection(deviceRows, idOf: (row) => row['id'] as String);
final account = indexSyncCollection(accountRows, idOf: (row) => row['id'] as String);
if (!device.isConsistent || !account.isConsistent) {
  // Expose the collisions; do not apply the retained first values.
  return;
}
final plan = reconcileSnapshots(
  SyncSnapshot(collections: {'items': device.records}),
  SyncSnapshot(collections: {'items': account.records}),
);
if (!plan.isComplete) {
  // Collect explicit choices before writing the provisional merged snapshot.
  return;
}
// Apply plan.merged through the app's idempotent, authenticated adapters.
```

`deviceRows` and `accountRows` above are `List<Map<String, Object?>>` with an
`id` field.

- Identical duplicates fold once using `sameJson`, including reordered map keys.
- Contradictory duplicates are reported with their id, first and duplicate
  values. The first value stays in the index for inspection; `isConsistent` is
  false. No source record is modified or deleted.
- Empty or whitespace-only ids throw `ArgumentError`. Other ids are kept
  exactly as supplied by the caller.
- Index maps and collision lists are unmodifiable containers; payloads are not
  deep-frozen. Callers must not mutate them during reconciliation/review.
- Reconciliation still compares whole records and requires explicit choices
  for differing values. An unresolved plan contains provisional device values;
  it is not authority to write them.

CommandGlows snippets consume both collection indexing and reconciliation.
Their trigger key, semantic fields, account gates and local/Convex writes remain
in CommandGlows. Existing settings consumers keep the same API and behavior.

## Regression proof

`test/sync_collection_test.dart` covers indexing, collisions, missing ids, null
JSON values, non-mutation, conflict choices and replay. The integration is also
covered by CommandGlows' snippet sync tests and the existing
`shipglows_settings/test/settings_controller_test.dart` suite.

For this repair, tests may be executed through the CommandGlows consumer's
resolved package configuration and declared Doppler `commandglows/dev` scope,
without resolving dependencies again in this package. These are isolated tests,
not proof of a live authenticated application or a deployed backend. Follow the
operator's test authorization rules; no build or lint is required.
