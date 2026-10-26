/// [BlobStore] on an S3-compatible bucket (Cloudflare R2, MinIO, AWS),
/// spoken to directly over HTTPS with SigV4-signed requests.
///
/// Objects are addressed path-style, `<endpoint>/<bucket>/<key>`, which R2
/// and MinIO both accept. Files over [S3BlobStore.multipartThreshold] go up
/// in parts so an upload of a long recording or video never holds it whole
/// in memory.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:shipglows_xml/shipglows_xml.dart';

import 'blob_store.dart';
import 'sigv4.dart';

/// Where a bucket is and how to sign for it. The keys live in secure
/// storage; this value only travels in memory.
typedef S3Config = ({
  Uri endpoint,
  String bucket,
  String region,
  AwsCredentials credentials,
});

class S3BlobStore implements BlobStore {
  S3BlobStore(this.config, {HttpClient? client, DateTime Function()? clock})
      : _client = client ??
            (HttpClient()..connectionTimeout = const Duration(seconds: 15)),
        _clock = clock ?? DateTime.now,
        _signer = SigV4Signer(
          credentials: config.credentials,
          region: config.region,
        );

  /// Size from which a file goes up in parts.
  static const multipartThreshold = 64 * 1024 * 1024;

  /// Size of each part but the last.
  static const partBytes = 16 * 1024 * 1024;

  final S3Config config;
  final HttpClient _client;
  final DateTime Function() _clock;
  final SigV4Signer _signer;

  /// Closes the connections; the store cannot be used afterwards.
  void close() => _client.close(force: true);

  @override
  Future<BlobInfo> putBytes(
    String key,
    Uint8List bytes, {
    WriteCondition condition = WriteCondition.always,
  }) async {
    checkBlobKey(key);
    final response = await _send(
      'PUT',
      key,
      body: bytes,
      headers: switch (condition) {
        AlwaysWrite() => const {},
        WriteIfAbsent() => const {'if-none-match': '*'},
        WriteIfMatch(:final etag) => {'if-match': etag},
      },
    );
    await _expectOk(response, conditional: condition is! AlwaysWrite);
    return (key: key, bytes: bytes.length, etag: _etagOf(response));
  }

  @override
  Future<BlobInfo> putFile(String key, File file) async {
    checkBlobKey(key);
    final length = await file.length();
    if (length <= multipartThreshold) {
      return putBytes(key, await file.readAsBytes());
    }
    return _putMultipart(key, file, length);
  }

  Future<BlobInfo> _putMultipart(String key, File file, int length) async {
    final created = await _send('POST', key, query: {'uploads': ''});
    final uploadId = parseSafeXml(await _expectOk(created))
        .descendants('UploadId')
        .firstOrNull
        ?.text;
    if (uploadId == null || uploadId.isEmpty) {
      throw const BlobTransientFailure('Réponse S3 sans identifiant d’envoi.');
    }
    try {
      final etags = <String>[];
      final handle = await file.open();
      try {
        for (var offset = 0; offset < length; offset += partBytes) {
          final part = await handle.read(partBytes);
          final response = await _send(
            'PUT',
            key,
            query: {
              'partNumber': '${etags.length + 1}',
              'uploadId': uploadId,
            },
            body: part,
          );
          await _expectOk(response);
          etags.add(_etagOf(response));
        }
      } finally {
        await handle.close();
      }
      final manifest = StringBuffer('<CompleteMultipartUpload>');
      for (final (index, etag) in etags.indexed) {
        manifest.write('<Part><PartNumber>${index + 1}</PartNumber>'
            '<ETag>${const HtmlEscape().convert(etag)}</ETag></Part>');
      }
      manifest.write('</CompleteMultipartUpload>');
      final done = await _send(
        'POST',
        key,
        query: {'uploadId': uploadId},
        body: utf8.encode(manifest.toString()),
      );
      final body = parseSafeXml(await _expectOk(done));
      // S3 may answer 200 with an <Error> body when completion fails late.
      if (body.localName == 'Error') {
        throw const BlobTransientFailure('Assemblage de l’envoi refusé.');
      }
      final etag = body.descendants('ETag').firstOrNull?.text ?? '';
      return (key: key, bytes: length, etag: etag);
    } catch (_) {
      try {
        await (await _send('DELETE', key, query: {'uploadId': uploadId}))
            .drain<void>();
      } on Object {
        // The bucket drops abandoned uploads on its own; the first error
        // is the one worth reporting.
      }
      rethrow;
    }
  }

