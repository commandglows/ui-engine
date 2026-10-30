/// Where the last run of each routine is kept, so the minimum gap holds
/// across launches.
///
/// Implementations answer `null` for an id they never saw; they must not
/// throw for a missing id. A failing store never stops a routine:
/// [RoutineScheduler] treats a read error as "no last run" and ignores a
/// write error.
abstract interface class RoutineStore {
  /// When [routineId] last ran (a failed attempt counts), or `null` when it
  /// never ran or the store cannot tell.
  Future<DateTime?> lastRun(String routineId);

  /// Records that [routineId] ran at [at], replacing the previous value.
  Future<void> recordRun(String routineId, DateTime at);
}

/// In memory only: tests, previews, and apps where a restart may run a
/// routine again.
final class MemoryRoutineStore implements RoutineStore {
  final Map<String, DateTime> _runs = {};

  @override
  Future<DateTime?> lastRun(String routineId) async => _runs[routineId];

  @override
  Future<void> recordRun(String routineId, DateTime at) async {
    _runs[routineId] = at;
  }
}

/// Plugs an existing store in (SharedPreferences, a JSON file, a database)
/// without a dependency in this package. The callbacks carry the contract of
/// [RoutineStore]: a missing id answers `null`.
final class CallbackRoutineStore implements RoutineStore {
  const CallbackRoutineStore({
    required Future<DateTime?> Function(String routineId) read,
    required Future<void> Function(String routineId, DateTime at) write,
  }) : _read = read,
       _write = write;

  final Future<DateTime?> Function(String routineId) _read;
  final Future<void> Function(String routineId, DateTime at) _write;

  @override
  Future<DateTime?> lastRun(String routineId) => _read(routineId);

  @override
  Future<void> recordRun(String routineId, DateTime at) =>
      _write(routineId, at);
}
