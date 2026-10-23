/// Records created offline get a temporary id until the server gives them
/// theirs (`offline-…` → `proj_42`). Values that point at such a record
/// (a default project, a linked profile) must wait for the server id before
/// they are sent, then be rewritten with it.
library;

/// Recognizes the temporary ids of an app (`id.startsWith('offline-')`).
typedef TemporaryIdTest = bool Function(String id);

/// [value] with every string equal to a key of [ids] replaced by its server
/// id, at any depth of a JSON-safe value (maps, lists). Other values are
/// returned as is.
Object? rewriteSyncIds(Object? value, Map<String, String> ids) {
  if (value == null || ids.isEmpty) return value;
  return switch (value) {
    final String text => ids[text] ?? text,
    final List<Object?> list => [
      for (final item in list) rewriteSyncIds(item, ids),
    ],
    final Map<Object?, Object?> map => {
      for (final entry in map.entries)
        '${entry.key}': rewriteSyncIds(entry.value, ids),
    },
    _ => value,
  };
}

/// Whether [value] still holds an id that [isTemporary] recognizes, at any
/// depth: such a value cannot be sent yet.
bool holdsTemporaryId(Object? value, TemporaryIdTest isTemporary) =>
    switch (value) {
      final String text => isTemporary(text),
      final List<Object?> list => list.any(
        (item) => holdsTemporaryId(item, isTemporary),
      ),
      final Map<Object?, Object?> map => map.values.any(
        (item) => holdsTemporaryId(item, isTemporary),
      ),
      _ => false,
    };