  @override
  Future<({Uint8List bytes, BlobInfo info})?> getBytes(String key) async {
    checkBlobKey(key);
    final response = await _send('GET', key);
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    final bytes = await _expectOk(response);
    return (
      bytes: bytes,
      info: (key: key, bytes: bytes.length, etag: _etagOf(response)),
    );
  }

  @override
  Future<BlobInfo?> download(String key, File target) async {
    checkBlobKey(key);
    final response = await _send('GET', key);
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return null;
    }
    if (response.statusCode != HttpStatus.ok) {
      await _expectOk(response);
    }
    await target.parent.create(recursive: true);
    final partial = File('${target.path}.part');
    var bytes = 0;
    final sink = partial.openWrite();
    try {
      await for (final chunk in response) {
        bytes += chunk.length;
        sink.add(chunk);
      }
      await sink.flush();
    } on Object catch (error) {
      await sink.close();
      await _deleteQuietly(partial);
      throw _transient(error);
    }
    await sink.close();
    await partial.rename(target.path);
    return (key: key, bytes: bytes, etag: _etagOf(response));
  }

  @override
  Future<BlobInfo?> head(String key) async {
    checkBlobKey(key);
    final response = await _send('HEAD', key);
    await response.drain<void>();
    if (response.statusCode == HttpStatus.notFound) return null;
    _checkStatus(response.statusCode, conditional: false);
    return (
      key: key,
      bytes: response.contentLength < 0 ? 0 : response.contentLength,
      etag: _etagOf(response),
    );
  }

  @override
  Future<void> delete(String key) async {
    checkBlobKey(key);
    final response = await _send('DELETE', key);
    if (response.statusCode == HttpStatus.notFound) {
      await response.drain<void>();
      return;
    }
    await _expectOk(response);
  }

  @override
  Stream<BlobInfo> list(String prefix) async* {
    String? token;
    do {
      final response = await _send(
        'GET',
        null,
        query: {
          'list-type': '2',
          'prefix': prefix,
          if (token != null) 'continuation-token': token,
        },
      );
      final root = parseSafeXml(await _expectOk(response));
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
  /// [key] is null.
  Future<HttpClientResponse> _send(
    String method,
    String? key, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    List<int>? body,
  }) async {
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
      for (final entry in {...headers, ...signed}.entries) {
        request.headers.set(entry.key, entry.value, preserveHeaderCase: true);
      }
      request.contentLength = payload.length;
      if (payload.isNotEmpty) request.add(payload);
      return await request.close();
    } on Object catch (error) {
      throw _transient(error);
    }
  }

  /// The body of a 2xx [response]; throws for any other status.
  Future<Uint8List> _expectOk(
    HttpClientResponse response, {
    bool conditional = false,
  }) async {
    final Uint8List bytes;
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
    } on Object catch (error) {
      throw _transient(error);
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

  static BlobStoreException _transient(Object error) => switch (error) {
        BlobStoreException() => error,
        SocketException() || TimeoutException() || HandshakeException() =>
          const BlobTransientFailure('Stockage injoignable.'),
        _ => BlobTransientFailure('Échange interrompu : $error'),
      };

  static Future<void> _deleteQuietly(File file) async {
    try {
      await file.delete();
    } on FileSystemException {
      // Already gone.
    }
  }
}
