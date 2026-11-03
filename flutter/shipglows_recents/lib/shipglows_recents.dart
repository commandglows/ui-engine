/// Recently used items of a picker (projects, ideas, tasks), kept per scope
/// and synced per account, and the [RecentChips] that put them one tap away
/// under the picker.
///
/// A scope groups the ids that compete together: `projects`, or
/// `ideas:<projectId>` so the ideas shown follow the chosen project.
library;

export 'src/recent_chips.dart';
export 'src/recents_store.dart';
