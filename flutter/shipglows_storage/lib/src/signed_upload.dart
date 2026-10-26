/// Uploads straight to object storage through parts a backend signs one by
/// one, extracted from ContentGlows: the backend keeps the storage keys, the
/// app only ever holds a URL valid a few minutes. Free of `dart:io`, so it
/// runs on the web too; the app brings the HTTP calls ([SignedUploadCall],
/// [SignedPartPut]) with its own base URL, auth and client.
///
/// The ShipGlows protocol, under a base path per purpose (ContentGlows lab's
/// direct-upload routes):
/// - `POST <base>` with `clientKey`, `fileName`, `mimeType`, `byteSize` and
///   `checksumSha256` opens a session, `{uploadId, parts: [{partNumber,
///   sizeBytes}]}`, or answers `{result}` when this `clientKey` already
///   finished. The same `clientKey` resumes the open session.
/// - `POST <base>/<uploadId>/parts/<n>/sign` with `partNumber`,
///   `checksumSha256` and `sizeBytes` answers `{partNumber, sizeBytes,
///   uploadUrl, headers}`; the client PUTs the part there.
/// - `POST <base>/<uploadId>/complete` with `parts: [{partNumber, etag,
///   checksumSha256, sizeBytes}]` answers the purpose's result.
/// - `DELETE <base>/<uploadId>` abandons the session.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'blob_errors.dart';
import 'transfer.dart';
import 'transfer_journal.dart';

/// One part as the backend declared it: its number and size.
typedef SignedUploadPart = ({int number, int bytes});

/// Where to PUT one part: a URL signed by the backend and the headers it was
/// signed with.
typedef SignedPartTarget = ({Uri url, Map<String, String> headers});

/// A stored part, for the completion call.
typedef SignedPartReceipt = ({
  int number,
  String etag,
  String checksumSha256,
  int bytes,
});

/// PUTs [bytes] to [target] and returns the ETag storage answered, calling
/// [onSent] with the bytes sent so far.
///
/// Throws [BlobTransientFailure] (with the client's error as `cause`) for a
/// failure worth another signed attempt: a network drop, a timeout, a 5xx,
/// a 429, and a 403 from storage, which is an expired signature. Throws
/// [BlobTransferCancelled] once the transfer is cancelled; the app aborts
/// its own request then. Any other error is final and passes through.
typedef SignedPartPut = Future<String> Function(
  SignedPartTarget target,
  Uint8List bytes, {
  required void Function(int sent) onSent,
});

/// Sends one JSON call of the protocol to the backend and returns its
/// decoded JSON answer (empty for none). [slow] marks the completion, which
/// checks the whole file and may take minutes. Fails like [SignedPartPut],
/// a 403 from the backend being final.
typedef SignedUploadCall = Future<Map<String, Object?>> Function(
  String method,
  String path, {
  Map<String, Object?>? body,
  bool slow,
});

/// Keys an answer must never hold: storage stays the backend's business.
const _providerKeys = {
  'provider',
  'bucket',
  'bucketname',
  'objectkey',
  'storagekey',
  'bunnystoragekey',
  'bunnycdnhostname',
  'awsaccesskeyid',
  'awssecretaccesskey',
};

/// Throws a [FormatException] when [json] names a storage provider setting.
void rejectProviderConfiguration(Map<Object?, Object?> json) {
  for (final key in json.keys) {
    final normalized =
        '$key'.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (_providerKeys.contains(normalized)) {
      throw FormatException('Provider configuration is forbidden: $key');
    }
  }
}

/// The parts declared in [raw], the `parts` list of an opened session.
List<SignedUploadPart> signedUploadPartsFromJson(Object? raw) {
  final parts = <SignedUploadPart>[];
  for (final part in raw is List ? raw : const []) {
    if (part is! Map) continue;
    rejectProviderConfiguration(part);
    parts.add((
      number: _int(part['partNumber'] ?? part['part_number']) ?? 0,
      bytes: _int(part['sizeBytes'] ?? part['size_bytes']) ?? 0,
    ));
  }
  return parts;
}

