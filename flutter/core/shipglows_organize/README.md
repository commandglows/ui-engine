# shipglows_organize

Folders, typed trees, manual order, tags and search for business items,
started from the CommandGlows snippets. Pure Dart (no Flutter import), so a
pure Dart core such as DreamGlows `path_core_dart` uses it too. Storage stays
in each app: an item only exposes a folder or parent id, a tag list and a
rank. Status and due dates are not here (separate packages later).

- Tags: `normalizeTags` (string or list, `#` removed, lower case, no
  duplicate, `TagRules` limits), `normalizeTag`, `distinctTags`, `tagCounts`,
  `renameTag` (merges into an existing tag), `removeTag`.
- Folders: `Folder(id, name, parentId)`, flat or nested. `FolderTree` gives
  `children`, `path`, `label` (`Parent / Child`), `descendants`,
  `subtreeIds` (filter or cascading delete), and checks `checkName` (unique
  among siblings, ignoring case) and `checkMove` (no cycle) as a
  `FolderProblem`. Missing parents and stored cycles show at the root.
  Apps that store a folder name instead (CommandGlows snippets) use
  `normalizeFolderName` and `distinctFolderNames`.
- Typed trees: `TypedTree(items, idOf:, parentIdOf:, typeOf:, rules:)` with
  `ParentRules({type: {parent types}})` (DreamGlows: dream > goal > step >
  action). Same shown-tree reads as folders (`FolderTree` is the one-type
  case), `checkParent(type, parentId, movingId:)` as a `TreeProblem`
  (`unknownParent`, `incompatibleType`, `cycle`, also refused when the stored
  ancestors loop), and walks along the stored parent ids: `walkUp(item)`
  (ancestors nearest first, plus the missing parent or cycle met) and
  `walkDown(id)` (each descendant once even when links loop).
- Manual order: `rankBetween(before, after)` (base-62 keys, a move rewrites
  one item), `isRank`, `orderByRank(items, rankOf)` (ranked first, then
  given order), `planRankMove(ordered, id, toIndex, idOf:, rankOf:)`. Same
  contract to the character as DreamGlows TypeScript
  (`path-core/fixtures/action-rank-v1.json`).
- Search: `OrganizeQuery.parse` (`#term` prefixes a tag, other terms search
  the given fields or prefix a tag); `OrganizeFilter` (folders, tags with
  `TagMatch.all` or `.any`).
- Labels: `normalizeLabels` for free comma lists (keywords, topics) that keep
  their case and inner spaces, without duplicates (ignoring case).
- Sort: `sortedBy(items, key, direction: SortDirection.descending)`, stable,
  items with a `null` key last (dates, names, counts).
- Names: `nameKey` (`searchKey`, trimmed and single-spaced: one name
  whatever its case, accents or spaces), `compareNames` to sort by it,
  `checkNameAmong` for flat collections stored by name (playlists: empty or
  taken, as `FolderProblem`), `duplicateAliases` mapping the ids of items
  created twice under one name (two devices) to the smallest id kept.
- Text search: `searchKey` (lower case, no accents, `œ`/`æ` as `oe`/`ae`), `searchWords`,
  `matchesSearch(query, fields)` (every word in some field) and
  `rankBySearch(items, query, label:, fields:)` (label starting with the
  query, then label holding every word, then a match in the fields).

Used by CommandGlows (snippets), ContentGlows (History search with
`#tag` and date sort, keyword and topic lists), BeatGlows (library search
and sort, playlist names, artist and song merge after a sync), the
ShipGlows app (command palette ranking, GitHub repository picker) and
DreamGlows (`path_core_dart`: parent rules and checks, next action
ancestors, progress roll-up, manual action order). Not yet: tag colours,
UI widgets.
