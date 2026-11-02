# @shipglows/sync

Reusable TypeScript command synchronization engine. The caller injects verified
ownership, one atomic transaction, field footprints and the domain executor.
No application model, network client, login provider or Convex runtime is imported.
`convex-schema` builds the shared table/index definitions using the deployment's
own `defineTable` and `v` builders.

`executeSyncCommand` validates the exact v1 request, compares immutable canonical
intent on replay, checks cross-device writes since the supplied base revision,
executes the injected domain, and persists journal plus receipt in the caller's
transaction. Revisions only advance on accepted writes. No record expires.
Domain divergence becomes a durable `domain:<reason>` conflict so a failed FIFO
head has a visible recovery choice. An executor can mark malformed or unsafe
input with `recoverable:false` to return an explicit rejection instead.
Command size is 32 KiB, canonical document size 512 KiB, page limit 100.

The installation ID is private, durable and never imported from portable data.
One serialized FIFO worker may push for that installation. Same-device commands
are assumed to follow authored order; the server cannot prove arbitrary request
ordering with the v1 envelope. A failed head command blocks later commands.
Field stamps are retained separately per device so a local later write never
hides a prior concurrent write by another installation.

All storage methods must share the same database transaction. A storage adapter
which commits each callback separately does not satisfy this contract. The
DreamGlows Convex wrapper is the first consumer; its fixture-driven domain tests
live under `dreamglows/packages/path-core/tests/remote-sync.test.mjs`.
