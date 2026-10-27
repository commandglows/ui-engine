/// [BlobStore] on an S3-compatible bucket (Cloudflare R2, MinIO, AWS),
/// spoken to directly over HTTPS with SigV4-signed requests.
///
/// Objects are addressed path-style, `<endpoint>/<bucket>/<key>`, which R2
/// and MinIO both accept. Files over [S3BlobStore.multipartThreshold] go up
/// in parts so an upload of a long recording or video never holds it whole
/// in memory.
///
/// Every request that can safely be sent twice is retried after a
/// [BlobTransientFailure] by [S3BlobStore.retry]; a conditional write is
/// not, since its first try may have landed. With a [TransferJournal], a
/// multipart upload or a download interrupted by a cancellation, a lost
/// connection or a restart picks up where it stopped when started again.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shipglows_xml/shipglows_xml.dart';

import 'blob_store.dart';
import 'file_hash.dart';
import 'sigv4.dart';
import 'transfer.dart';
import 'transfer_journal.dart';

/// Where a bucket is and how to sign for it. The keys live in secure
/// storage; this value only travels in memory.
typedef S3Config = ({
  Uri endpoint,
  String bucket,
  String region,
  AwsCredentials credentials,
});

class S3BlobStore implements BlobStore {
  S3BlobStore(
    this.config, {
    HttpClient? client,
    DateTime Function()? clock,
    this.retry = const RetryPolicy(),
    this.journal,
    this.multipartThreshold = 64 * 1024 * 1024,
    this.partBytes = 16 * 1024 * 1024,
    this.partConcurrency = 3,
  }) : assert(partConcurrency >= 1),
       _client =
           client ??
           (HttpClient()..connectionTimeout = const Duration(seconds: 15)),
       _clock = clock ?? DateTime.now,
       // Keys never hold spaces: a pasted key often ends with a newline,
       // which would fail every signature as « Clé secrète refusée ».
       _signer = SigV4Signer(
         credentials: (
           accessKeyId: config.credentials.accessKeyId.trim(),
           secretAccessKey: config.credentials.secretAccessKey.trim(),
         ),
         region: config.region,
       );

  final S3Config config;

  /// How requests are tried again after a network hiccup.
  final RetryPolicy retry;

  /// Where interrupted uploads and downloads are noted to be resumed; none
  /// is resumed without it, and an interrupted upload is then aborted.
  final TransferJournal? journal;

  /// Size from which a file goes up in parts.
  final int multipartThreshold;

  /// Size of each part but the last; S3 wants at least 5 MiB.
  final int partBytes;

  /// Parts of one file sent at the same time; each holds [partBytes] in
  /// memory.
  final int partConcurrency;

  final HttpClient _client;
  final DateTime Function() _clock;
  final SigV4Signer _signer;

  /// Size of the slices a body is written in, between progress reports.
  static const _sendSlice = 256 * 1024;

  /// Closes the connections; the store cannot be used afterwards.
  void close() => _client.close(force: true);

