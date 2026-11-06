/// Why a storage call failed. Free of `dart:io`, like everything the web
/// can use.
library;

import 'blob_strings.dart';

export 'blob_strings.dart';

/// Why a store call failed. Each kind keeps the data it needs; [message]
/// gives the French text and [messageIn] the text in the language of the
/// [BlobStrings] the app picks.
sealed class BlobStoreException implements Exception {
  const BlobStoreException();

  /// The French text, as the package has always written it.
  String get message => messageIn(BlobStrings.fr);

  /// The text in the language of [strings].
  String messageIn(BlobStrings strings);

  @override
  String toString() => message;
}

/// The `WriteCondition` did not hold: someone else wrote the object first.
final class BlobPreconditionFailed extends BlobStoreException {
  const BlobPreconditionFailed();

  @override
  String messageIn(BlobStrings strings) => strings.preconditionFailed;
}

/// Why access was denied.
enum BlobAccessReason {
  /// Wrong keys or a missing right, with no more precise cause.
  credentials,

  /// The storage rejected the secret key.
  secretKeyRejected,

  /// The storage does not know the access key ID.
  accessKeyUnknown,

  /// The bucket does not exist; [BlobAccessDenied.bucket] names it.
  bucketMissing,

  /// The system refused writes into the synchronised folder.
  folderNotWritable,
}

/// The credentials are wrong or lack a right; retrying will not help.
final class BlobAccessDenied extends BlobStoreException {
  const BlobAccessDenied([
    this.reason = BlobAccessReason.credentials,
    this.bucket,
  ]);

  /// What was refused.
  final BlobAccessReason reason;

  /// The bucket's name, for [BlobAccessReason.bucketMissing].
  final String? bucket;

  @override
  String messageIn(BlobStrings strings) => switch (reason) {
    BlobAccessReason.credentials => strings.accessDenied,
    BlobAccessReason.secretKeyRejected => strings.secretKeyRejected,
    BlobAccessReason.accessKeyUnknown => strings.accessKeyUnknown,
    BlobAccessReason.bucketMissing => strings.bucketMissing(bucket ?? ''),
    BlobAccessReason.folderNotWritable => strings.folderNotWritable,
  };
}

/// Why a transient failure happened.
enum BlobTransientReason {
  /// The storage cannot be reached over the network.
  unreachable,

  /// The exchange broke off; [BlobTransientFailure.detail] says how.
  interrupted,

  /// The storage's answer to a multipart upload had no upload identifier.
  uploadIdMissing,

  /// The storage dropped an upload in progress.
  uploadAborted,

  /// The storage refused to assemble the parts of an upload.
  assemblyRefused,

  /// The object changed during a download; it is fetched again from zero.
  objectChanged,

  /// The storage answered with an unexpected status; the detail gives it.
  storageAnswered,

  /// The synchronised folder is missing, as when its drive is not mounted;
  /// the detail is its path.
  folderMissing,

  /// The synchronised folder cannot be read; the detail says why.
  folderUnreachable,

  /// Free text: the detail is shown as it is.
  other,
}

/// The place could not be reached or answered oddly; retrying may help.
final class BlobTransientFailure extends BlobStoreException {
  /// A failure with the free-text [detail], shown as it is. Also keeps the
  /// `BlobTransientFailure('text')` calls of earlier versions working.
  const BlobTransientFailure(String detail, {Object? cause})
    : this.because(BlobTransientReason.other, detail: detail, cause: cause);

  /// A failure for [reason]. [detail] fills the reasons whose text carries a
  /// value, and [cause] is the error underneath.
  const BlobTransientFailure.because(
    this.reason, {
    this.detail,
    this.cause,
  });

  /// What went wrong.
  final BlobTransientReason reason;

  /// The value the text of [reason] carries, when it has one.
  final String? detail;

  /// The error underneath, such as the HTTP client's, for an app that maps
  /// it its own way once retries are spent.
  final Object? cause;

  @override
  String messageIn(BlobStrings strings) => switch (reason) {
    BlobTransientReason.unreachable => strings.unreachable,
    BlobTransientReason.interrupted => strings.interrupted(detail ?? ''),
    BlobTransientReason.uploadIdMissing => strings.uploadIdMissing,
    BlobTransientReason.uploadAborted => strings.uploadAborted,
    BlobTransientReason.assemblyRefused => strings.assemblyRefused,
    BlobTransientReason.objectChanged => strings.objectChanged,
    BlobTransientReason.storageAnswered =>
      strings.storageAnswered(detail ?? ''),
    BlobTransientReason.folderMissing => strings.folderMissing(detail ?? ''),
    BlobTransientReason.folderUnreachable =>
      strings.folderUnreachable(detail ?? ''),
    BlobTransientReason.other => detail ?? strings.unspecifiedFailure,
  };
}

/// The key is not a valid relative path.
final class BlobInvalidKey extends BlobStoreException {
  const BlobInvalidKey(this.key);

  /// The key as given.
  final String key;

  @override
  String messageIn(BlobStrings strings) => strings.invalidKey(key);
}

/// What was downloaded does not have the expected SHA-256: the object is
/// not the one asked for, or it was damaged. The target was left untouched;
/// sending again would fetch the same bytes, so it is not retried.
final class BlobChecksumMismatch extends BlobStoreException {
  const BlobChecksumMismatch(this.key);

  /// The key of the object that did not match.
  final String key;

  @override
  String messageIn(BlobStrings strings) => strings.checksumMismatch(key);
}

/// The transfer was stopped through `TransferControl.cancel`.
final class BlobTransferCancelled extends BlobStoreException {
  const BlobTransferCancelled();

  @override
  String messageIn(BlobStrings strings) => strings.transferCancelled;
}