/// The target in a sign answer [json] for part [number] of [bytes] bytes.
///
/// Throws a [FormatException] when the answer is for another part, has no
/// http(s) URL, or names a storage provider setting.
SignedPartTarget signedPartTargetFromJson(
  Map<Object?, Object?> json, {
  required int number,
  required int bytes,
}) {
  rejectProviderConfiguration(json);
  final url = Uri.tryParse('${json['uploadUrl'] ?? json['upload_url'] ?? ''}');
  if (_int(json['partNumber'] ?? json['part_number']) != number ||
      _int(json['sizeBytes'] ?? json['size_bytes']) != bytes ||
      url == null ||
      !url.hasAuthority ||
      (url.scheme != 'https' && url.scheme != 'http')) {
    throw const FormatException('The signed part instruction is invalid.');
  }
  final headers = json['headers'];
  return (
    url: url,
    headers: headers is Map
        ? {
            for (final entry in headers.entries)
              '${entry.key}': '${entry.value ?? ''}',
          }
        : const {},
  );
}

/// [receipt] as the completion call wants it.
Map<String, Object?> signedPartReceiptToJson(SignedPartReceipt receipt) => {
      'partNumber': receipt.number,
      'etag': receipt.etag,
      'checksumSha256': receipt.checksumSha256,
      'sizeBytes': receipt.bytes,
    };

/// Streams [source], [totalBytes] long, into [parts]: each part is signed by
/// [sign] and put by [put]; a part that fails transiently is signed and sent
/// again by [retry], so a flaky connection does not restart the file.
///
/// Parts already in [stored] (a resume) are read past without being sent
/// again when their checksum still matches; [onStored] hears each newly
/// stored part, to note it. Returns the receipts in part order.
///
/// Throws a [FormatException] when the source does not fit the parts.
Future<List<SignedPartReceipt>> uploadSignedParts({
  required List<SignedUploadPart> parts,
  required Stream<List<int>> source,
  required int totalBytes,
  required Future<SignedPartTarget> Function(
    int number,
    String checksumSha256,
    int bytes,
  ) sign,
  required SignedPartPut put,
  RetryPolicy retry = const RetryPolicy(),
  TransferControl? control,
  Map<int, SignedPartReceipt> stored = const {},
  FutureOr<void> Function(SignedPartReceipt receipt)? onStored,
}) async {
  if (parts.isEmpty) {
    throw const FormatException('The upload has no part instructions.');
  }
  final receipts = <SignedPartReceipt>[];
  final builder = BytesBuilder(copy: false);
  var index = 0;
  var done = 0;
  await for (final chunk in source) {
    control?.check();
    var offset = 0;
    while (offset < chunk.length) {
      if (index >= parts.length) {
        throw const FormatException('The file exceeds its upload parts.');
      }
      final part = parts[index];
      final take = min(part.bytes - builder.length, chunk.length - offset);
      builder.add(chunk.sublist(offset, offset + take));
      offset += take;
      if (builder.length != part.bytes) continue;
      final bytes = builder.takeBytes();
      final checksum = sha256.convert(bytes).toString();
      final kept = stored[part.number];
      if (kept != null &&
          kept.checksumSha256 == checksum &&
          kept.bytes == bytes.length) {
        receipts.add(kept);
      } else {
        final sentBefore = done;
        final etag = await retry.run(
          () async {
            control?.report(sentBefore, totalBytes);
            final target = await sign(part.number, checksum, bytes.length);
            control?.check();
            return put(
              target,
              bytes,
              onSent: (sent) => control?.report(sentBefore + sent, totalBytes),
            );
          },
          control: control,
        );
        if (etag.trim().isEmpty) {
          throw const FormatException('Storage returned no part receipt.');
        }
        final receipt = (
          number: part.number,
          etag: etag,
          checksumSha256: checksum,
          bytes: bytes.length,
        );
        await onStored?.call(receipt);
        receipts.add(receipt);
      }
      done += bytes.length;
      control?.report(done, totalBytes);
      index++;
    }
  }
  if (builder.length != 0 || index != parts.length || done != totalBytes) {
    throw const FormatException(
      'The file does not match its upload parts.',
    );
  }
  return receipts;
}

/// The client side of the ShipGlows signed upload protocol.
class SignedUploadClient {
  SignedUploadClient({
    required this.call,
    required this.put,
    this.retry = const RetryPolicy(),
    this.journal,
  });

