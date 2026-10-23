import 'package:flutter/foundation.dart';

import 'reconciliation.dart';

/// The two copies of an account met on a device for the first time, waiting
/// for the user's choices before anything is synced.
@immutable
class SyncReview {
  const SyncReview({
    required this.accountId,
    required this.device,
    required this.account,
  });

  final String accountId;
  final SyncSnapshot device;
  final SyncSnapshot account;

  SyncPlan plan([SyncChoices choices = const {}]) =>
      reconcileSnapshots(device, account, choices: choices);
}

/// Why the last confirmation of a review did not go through.
enum SyncReviewError {
  /// A side changed since the comparison: the review now shows the new one.
  changed,

  /// The account or the device could not be written; nothing was changed
  /// and the sync stays suspended.
  failed,
}

/// Holds the review of an account's first sync on this device (the settings
/// controller, a data repository...).
abstract interface class SyncReviewHost implements Listenable {
  /// The review waiting for the user, or `null`.
  SyncReview? get review;

  bool get isResolvingReview;
  SyncReviewError? get reviewError;

  /// Checks that neither side changed, saves a [SyncRecovery], applies the
  /// merged copy here and sends it to the account. Returns whether it went
  /// through; otherwise [reviewError] says why.
  Future<bool> resolveReview(SyncChoices choices);
}

/// Holds the [SyncRecovery] of the shown account.
abstract interface class SyncRecoveryHost implements Listenable {
  SyncRecovery? get recovery;

  /// Puts [side]'s copy back, here and in the account. Returns whether it
  /// was applied.
  Future<bool> restoreRecovery(SyncSide side);

  /// Deletes the copies from this device.
  Future<void> dropRecovery();
}

/// Device-only copies of both sides taken before a reviewed sync, so a bad
/// choice or an interrupted sync can be undone. Kept until the user drops
/// them; never sent anywhere.
@immutable
class SyncRecovery {
  const SyncRecovery({
    required this.accountId,
    required this.device,
    required this.account,
    required this.savedAt,
    this.confirmed = false,
  });

  factory SyncRecovery.of(SyncReview review, DateTime savedAt) => SyncRecovery(
    accountId: review.accountId,
    device: review.device,
    account: review.account,
    savedAt: savedAt,
  );

  /// `null` when [json] is not a recovery (corrupt or older file).
  static SyncRecovery? fromJson(Map<String, Object?> json) {
    final accountId = json['accountId'];
    final device = json['device'];
    final account = json['account'];
    final savedAt = json['savedAt'] is String
        ? DateTime.tryParse(json['savedAt'] as String)
        : null;
    if (accountId is! String ||
        device is! Map ||
        account is! Map ||
        savedAt == null) {
      return null;
    }
    return SyncRecovery(
      accountId: accountId,
      device: SyncSnapshot.fromJson(device.cast<String, Object?>()),
      account: SyncSnapshot.fromJson(account.cast<String, Object?>()),
      savedAt: savedAt.toUtc(),
      confirmed: json['confirmed'] == true,
    );
  }

  final String accountId;
  final SyncSnapshot device;
  final SyncSnapshot account;
  final DateTime savedAt;

  /// The reviewed sync went through; `false` means it was interrupted.
  final bool confirmed;

  SyncSnapshot of(SyncSide side) => side == SyncSide.device ? device : account;

  SyncRecovery confirm() => SyncRecovery(
    accountId: accountId,
    device: device,
    account: account,
    savedAt: savedAt,
    confirmed: true,
  );

  Map<String, Object?> toJson() => {
    'accountId': accountId,
    'device': device.toJson(),
    'account': account.toJson(),
    'savedAt': savedAt.toUtc().toIso8601String(),
    if (confirmed) 'confirmed': true,
  };
}