  @override
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
    TransferControl? control,
  }) async {
    checkBlobKey(key);
    Future<BlobInfo> attempt() async {
      final response = await _send(
        'PUT',
        key,
        body: bytes,
        headers: switch (condition) {
          AlwaysWrite() => const {},
          WriteIfAbsent() => const {'if-none-match': '*'},
          WriteIfMatch(:final etag) => {'if-match': etag},
        },
        control: control,
        onSent: (sent) => control?.report(sent, bytes.length),
      );
      await _expectOk(
        response,
        conditional: condition is! AlwaysWrite,
        control: control,
      );
      return (key: key, bytes: bytes.length, etag: _etagOf(response));
    }

    // A conditional write that timed out may have landed: sent again, it
    // would fail on its own success.
    return condition is AlwaysWrite
        ? retry.run(attempt, control: control)
        : attempt();
  }

  @override
  Future<BlobInfo> putFile(
    String key,
    File file, {
    TransferControl? control,
  }) async {
    checkBlobKey(key);
    final length = await file.length();
    if (length <= multipartThreshold) {
      return putBytes(key, await file.readAsBytes(), control: control);
    }
    return _putMultipart(key, file, length, control);
  }

  Future<BlobInfo> _putMultipart(
    String key,
    File file,
    int length,
    TransferControl? control,
  ) async {
    final modified = (await file.stat()).modified.toUtc();
    final journalId = _journalId([
      'put',
      key,
      file.absolute.path,
      '$length',
      '${modified.microsecondsSinceEpoch}',
    ]);
    final resumed = await _readUpload(journalId);
    if (resumed != null) {
      try {
        return await _sendParts(key, file, length, resumed, journalId, control);
      } on _UploadGone {
        // The bucket dropped it (expired or aborted): start over.
      }
    }
    final created = await retry.run(() async {
      final response = await _send(
        'POST',
        key,
        query: {'uploads': ''},
        control: control,
      );
      final uploadId = parseSafeXml(
        await _expectOk(response, control: control),
      ).descendants('UploadId').firstOrNull?.text;
      if (uploadId == null || uploadId.isEmpty) {
        throw const BlobTransientFailure(
          'Réponse S3 sans identifiant d’envoi.',
        );
      }
      return uploadId;
    }, control: control);
    final upload = _Upload(created, partBytes, {});
    await journal?.write(journalId, upload.toJson());
    try {
      return await _sendParts(key, file, length, upload, journalId, control);
    } on _UploadGone {
      throw const BlobTransientFailure('Envoi abandonné par le stockage.');
    }
  }

  /// Sends the parts [upload] lacks, then assembles them. A transient
  /// failure or a cancellation keeps the upload and its note for a resume
  /// when there is a [journal]; anything else aborts it.
  Future<BlobInfo> _sendParts(
    String key,
    File file,
    int length,
    _Upload upload,
    String journalId,
    TransferControl? control,
  ) async {
    try {
      final count = (length + partBytes - 1) ~/ partBytes;
      int sizeOf(int number) =>
          min(partBytes, length - (number - 1) * partBytes);
      // Bytes of the stored parts, plus what each part in flight has sent.
      var stored = 0;
      final inFlight = <int, int>{};
      void report() => control?.report(
        stored + inFlight.values.fold(0, (sum, sent) => sum + sent),
        length,
      );
      final pending = <int>[];
      for (var number = 1; number <= count; number++) {
        if (upload.parts.containsKey(number)) {
          stored += sizeOf(number);
        } else {
          pending.add(number);
        }
      }
      report();
      // Notes go one at a time: two writers of the same journal file would
      // race.
      Future<void> noting = Future.value();
      var failed = false;
      Future<void> sendPart(int number) async {
        control?.check();
        final offset = (number - 1) * partBytes;
        final builder = BytesBuilder(copy: false);
        await for (final chunk in file.openRead(
          offset,
          offset + sizeOf(number),
        )) {
          builder.add(chunk);
        }
        final part = builder.takeBytes();
        try {
          upload.parts[number] = await retry.run(() async {
            inFlight[number] = 0;
            final response = await _send(
              'PUT',
              key,
              query: {'partNumber': '$number', 'uploadId': upload.uploadId},
              body: part,
              control: control,
              onSent: (sent) {
                inFlight[number] = sent;
                report();
              },
            );
            await _expectOk(response, control: control);
            return _etagOf(response);
          }, control: control);
        } finally {
          inFlight.remove(number);
        }
        stored += part.length;
        report();
        final note = upload.toJson();
        noting = noting.then((_) => journal?.write(journalId, note));
      }

      Future<void> worker() async {
        try {
          while (pending.isNotEmpty && !failed) {
            await sendPart(pending.removeAt(0));
          }
        } on Object {
          // The other workers finish the part they are sending, then stop.
          failed = true;
          rethrow;
        }
      }

      try {
        await Future.wait([
          for (var i = 0; i < min(partConcurrency, pending.length); i++)
            worker(),
        ]);
      } finally {
        // Every stored part noted, even when another one failed.
        await noting;
      }
      final manifest = StringBuffer('<CompleteMultipartUpload>');
      for (var number = 1; number <= count; number++) {
        manifest.write(
          '<Part><PartNumber>$number</PartNumber>'
          '<ETag>${const HtmlEscape().convert(upload.parts[number]!)}'
          '</ETag></Part>',
        );
      }
      manifest.write('</CompleteMultipartUpload>');
      // Not retried: a completion sent twice fails with NoSuchUpload.
      final completed = await _send(
        'POST',
        key,
        query: {'uploadId': upload.uploadId},
        body: utf8.encode(manifest.toString()),
        control: control,
      );
      final body = parseSafeXml(await _expectOk(completed, control: control));
      // S3 may answer 200 with an <Error> body when completion fails late.
      if (body.localName == 'Error') {
        throw const BlobTransientFailure('Assemblage de l’envoi refusé.');
      }
      await journal?.delete(journalId);
      final etag = body.descendants('ETag').firstOrNull?.text ?? '';
      return (key: key, bytes: length, etag: etag);
    } on Object catch (error) {
      final resumable =
          journal != null &&
          (error is BlobTransientFailure || error is BlobTransferCancelled);
      if (!resumable) {
        try {
          await (await _send(
            'DELETE',
            key,
            query: {'uploadId': upload.uploadId},
          )).drain<void>();
        } on Object {
          // The bucket drops abandoned uploads on its own; the first error
          // is the one worth reporting.
        }
        await journal?.delete(journalId);
      }
      rethrow;
    }
  }

  /// The noted upload for [journalId], or null when there is none or it
  /// was cut in parts of another size.
  Future<_Upload?> _readUpload(String journalId) async {
    final note = await journal?.read(journalId);
    if (note == null) return null;
    final upload = _Upload.fromJson(note);
    if (upload == null || upload.partBytes != partBytes) {
      await journal?.delete(journalId);
      return null;
    }
    return upload;
  }

  @override
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(
    String key, {
    TransferControl? control,
  }) async {
    checkBlobKey(key);
    return retry.run(() async {
      final response = await _send('GET', key, control: control);
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return null;
      }
      final bytes = await _expectOk(response, control: control);
      return (
        bytes: bytes,
        info: (key: key, bytes: bytes.length, etag: _etagOf(response)),
      );
    }, control: control);
  }

  @override
  Future<BlobInfo?> download(
    String key,
    File target, {
    TransferControl? control,
    String? expectedSha256,
  }) async {
    checkBlobKey(key);
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    final journalId = _journalId(['get', key, target.absolute.path]);
    final note = await journal?.read(journalId);
    // The version the bytes in [partial] belong to; without it they are
    // leftovers of unknown origin.
    var etag = note?['etag'] is String ? note!['etag'] as String : null;
    if (etag == null) await _deleteQuietly(partial);
    try {
      final got = await retry.run(() async {
        final have = etag != null && await partial.exists()
            ? await partial.length()
            : 0;
        final response = await _send(
          'GET',
          key,
          headers: {
            if (have > 0) 'range': 'bytes=$have-',
            if (have > 0) 'if-match': etag!,
          },
          control: control,
        );
        final status = response.statusCode;
        if (status == HttpStatus.notFound) {
          await response.drain<void>();
          return null;
        }
        if (have > 0 &&
            (status == HttpStatus.preconditionFailed ||
                status == HttpStatus.requestedRangeNotSatisfiable)) {
          // Changed since, or already whole: fetch it again from the start.
          await response.drain<void>();
          await _deleteQuietly(partial);
          etag = null;
          throw const BlobTransientFailure('Objet modifié, reprise à zéro.');
        }
        if (status != HttpStatus.ok && status != HttpStatus.partialContent) {
          await _expectOk(response, control: control);
        }
        final append = status == HttpStatus.partialContent;
        final start = append ? have : 0;
        final total = response.contentLength < 0
            ? -1
            : start + response.contentLength;
        if (!append) {
          etag = _etagOf(response);
          await journal?.write(journalId, {'etag': etag});
        }
        var bytes = start;
        final sink = partial.openWrite(
          mode: append ? FileMode.append : FileMode.write,
        );
        try {
          await for (final chunk in response) {
            control?.check();
            bytes += chunk.length;
            sink.add(chunk);
            control?.report(bytes, total);
          }
          await sink.flush();
        } on Object catch (error) {
          throw _failure(error, control);
        } finally {
          await sink.close();
        }
        return (bytes: bytes, etag: etag ?? '');
      }, control: control);
      if (got == null) {
        await _deleteQuietly(partial);
        await journal?.delete(journalId);
        return null;
      }
      // Checked on the whole file: a resumed download wrote it in pieces.
      if (expectedSha256 != null &&
          await sha256OfFile(partial) != expectedSha256) {
        throw BlobChecksumMismatch(key);
      }
      await partial.rename(target.path);
      await journal?.delete(journalId);
      return (key: key, bytes: got.bytes, etag: got.etag);
    } on Object catch (error) {
      final resumable =
          journal != null &&
          (error is BlobTransientFailure || error is BlobTransferCancelled);
      if (!resumable) {
        await _deleteQuietly(partial);
        await journal?.delete(journalId);
      }
      rethrow;
    }
  }

  @override
  Future<BlobInfo?> head(String key) async {
    checkBlobKey(key);
    return retry.run(() async {
      final response = await _send('HEAD', key);
      await response.drain<void>();
      if (response.statusCode == HttpStatus.notFound) return null;
      _checkStatus(response.statusCode, conditional: false);
      return (
        key: key,
        bytes: response.contentLength < 0 ? 0 : response.contentLength,
        etag: _etagOf(response),
      );
    });
  }

  @override
  Future<void> delete(String key) async {
    checkBlobKey(key);
    await retry.run(() async {
      final response = await _send('DELETE', key);
      if (response.statusCode == HttpStatus.notFound) {
        await response.drain<void>();
        return;
      }
      await _expectOk(response);
    });
  }

  @override
  Stream<BlobInfo> list(String prefix) async* {
    String? token;
    do {
      final page = token;
      final root = await retry.run(() async {
        final response = await _send(
          'GET',
          null,
          query: {
            'list-type': '2',
            'prefix': prefix,
            'continuation-token': ?page,
          },
        );
        return parseSafeXml(await _expectOk(response));
      });
      for (final item in root.childrenNamed('Contents')) {
        yield (
          key: item.child('Key')?.text ?? '',
          bytes: int.tryParse(item.child('Size')?.text ?? '') ?? 0,
          etag: item.child('ETag')?.text ?? '',
        );
      }
      final truncated = root.child('IsTruncated')?.text == 'true';
      token = truncated ? root.child('NextContinuationToken')?.text : null;
    } while (token != null && token.isNotEmpty);
  }

  /// Sends one signed request for [key], or for the bucket itself when
  /// [key] is null. [onSent] hears how many bytes of [body] went out; a
  /// cancelled [control] aborts the request.
  Future<HttpClientResponse> _send(
    String method,
    String? key, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    List<int>? body,
    TransferControl? control,
    void Function(int sent)? onSent,
  }) async {
    control?.check();
    final basePath = config.endpoint.path.endsWith('/')
        ? config.endpoint.path.substring(0, config.endpoint.path.length - 1)
        : config.endpoint.path;
    final path = '$basePath/${config.bucket}${key == null ? '' : '/$key'}';
    final payload = body ?? const <int>[];
    final payloadHash = payload.isEmpty
        ? emptyPayloadHash
        : sha256.convert(payload).toString();
    final host = config.endpoint.authority;
    final signed = _signer.sign(
      method: method,
      path: path,
      query: query,
      headers: {'host': host, ...headers},
      payloadHash: payloadHash,
      now: _clock(),
    );
    // Built by hand so the wire path is exactly the signed one.
    final queryText = canonicalQuery(query);
    final uri = Uri.parse(
      '${config.endpoint.scheme}://$host${canonicalPath(path)}'
      '${queryText.isEmpty ? '' : '?$queryText'}',
    );
    try {
      final request = await _client.openUrl(method, uri);
      // Stops a request still waiting for its answer; a download already
      // streaming stops at its next chunk.
      control?.whenCancelled.then((_) {
        try {
          request.abort(const BlobTransferCancelled());
        } on Object {
          // Already over.
        }
      });
      for (final entry in {...headers, ...signed}.entries) {
        request.headers.set(entry.key, entry.value, preserveHeaderCase: true);
      }
      request.contentLength = payload.length;
      for (var offset = 0; offset < payload.length; offset += _sendSlice) {
        final end = min(offset + _sendSlice, payload.length);
        request.add(payload.sublist(offset, end));
        await request.flush();
        onSent?.call(end);
      }
      return await request.close();
    } on Object catch (error) {
      throw _failure(error, control);
    }
  }

  /// The body of a 2xx [response]; throws for any other status.
  Future<Uint8List> _expectOk(
    HttpClientResponse response, {
    bool conditional = false,
    TransferControl? control,
  }) async {
    final Uint8List bytes;
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } on Object catch (error) {
      throw _failure(error, control);
    }
    _checkStatus(response.statusCode, conditional: conditional, body: bytes);
    return bytes;
  }

  void _checkStatus(int status, {required bool conditional, Uint8List? body}) {
    if (status >= 200 && status < 300) return;
    if (status == HttpStatus.preconditionFailed ||
        (conditional && status == HttpStatus.conflict)) {
      throw const BlobPreconditionFailed();
    }
    final code = _errorCode(body);
    if (status == HttpStatus.forbidden || status == HttpStatus.unauthorized) {
      throw BlobAccessDenied(switch (code) {
        'SignatureDoesNotMatch' => 'Clé secrète refusée par le stockage.',
        'InvalidAccessKeyId' => 'Identifiant de clé inconnu du stockage.',
        _ => const BlobAccessDenied().message,
      });
    }
    if (status == HttpStatus.notFound && code == 'NoSuchBucket') {
      throw BlobAccessDenied('Bucket « ${config.bucket} » introuvable.');
    }
    if (status == HttpStatus.notFound && code == 'NoSuchUpload') {
      throw const _UploadGone();
    }
    throw BlobTransientFailure(
      'Le stockage a répondu $status${code == null ? '' : ' ($code)'}.',
    );
  }

  static String? _errorCode(Uint8List? body) {
    if (body == null || body.isEmpty) return null;
    try {
      return parseSafeXml(body).child('Code')?.text;
    } on SafeXmlException {
      return null;
    }
  }

  static String _etagOf(HttpClientResponse response) =>
      response.headers.value(HttpHeaders.etagHeader) ?? '';

  /// An id for the journal note of one transfer on this bucket.
  String _journalId(List<String> parts) => sha256
      .convert(
        utf8.encode(
          [config.endpoint.toString(), config.bucket, ...parts].join('\n'),
        ),
      )
      .toString();

  /// [error] as a store failure: cancelled when [control] was, else as it
  /// is when already one, else transient.
  static Object _failure(Object error, TransferControl? control) {
    if (control?.isCancelled ?? false) return const BlobTransferCancelled();
    return switch (error) {
      BlobStoreException() || _UploadGone() => error,
      SocketException() || TimeoutException() || HandshakeException() =>
        const BlobTransientFailure('Stockage injoignable.'),
      _ => BlobTransientFailure('Échange interrompu : $error'),
    };
  }

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}

/// A multipart upload under way: its id, the part size it was cut in and
/// the tag of each part already stored, by part number.
class _Upload {
  _Upload(this.uploadId, this.partBytes, this.parts);

  final String uploadId;
  final int partBytes;
  final Map<int, String> parts;

  static _Upload? fromJson(Map<String, Object?> json) {
    final uploadId = json['uploadId'];
    final partBytes = json['partBytes'];
    final parts = json['parts'];
    if (uploadId is! String || partBytes is! int || parts is! Map) return null;
    final read = <int, String>{};
    for (final entry in parts.entries) {
      final number = int.tryParse('${entry.key}');
      final etag = entry.value;
      if (number == null || etag is! String) return null;
      read[number] = etag;
    }
    return _Upload(uploadId, partBytes, read);
  }

  Map<String, Object?> toJson() => {
    'uploadId': uploadId,
    'partBytes': partBytes,
    'parts': {for (final entry in parts.entries) '${entry.key}': entry.value},
  };
}

/// The bucket no longer knows the multipart upload.
class _UploadGone implements Exception {
  const _UploadGone();
}