  final SignedUploadCall call;
  final SignedPartPut put;
  final RetryPolicy retry;

  /// Notes the parts stored per session, so the same upload started again
  /// after a lost connection sends only the missing parts; without it every
  /// part goes again.
  final TransferJournal? journal;

  /// Uploads the [byteSize] bytes [openRead] gives (called once to hash
  /// them when [checksumSha256] is null, once to send them) through the
  /// routes under [basePath], and returns the backend's result.
  ///
  /// The backend keys the session by [clientKey]: the same key resumes or
  /// replays it. A cancellation abandons the session; any other failure
  /// keeps it for the next attempt with the same key. Throws a
  /// [FormatException] for an answer that breaks the protocol.
  Future<Map<String, Object?>> upload({
    required String basePath,
    required String clientKey,
    required String fileName,
    required String mimeType,
    required int byteSize,
    required Stream<List<int>> Function() openRead,
    String? checksumSha256,
    TransferControl? control,
  }) async {
    final checksum =
        checksumSha256 ?? (await sha256.bind(openRead()).first).toString();
    control?.check();
    final opened = await retry.run(
      () => call(
        'POST',
        basePath,
        body: {
          'clientKey': clientKey,
          'fileName': fileName,
          'mimeType': mimeType,
          'byteSize': byteSize,
          'checksumSha256': checksum,
        },
      ),
      control: control,
    );
    final finished = opened['result'];
    if (finished is Map) return finished.cast<String, Object?>();
    final uploadId = '${opened['uploadId'] ?? ''}';
    if (uploadId.isEmpty) {
      throw const FormatException('The upload session has no identifier.');
    }
    final parts = signedUploadPartsFromJson(opened['parts']);
    final journalId =
        sha256.convert(utf8.encode('$basePath\n$uploadId')).toString();
    try {
      final receipts = await uploadSignedParts(
        parts: parts,
        source: openRead(),
        totalBytes: byteSize,
        sign: (number, checksum, bytes) async => signedPartTargetFromJson(
          await call(
            'POST',
            '$basePath/$uploadId/parts/$number/sign',
            body: {
              'partNumber': number,
              'checksumSha256': checksum,
              'sizeBytes': bytes,
            },
          ),
          number: number,
          bytes: bytes,
        ),
        put: put,
        retry: retry,
        control: control,
        stored: await _storedParts(journalId),
        onStored: (receipt) => _noteStored(journalId, receipt),
      );
      // Not retried: a completion that landed would fail when sent again.
      final result = await call(
        'POST',
        '$basePath/$uploadId/complete',
        body: {'parts': receipts.map(signedPartReceiptToJson).toList()},
        slow: true,
      );
      await journal?.delete(journalId);
      return result;
    } on BlobTransferCancelled {
      await journal?.delete(journalId);
      // Best effort: the backend expires sessions nobody abandoned.
      unawaited(
        call('DELETE', '$basePath/$uploadId')
            .then<void>((_) {}, onError: (Object _) {}),
      );
      rethrow;
    }
  }

  Future<Map<int, SignedPartReceipt>> _storedParts(String journalId) async {
    final parts = (await journal?.read(journalId))?['parts'];
    if (parts is! Map) return const {};
    return {
      for (final entry in parts.entries)
        if (int.tryParse('${entry.key}') case final number?)
          if (entry.value case {
            'etag': final String etag,
            'checksumSha256': final String checksum,
            'bytes': final int bytes,
          })
            number: (
              number: number,
              etag: etag,
              checksumSha256: checksum,
              bytes: bytes,
            ),
    };
  }

  Future<void> _noteStored(String journalId, SignedPartReceipt receipt) async {
    final journal = this.journal;
    if (journal == null) return;
    final note = await journal.read(journalId);
    final parts = note?['parts'] is Map
        ? (note!['parts'] as Map).cast<String, Object?>()
        : <String, Object?>{};
    parts['${receipt.number}'] = {
      'etag': receipt.etag,
      'checksumSha256': receipt.checksumSha256,
      'bytes': receipt.bytes,
    };
    await journal.write(journalId, {'parts': parts});
  }
}

int? _int(Object? value) => switch (value) {
      final int number => number,
      final num number => number.toInt(),
      final String text => int.tryParse(text),
      _ => null,
    };
