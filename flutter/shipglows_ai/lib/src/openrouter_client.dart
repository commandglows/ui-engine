import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'ai_exception.dart';
import 'ai_models.dart';
import 'openrouter_key_store.dart';

/// Talks to OpenRouter (`https://openrouter.ai/api/v1`) with the user's key.
///
/// [appTitle] and [appUrl] name the app on OpenRouter's dashboards
/// (`X-Title`, `HTTP-Referer`). The key is read from [keyStore] before each
/// request and never logged. Failures are [AiException]s; nothing is retried
/// here, the caller decides with [AiException.retryable].
///
/// [activity] reports the start and end of each call, for a UI that has no
/// window of its own to show progress in.
class OpenRouterClient {
  OpenRouterClient({
    required this.keyStore,
    required this.appTitle,
    this.appUrl,
    http.Client? httpClient,
    Uri? baseUrl,
    this.timeout = const Duration(seconds: 60),
  }) : _http = httpClient ?? http.Client(),
       _ownsHttp = httpClient == null,
       baseUrl = baseUrl ?? Uri.parse('https://openrouter.ai/api/v1/');

  final OpenRouterKeyStore keyStore;
  final String appTitle;
  final String? appUrl;
  final Uri baseUrl;

  /// Wait for the answer of [complete], [models] and [checkKey]; for
  /// [stream], wait for the first byte.
  final Duration timeout;

  final http.Client _http;
  final bool _ownsHttp;

  final _activity = StreamController<AiActivity>.broadcast();
  int _sequence = 0;

  /// Start and end of each call. Each call emits [AiWorking], then exactly one
  /// [AiDone] or [AiFailed] with the same id; a stream cancelled by its
  /// listener emits no end event. An unexpected error (not an [AiException])
  /// is reported as [AiFailed] with an [AiBadResponse], then rethrown as it
  /// is. A broadcast stream: an event emitted while nobody listens is lost.
  Stream<AiActivity> get activity => _activity.stream;

  /// One full answer.
  Future<AiCompletion> complete(AiRequest request) async {
    final id = _begin();
    try {
      final response = await _send(
        'POST',
        'chat/completions',
        body: request.toJson(),
        requireKey: true,
      );
      final json = _decodeObject(response.body, response.statusCode);
      _throwIfErrorBody(json, response.statusCode);
      final choices = json['choices'];
      if (choices is! List || choices.isEmpty) {
        throw AiBadResponse(statusCode: response.statusCode);
      }
      final choice = choices.first;
      final message = choice is Map<String, Object?> ? choice['message'] : null;
      final content = message is Map<String, Object?>
          ? message['content']
          : null;
      final completion = AiCompletion(
        text: content is String ? content : '',
        model: json['model'] as String? ?? request.model,
        finishReason: choice is Map<String, Object?>
            ? choice['finish_reason'] as String?
            : null,
        usage: AiUsage.fromJson(json['usage']),
        id: json['id'] as String?,
      );
      _emit(AiDone(id, truncated: completion.truncated));
      return completion;
    } on AiException catch (error) {
      _emit(AiFailed(id, error));
      rethrow;
    } catch (error, stack) {
      _emit(AiFailed(id, const AiBadResponse()));
      Error.throwWithStackTrace(error, stack);
    }
  }

  /// One instruction applied to [text]; returns the answer, trimmed. [route]
  /// and [context] apply to this call only. [model] is the default model,
  /// which [route] can replace. Goes through [complete], so [activity]
  /// reports it.
  Future<String> transformText({
    required String model,
    required String text,
    required String instruction,
    AiRoute? route,
    AiContext? context,
  }) async {
    final base = AiRequest.transform(
      model: model,
      instruction: instruction,
      text: text,
      context: context,
    );
    final request = route == null ? base : base.withRoute(route);
    final completion = await complete(request);
    return completion.text.trim();
  }

