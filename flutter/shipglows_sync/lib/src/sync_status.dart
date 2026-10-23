import 'package:flutter/foundation.dart';

/// Where the account data stands against its remote copy.
enum SyncHealth {
  /// Signed out or no remote: data stays on this device.
  localOnly,

  /// Every change is on the remote.
  synced,

  /// Changes wait for the remote (offline, or a retry is scheduled).
  pending,

  /// A pull or push is running.
  syncing,

  /// The device and the account both hold data that differ: sync waits for
  /// the user to pick a side per difference ([SyncReview]). Until then the
  /// device copy is shown and nothing is sent.
  needsReview,

  /// The account was never read on this device and the last attempt failed:
  /// the values shown are the device's, not verified against the account.
  unreachable,

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

  /// Changes made on this device and not on the remote yet.
  final int pendingCount;
  final DateTime? lastSyncedAt;
  final SyncIssue? issue;

  bool get hasPendingChanges => pendingCount > 0;

  /// Whether the user has something to do or to know (review, error).
  bool get needsAttention =>
      health == SyncHealth.needsReview ||
      health == SyncHealth.unreachable ||
      health == SyncHealth.failed ||
      (health == SyncHealth.pending && issue != null);

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

/// Anything synced to an account that the shared widgets can show: the
/// settings controller, a data repository...
abstract interface class SyncSource implements Listenable {
  SyncStatus get status;

  /// Pulls then pushes now. Never throws: the outcome is in [status].
  Future<void> sync();
}
