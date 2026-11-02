import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'convex_exception.dart';
import 'network_error.dart';

/// Client identifier sent in the `Convex-Client` header.
const _clientId = 'shipglows-dart-0.1.0';

/// Auth failures Convex reports as a function error message.
final _authFailure = RegExp(
  r'unauthenticated|not authenticated',
  caseSensitive: false,
);

/// Calls a Convex deployment over its HTTP API with a bearer token.
///
/// [token] runs before each call and returns the token the deployment accepts
/// (for a Clerk OIDC audience, `ClerkAuthClient.idToken`), or `null` when signed out. A
/// call that fails as `unauthenticated` is retried once, after [token] runs
/// again, so an expired token refreshes by itself.
///
/// Arguments and results are plain JSON: `null`, bool, string, finite number,
/// list, and map with string keys. Not supported:
/// - `int` beyond 2^53: sent as a JSON number, which Convex reads as a float.
///   Timestamps go through `dateTimeToConvexMillis`, which stays in range.
/// - `Uint8List`: sent as a JSON array, not as Convex bytes. Use [uploadBytes]
///   and pass the storage id.
/// - `DateTime`, `NaN` and infinities: rejected with an [ArgumentError].
/// - Map keys starting with `$`: reserved by Convex.
///
/// Convex's special encodings (`$integer`, `$bytes`, `$float`) are not decoded
/// in results. Log lines are not printed, and realtime subscriptions and
/// pagination cursors are not supported.
class ConvexHttpClient {
  ConvexHttpClient({
    required this.deploymentUrl,
    required Future<String?> Function() token,
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _token = token,
       _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null;

  /// The deployment address, for example `https://<name>.convex.cloud`.
  final Uri deploymentUrl;

  /// Applies to each HTTP request, the upload included.
  final Duration timeout;

  final Future<String?> Function() _token;
  final http.Client _http;
  final bool _ownsHttp;

  /// Runs the query [path] (`module:function`) with [args].
  Future<Object?> query(
    String path, [
    Map<String, Object?> args = const {},
  ]) => _call('query', path, args);

  /// Runs the mutation [path] (`module:function`) with [args].
  Future<Object?> mutation(
    String path, [
    Map<String, Object?> args = const {},
  ]) => _call('mutation', path, args);

  /// Runs the action [path] (`module:function`) with [args].
  Future<Object?> action(
    String path, [
    Map<String, Object?> args = const {},
  ]) => _call('action', path, args);

  /// Calls the mutation [uploadUrlPath] (no args), which returns an upload
  /// URL. POSTs [bytes] to that URL with [contentType] and returns the
  /// storage id.
  Future<String> uploadBytes({
    required String uploadUrlPath,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final target = await mutation(uploadUrlPath);
    if (target is! String || target.isEmpty) {
      throw const ConvexException('bad_response', 'No upload URL.');
    }
    final Uri uri;
    try {
      uri = Uri.parse(target);
    } on FormatException {
      throw const ConvexException('bad_response', 'Invalid upload URL.');
    }
    // No bearer token: the upload URL is the authorization for this upload.
    final response = await _post(
      uri,
      headers: {'Content-Type': contentType},
      body: bytes,
    );
    if (response.statusCode < 200 || response.statusCode > 299) {
      throw ConvexException(
        'bad_response',
        'Upload failed with HTTP ${response.statusCode}.',
      );
    }
    final json = _decodeObject(response.body);
    final storageId = json?['storageId'];
    if (storageId is! String || storageId.isEmpty) {
      throw const ConvexException('bad_response', 'No storageId.');
    }
    return storageId;
  }

  /// Closes the HTTP client when this object created it. An injected client
  /// stays open, since its owner made it.
  void close() {
    if (_ownsHttp) {
      _http.close();
    }
  }

  Future<Object?> _call(
    String kind,
    String path,
    Map<String, Object?> args,
  ) async {
    final body = _requestBody(path, args);
    try {
      return await _send(kind, body);
    } on ConvexException catch (error) {
      if (error.code != 'unauthenticated') {
        rethrow;
      }
    }
    return _send(kind, body);
  }

  /// Same wire format as the official JS client (`convex_encoded_json`,
  /// args wrapped in a list). With plain JSON values the bytes are identical
  /// to a plain `json` body.
  static String _requestBody(String path, Map<String, Object?> args) {
    try {
      return jsonEncode({
        'path': path,
        'format': 'convex_encoded_json',
        'args': [args],
      });
    } on JsonUnsupportedObjectError {
      throw ArgumentError(
        'Convex arguments must be plain JSON: no DateTime, Uint8List, '
        'int beyond 2^53, NaN or infinity.',
      );
    }
  }

  Future<Object?> _send(String kind, String body) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Convex-Client': _clientId,
    };
    final token = await _token();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    final response = await _post(_endpoint(kind), headers: headers, body: body);
    final status = response.statusCode;
    if (status == 401 || status == 403) {
      throw ConvexException('unauthenticated', 'HTTP $status.');
    }
    // Convex answers a failed function with HTTP 560 and a JSON body.
    if (status != 200 && status != 560) {
      throw ConvexException('bad_response', 'HTTP $status.');
    }
    final json = _decodeObject(response.body);
    if (json == null) {
      throw const ConvexException('bad_response', 'Body is not a JSON object.');
    }
    switch (json['status']) {
      case 'success':
        if (!json.containsKey('value')) {
          throw const ConvexException('bad_response', 'No value.');
        }
        return json['value'];
      case 'error':
        throw _functionError(json);
      default:
        throw const ConvexException('bad_response', 'Unknown status.');
    }
  }

  /// Maps a failed function to a code. An app code in a `ConvexError` payload
  /// comes first, then auth messages, then the payload or a plain failure.
  static ConvexException _functionError(Map<String, dynamic> json) {
    final raw = json['errorMessage'];
    final message = raw is String ? raw : 'Convex function failed.';
    final data = json['errorData'];
    if (data is Map<String, dynamic> && data['code'] is String) {
      return ConvexException(data['code'] as String, message, data: data);
    }
    if (_authFailure.hasMatch(message)) {
      return ConvexException('unauthenticated', message);
    }
    if (data != null) {
      return ConvexException('convex_error', message, data: data);
    }
    return ConvexException('function_error', message);
  }

  Future<http.Response> _post(
    Uri uri, {
    required Map<String, String> headers,
    required Object body,
  }) async {
    try {
      return await _http
          .post(uri, headers: headers, body: body)
          .timeout(timeout);
    } on TimeoutException {
      throw ConvexException(
        'network',
        'Timed out after ${timeout.inSeconds} s.',
      );
    } on http.ClientException {
      throw const ConvexException('network', 'Request failed.');
    } catch (error) {
      if (isSocketFailure(error)) {
        throw const ConvexException('network', 'No connection.');
      }
      rethrow;
    }
  }

  Uri _endpoint(String kind) {
    final base = deploymentUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    return Uri.parse('$base/api/$kind');
  }

  static Map<String, dynamic>? _decodeObject(String body) {
    try {
      final value = jsonDecode(body);
      return value is Map<String, dynamic> ? value : null;
    } on FormatException {
      return null;
    }
  }
}
