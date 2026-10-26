/// Files kept away from this computer, for ShipGlows Flutter apps, extracted
/// from BeatGlows.
///
/// - [BlobStore]: put, get, download, head, delete and list objects by key,
///   with [WriteCondition] (always, ifAbsent, ifMatch) and typed
///   [BlobStoreException]s (precondition failed, access denied, transient,
///   invalid key, cancelled).
/// - [S3BlobStore]: any S3-compatible bucket (Cloudflare R2, MinIO, AWS)
///   over HTTPS, signed by [SigV4Signer]; large files go up in parts.
/// - [FolderBlobStore]: a folder another program keeps in sync.
/// - [MemoryBlobStore]: for tests.
/// - [TransferControl]: progress and cancellation of one transfer;
///   [RetryPolicy]: tries again after a network hiccup, with growing waits;
///   [TransferJournal] ([FileTransferJournal], [MemoryTransferJournal]):
///   lets [S3BlobStore] resume an interrupted upload or download.
/// - [SignedUploadClient] and [uploadSignedParts]: uploads through parts a
///   backend signs (ContentGlows lab); `signed_upload.dart` is the web-safe
///   entry with only these and the transfer types.
/// - [parseS3Endpoint] and [testBlobStore] for a storage settings page.
library;

export 'src/blob_store.dart';
export 'src/blob_store_probe.dart';
export 'src/file_transfer_journal.dart';
export 'src/folder_blob_store.dart';
export 'src/s3_blob_store.dart';
export 'src/s3_endpoint.dart';
export 'src/signed_upload.dart';
export 'src/sigv4.dart';
export 'src/transfer.dart';
export 'src/transfer_journal.dart';
