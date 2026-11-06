# shipglows_recents

Recently used items of a picker (projects, ideas, tasks) and the quick-pick
chips shown under it. A scope groups the ids that compete together:
`projects`, or `ideas:<projectId>` so the ideas follow the chosen project.

- `RecentsStore` (`recent(scope, limit:)` latest use first, `markUsed`,
  `forget`, a `Listenable`). `SettingsRecentsStore(settings, key)` keeps
  `{scope: {id: epochMillis}}` in one synced `SettingKey.map` with
  `mergeFields` (`shipglows_settings`): each use is one nested field, so two
  devices never overwrite each other; 20 ids kept per scope, the pruned ones
  sent as `null` (the remote deep-merges and drops them). A use is always
  stamped after the latest one, so a late device clock still puts it first.
  `MemoryRecentsStore` for tests.
- `pickRecent(recent, items, idOf, limit:, fill:)` keeps only the items the
  app still offers (deleted or archived ones disappear), in recent order, each
  id at most once (first occurrence wins, so an active item also used last
  shows one chip); with `fill`, the other items follow in their given order so
  the chips are never empty before the first use.
- `RecentChips(choices, onSelected, selectedId, maxLines)`: chips measured
  before layout, as many as fit on `maxLines` lines without breaking the
  order; long labels shortened with a tooltip; the selected chip is filled
  and outlined (not colour alone); button and selected semantics.

Used by ContentGlows (capture overlay: 4 recent projects, two lines of
recent ideas of the chosen project, recorded by the main engine after a
save, synced through `/api/settings` `recents`). Planned: DreamGlows
(projects and tasks).
