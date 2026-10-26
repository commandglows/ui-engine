import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A bucket named `bucket` on this computer that answers the S3 calls
/// [S3BlobStore] makes, without checking signatures, so uploads, downloads
/// and their resumes can be tested without MinIO.
class FakeS3Server {
  FakeS3Server._(this._server) {
    _server.listen(_handle);
  }

  static Future<FakeS3Server> start() async =>
      FakeS3Server._(await HttpServer.bind(InternetAddress.loopbackIPv4, 0));

  final HttpServer _server;

  /// Stored objects by key.
  final objects = <String, ({Uint8List bytes, String etag})>{};

  /// Multipart uploads under way: upload id to part number to bytes.
  final uploads = <String, Map<int, Uint8List>>{};

  /// Every call, as `METHOD key ?query`, such as `PUT big.bin ?partNumber=2`.
  final calls = <String>[];

  /// Answers a call itself when it returns true: to fail it, cut it short
  /// or cancel a transfer while it is under way.
  FutureOr<bool> Function(HttpRequest request, Uint8List body)? intercept;

  var _ids = 0;

  Uri get endpoint => Uri.parse('http://127.0.0.1:${_server.port}');

  Future<void> close() => _server.close(force: true);

  /// Sends the head of a 200 answer of [total] bytes, only [sent] of them,
  /// and drops the connection.
  static Future<void> cutShort(
    HttpRequest request,
    Uint8List bytes,
    int sent, {
    String etag = '',
  }) async {
    final socket = await request.response.detachSocket(writeHeaders: false);
    socket.add(utf8.encode('HTTP/1.1 200 OK\r\n'
        'content-length: ${bytes.length}\r\n'
        'etag: $etag\r\n\r\n'));
    socket.add(bytes.sublist(0, sent));
    await socket.flush();
    socket.destroy();
  }

  Future<void> _handle(HttpRequest request) async {
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in request) {
        builder.add(chunk);
      }
      final body = builder.takeBytes();
      final path = Uri.decodeFull(request.uri.path);
      final key = path.length > '/bucket/'.length
          ? path.substring('/bucket/'.length)
          : '';
      final query = request.uri.queryParameters;
      calls.add('${request.method} $key'
          '${request.uri.hasQuery ? ' ?${request.uri.query}' : ''}');
      if (await intercept?.call(request, body) ?? false) return;
      final response = request.response;
      switch (request.method) {
        case 'POST' when query.containsKey('uploads'):
          final id = 'u${++_ids}';
          uploads[id] = {};
          _xml(response, '<InitiateMultipartUploadResult>'
              '<UploadId>$id</UploadId></InitiateMultipartUploadResult>');
        case 'PUT' when query.containsKey('partNumber'):
          final parts = uploads[query['uploadId']];
          if (parts == null) return _error(response, 404, 'NoSuchUpload');
          parts[int.parse(query['partNumber']!)] = body;
          response.headers.set('etag', _etagOf(body));
          await response.close();
        case 'POST' when query.containsKey('uploadId'):
          final parts = uploads.remove(query['uploadId']);
          if (parts == null) return _error(response, 404, 'NoSuchUpload');
          final whole = BytesBuilder();
          for (final number in parts.keys.toList()..sort()) {
            whole.add(parts[number]!);
          }
          final etag = _store(key, whole.takeBytes());
          _xml(response, '<CompleteMultipartUploadResult>'
              '<ETag>${const HtmlEscape().convert(etag)}</ETag>'
              '</CompleteMultipartUploadResult>');
        case 'DELETE' when query.containsKey('uploadId'):
          uploads.remove(query['uploadId']);
          response.statusCode = 204;
          await response.close();
        case 'PUT':
          final current = objects[key];
          final ifNoneMatch = request.headers.value('if-none-match');
          final ifMatch = request.headers.value('if-match');
          if ((ifNoneMatch == '*' && current != null) ||
              (ifMatch != null && current?.etag != ifMatch)) {
            return _error(response, 412, 'PreconditionFailed');
          }
          response.headers.set('etag', _store(key, body));
          await response.close();
        case 'GET' when query.containsKey('list-type'):
          final prefix = query['prefix'] ?? '';
          final keys = objects.keys.where((k) => k.startsWith(prefix)).toList()
            ..sort();
          _xml(response, '<ListBucketResult>${[
            for (final k in keys)
              '<Contents><Key>$k</Key>'
                  '<Size>${objects[k]!.bytes.length}</Size>'
                  '<ETag>${const HtmlEscape().convert(objects[k]!.etag)}</ETag>'
                  '</Contents>',
          ].join()}<IsTruncated>false</IsTruncated></ListBucketResult>');
        case 'GET' || 'HEAD':
          final object = objects[key];
          if (object == null) return _error(response, 404, 'NoSuchKey');
          final ifMatch = request.headers.value('if-match');
          if (ifMatch != null && ifMatch != object.etag) {
            return _error(response, 412, 'PreconditionFailed');
          }
          var bytes = object.bytes;
          final range = request.headers.value('range');
          if (range != null) {
            final start = int.parse(
              RegExp(r'^bytes=(\d+)-$').firstMatch(range)!.group(1)!,
            );
            if (start >= bytes.length) {
              return _error(response, 416, 'InvalidRange');
            }
            bytes = bytes.sublist(start);
            response.statusCode = 206;
          }
          response.headers.set('etag', object.etag);
          response.contentLength = bytes.length;
          if (request.method == 'GET') response.add(bytes);
          await response.close();
        case 'DELETE':
          objects.remove(key);
          response.statusCode = 204;
          await response.close();
        default:
          return _error(response, 400, 'NotImplemented');
      }
    } on Object {
      // The client hung up (a cancelled transfer): nothing to answer.
    }
  }

  String _store(String key, Uint8List bytes) {
    final etag = _etagOf(bytes);
    objects[key] = (bytes: bytes, etag: etag);
    return etag;
  }

  static String _etagOf(Uint8List bytes) =>
      '"${md5.convert(bytes).toString()}"';

  static void _xml(HttpResponse response, String xml) {
    response.headers.contentType = ContentType('application', 'xml');
    response.write('<?xml version="1.0" encoding="UTF-8"?>$xml');
    response.close();
  }

  static Future<void> _error(HttpResponse response, int status, String code) {
    response.statusCode = status;
    response.write('<?xml version="1.0" encoding="UTF-8"?>'
        '<Error><Code>$code</Code></Error>');
    return response.close();
  }
}
