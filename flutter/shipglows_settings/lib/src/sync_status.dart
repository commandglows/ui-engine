/// Where the account settings stand against their remote copy.
enum SyncHealth {
  /// Signed out or no remote: settings stay on this device.
  localOnly,

  /// Every change is on the remote.
  synced,

  /// Changes wait for the remote (offline, or a retry is scheduled).
  pending,

  /// A pull or push is running.
  syncing,

  /// The remote refused the last attempt; [SyncIssue.retryable] says whether
  /// the next retry can succeed on its own.
  failed,
}

class SyncIssue {
  const SyncIssue({
    required this.code,
    required this.message,
    required this.occurredAt,
    this.retryable = true,
  });

  /// Stable code for diagnostics (`timeout`, `auth`, `remote_error`).
  final String code;
  final String message;
  final DateTime occurredAt;

  /// `false` when only the user can fix it (sign in again).
  final bool retryable;
}

class SyncStatus {
  const SyncStatus({
    required this.health,
    this.pendingCount = 0,
    this.lastSyncedAt,
    this.issue,
  });

  const SyncStatus.localOnly()
    : health = SyncHealth.localOnly,
      pendingCount = 0,
      lastSyncedAt = null,
      issue = null;

  final SyncHealth health;

  /// Settings changed on this device and not on the remote yet.
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final SyncIssue? issue;

  bool get hasPendingChanges => pendingCount > 0;

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.health == health &&
      other.pendingCount == pendingCount &&
      other.lastSyncedAt == lastSyncedAt &&
      other.issue?.code == issue?.code &&
      other.issue?.occurredAt == issue?.occurredAt;

  @override
  int get hashCode => Object.hash(
    health,
    pendingCount,
    lastSyncedAt,
    issue?.code,
    issue?.occurredAt,
  );

  @override
  String toString() => 'SyncStatus(${health.name}, pending: $pendingCount)';
}
