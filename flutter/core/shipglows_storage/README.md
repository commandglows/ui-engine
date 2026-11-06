# shipglows_storage

Files kept away from this computer (audio, video, images), extracted from
BeatGlows. Business-data sync is not here: it belongs to `shipglows_sync`.
The chosen provider is Cloudflare R2, spoken to only through the S3 API so
another S3-compatible bucket is an endpoint change.

- `BlobStore`: `putBytes` (with `WriteCondition.always`, `.ifAbsent`,
  `.ifMatch(etag)`), `putFile` (streamed), `getBytes`, `download` (to a
  `.part` file, then renamed), `head`, `delete`, `list(prefix)`. A key is a
  relative forward-slash path (`checkBlobKey`). Failures are a sealed
  `BlobStoreException` with a French message: `BlobPreconditionFailed`,
  `BlobAccessDenied` (do not retry), `BlobTransientFailure` (may retry),
  `BlobInvalidKey`, `BlobTransferCancelled`.
- `TransferControl(onProgress: (done, total) {…})`, passed to `putBytes`,
  `putFile`, `getBytes` and `download`: progress (bytes kept from an
  interrupted attempt count as done) and `cancel()`, which aborts the request
  under way.
- `S3BlobStore(config, retry:, journal:, multipartThreshold:, partBytes:)`:
  path-style requests over `dart:io`, signed by `SigV4Signer` (checked on the
  AWS test vectors), no AWS SDK; files over 64 MB go up in 16 MB parts.
  `RetryPolicy` (4 tries, waits from 0.5 s doubling up to 30 s, with
  jitter) sends again every request that can safely be sent twice, a single
  part rather than the whole file; a conditional write is never resent. With
  a `TransferJournal` (`FileTransferJournal(dir)` survives a restart,
  `MemoryTransferJournal` does not), a cancelled or failed multipart upload
  is kept and resumes from its stored parts (started over if the bucket
  dropped it), and a download resumes from its `.part` file with a `Range`
  bound to the version by `If-Match`. Without a journal an interrupted
  upload is aborted.
- `FolderBlobStore(root, incomingSuffix:)`: a folder kept in sync by another
  program; writes go through a temporary file, the tag is the SHA-256, a
  missing root (unmounted drive) is reported, never created.
- `MemoryBlobStore` for tests; `parseS3Endpoint` (https, or http on this
  computer for MinIO) and `testBlobStore` (write, read back, delete a probe)
  for a settings page.
- Tests: one contract suite run on every store, including a local fake S3
  bucket (`test/fake_s3_server.dart`) that also proves retries and resumes;
  the run on a real bucket needs `SHIPGLOWS_S3_ENDPOINT`, `_BUCKET`,
  `_REGION`, `_KEY_ID`, `_SECRET` and is skipped without them. Proven on
  Cloudflare R2 on 2026-10-27 (bucket `shipglows-storage-tests`, EU
  jurisdiction, keys limited to it in Doppler `dotfiles`/`dev`):

  ```bash
  SHIPGLOWS_S3_ENDPOINT=https://b805cca6c486d78d68e7a4498292be56.eu.r2.cloudflarestorage.com SHIPGLOWS_S3_BUCKET=shipglows-storage-tests SHIPGLOWS_S3_REGION=auto doppler run --project dotfiles --config dev -- flutter test test/blob_stores_test.dart
  ```

- Backend-signed uploads, extracted from ContentGlows: the backend keeps
  the storage keys and signs one part at a time. `import
  'package:shipglows_storage/signed_upload.dart'` is the web-safe entry (no
  `dart:io`). The ShipGlows protocol under a base path: `POST <base>`
  (`clientKey`, `fileName`, `mimeType`, `byteSize`, `checksumSha256`) opens
  `{uploadId, parts}` or answers `{result}`; `POST
  <base>/<id>/parts/<n>/sign` answers `{uploadUrl, headers}`; `POST
  <base>/<id>/complete` with the receipts; `DELETE <base>/<id>` abandons.
  `SignedUploadClient(call:, put:, journal:).upload(...)` runs it all;
  `uploadSignedParts(parts:, source:, sign:, put:)` is the part loop alone,
  for a backend with its own open and complete routes. The app brings
  `call` (its JSON client with base URL and auth) and `put` (a raw PUT),
  and says which failures are transient (`BlobTransientFailure(cause:)`).
  A transiently failed part is signed and sent again; a sign answer that
  names a bucket or provider key is refused; with a journal a resend skips
  the parts already stored.

- `download(key, target, expectedSha256:)` checks the bytes before
  `target` is written (a resumed download is checked whole) and throws
  `BlobChecksumMismatch` otherwise; `sha256OfFile(file)` hashes in chunks.
- `S3BlobStore(partConcurrency: 3)`: the parts of one file go up three at a
  time (each holds `partBytes` in memory); resume and progress are
  unchanged.
- `BlobCache(directory:, store:, maxBytes:)`: `fetch(key, expectedSha256:)`
  downloads on demand into `directory` (two callers share one download),
  marks the file as used and drops the least recently used ones above
  `maxBytes`, never the file just fetched; `peek`, `remove`, `evictToFit`.

- Signed uploads send three parts at a time too
  (`SignedUploadClient(partConcurrency:)`, `uploadSignedParts(partConcurrency:)`):
  the source is read once, at most that many parts in memory, journal notes
  written one at a time; the first failure starts no new part and is
  rethrown.
- `BrowserTransferJournal(prefix:)` keeps the resume notes in
  `localStorage`, so a web upload resumes its missing parts after a reload
  (its constructor throws off the web; use `FileTransferJournal` there).
  `KeyValueTransferJournal(store)` is the same over any synchronous
  key-value store; a full or blocked store only means the upload starts
  over.
- Error messages: every `BlobStoreException` keeps its data and a reason
  (`BlobAccessReason`, `BlobTransientReason`); `messageIn(BlobStrings.en)`,
  `BlobStrings.fr` or the app's own `BlobStrings` give the text, `message`
  stays French.

Not yet: background transfers (Android/iOS).