  /// The answer piece by piece, as the model writes it. Cancelling the
  /// subscription closes the connection.
  Stream<String> stream(AiRequest request) async* {
    final id = _begin();
    var truncated = false;
    try {
      final key = await _key();
      final httpRequest = http.Request(
        'POST',
        baseUrl.resolve('chat/completions'),
      )
        ..headers.addAll(_headers(key, accept: 'text/event-stream'))
        ..body = jsonEncode(request.toJson(stream: true));
      final http.StreamedResponse response;
      try {
        response = await _http.send(httpRequest).timeout(timeout);
      } on TimeoutException {
        throw const AiTimeout();
      } on http.ClientException catch (error) {
        throw AiNetworkFailure(providerMessage: error.message);
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final body = await response.stream.bytesToString();
        throw _errorFor(response.statusCode, body, response.headers);
      }
      final lines = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter());
      try {
        await for (final line in lines) {
          // `: OPENROUTER PROCESSING` keeps the connection alive.
          if (!line.startsWith('data:')) continue;
          final data = line.substring(5).trim();
          if (data == '[DONE]') break;
          final json = _decodeObject(data, 200);
          _throwIfErrorBody(json, 200);
          final choices = json['choices'];
          if (choices is! List || choices.isEmpty) continue;
          final choice = choices.first;
          final finish = choice is Map<String, Object?>
              ? choice['finish_reason']
              : null;
          if (finish is String) truncated = finish == 'length';
          final delta = choice is Map<String, Object?> ? choice['delta'] : null;
          final content = delta is Map<String, Object?>
              ? delta['content']
              : null;
          if (content is String && content.isNotEmpty) yield content;
        }
      } on http.ClientException catch (error) {
        throw AiNetworkFailure(providerMessage: error.message);
      }
      _emit(AiDone(id, truncated: truncated));
    } on AiException catch (error) {
      _emit(AiFailed(id, error));
      rethrow;
    } catch (error, stack) {
      _emit(AiFailed(id, const AiBadResponse()));
      Error.throwWithStackTrace(error, stack);
    }
  }

  /// The model catalogue. Needs no key.
  Future<List<AiModel>> models() async {
    final response = await _send('GET', 'models', requireKey: false);
    final json = _decodeObject(response.body, response.statusCode);
    final data = json['data'];
    if (data is! List) throw AiBadResponse(statusCode: response.statusCode);
    return [
      for (final entry in data) ?AiModel.fromJson(entry),
    ];
  }

  /// Checks the stored key; throws [AiMissingKey] or [AiInvalidKey] when
  /// it cannot be used.
  Future<OpenRouterKeyInfo> checkKey() async {
    final response = await _send('GET', 'key', requireKey: true);
    return OpenRouterKeyInfo.fromJson(
      _decodeObject(response.body, response.statusCode),
    );
  }

  /// Closes the HTTP client this instance created; one given to it stays
  /// open. Ends [activity].
  void close() {
    if (_ownsHttp) _http.close();
    unawaited(_activity.close());
  }

  /// Starts a call: gives it an id and reports [AiWorking].
  String _begin() {
    final id = '${++_sequence}';
    _emit(AiWorking(id));
    return id;
  }

  void _emit(AiActivity event) {
    if (!_activity.isClosed) _activity.add(event);
  }

  Future<String> _key() async {
    final key = await keyStore.read();
    if (key == null || key.trim().isEmpty) throw const AiMissingKey();
    return key.trim();
  }

  Map<String, String> _headers(
    String? key, {
    String accept = 'application/json',
  }) {
    final authorization = key == null ? null : 'Bearer $key';
    return {
      'Content-Type': 'application/json',
      'Accept': accept,
      'X-Title': appTitle,
      'HTTP-Referer': ?appUrl,
      'Authorization': ?authorization,
    };
  }

  Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    required bool requireKey,
  }) async {
    final key = requireKey ? await _key() : null;
    final request = http.Request(method, baseUrl.resolve(path))
      ..headers.addAll(_headers(key));
    if (body != null) request.body = jsonEncode(body);
    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _http.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const AiTimeout();
    } on http.ClientException catch (error) {
      throw AiNetworkFailure(providerMessage: error.message);
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response;
    }
    throw _errorFor(response.statusCode, response.body, response.headers);
  }

  static Map<String, Object?> _decodeObject(String body, int statusCode) {
    try {
      final json = jsonDecode(body);
      if (json is Map<String, Object?>) return json;
    } on FormatException {
      // Falls through to the error below.
    }
    throw AiBadResponse(statusCode: statusCode);
  }

  /// OpenRouter can answer 200 with `{"error": …}` (and does so in the
  /// middle of a stream when the provider fails).
  static void _throwIfErrorBody(Map<String, Object?> json, int statusCode) {
    final error = json['error'];
    if (error is! Map<String, Object?>) return;
    // `code` is a number, or a string such as `server_error` in a stream.
    final raw = error['code'];
    final code = raw is num ? raw.toInt() : null;
    final message = error['message'];
    throw _errorForCode(
      code == null || code < 400 ? 502 : code,
      message is String ? message : null,
      null,
    );
  }

  static AiException _errorFor(
    int statusCode,
    String body,
    Map<String, String> headers,
  ) {
    String? message;
    try {
      final json = jsonDecode(body);
      final error = json is Map<String, Object?> ? json['error'] : null;
      if (error is Map<String, Object?>) message = error['message'] as String?;
    } on FormatException {
      // Not JSON: no provider message.
    }
    return _errorForCode(statusCode, message, headers['retry-after']);
  }

  static AiException _errorForCode(
    int statusCode,
    String? message,
    String? retryAfter,
  ) {
    return switch (statusCode) {
      401 => AiInvalidKey(providerMessage: message),
      402 => AiInsufficientCredits(providerMessage: message),
      403 => AiRefused(providerMessage: message),
      429 => AiRateLimited(
        providerMessage: message,
        retryAfter: switch (int.tryParse(retryAfter ?? '')) {
          final seconds? => Duration(seconds: seconds),
          null => null,
        },
      ),
      408 || >= 500 => AiProviderUnavailable(
        statusCode: statusCode,
        providerMessage: message,
      ),
      _ => AiBadRequest(statusCode: statusCode, providerMessage: message),
    };
  }
}
