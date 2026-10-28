import 'ai_exception.dart';

/// Who speaks in a conversation.
enum AiRole { system, user, assistant }

/// One turn of the conversation sent to the model.
final class AiMessage {
  const AiMessage(this.role, this.content);

  const AiMessage.system(this.content) : role = AiRole.system;
  const AiMessage.user(this.content) : role = AiRole.user;
  const AiMessage.assistant(this.content) : role = AiRole.assistant;

  final AiRole role;
  final String content;

  Map<String, Object?> toJson() => {'role': role.name, 'content': content};

  @override
  bool operator ==(Object other) =>
      other is AiMessage && other.role == role && other.content == content;

  @override
  int get hashCode => Object.hash(role, content);
}

/// One request. [model] is an OpenRouter id such as
/// `anthropic/claude-haiku-5.5`; [fallbackModels] are tried in order when it
/// is down or refuses the request (OpenRouter `models`). The request keeps the
/// lists passed in [messages] and [fallbackModels] without copying them: do
/// not modify them after passing them.
final class AiRequest {
  const AiRequest({
    required this.model,
    required this.messages,
    this.fallbackModels = const [],
    this.temperature,
    this.maxTokens,
  });

  /// A single instruction applied to [text]: the usual shape of a text
  /// action (rewrite, translate, clean a dictation). A filled [context] goes
  /// first, as a system message before the instruction.
  factory AiRequest.transform({
    required String model,
    required String instruction,
    required String text,
    List<String> fallbackModels = const [],
    double? temperature,
    int? maxTokens,
    AiContext? context,
  }) => AiRequest(
    model: model,
    fallbackModels: fallbackModels,
    temperature: temperature,
    maxTokens: maxTokens,
    messages: [
      ?context?.toMessage(),
      AiMessage.system(instruction),
      AiMessage.user(text),
    ],
  );

  final String model;
  final List<AiMessage> messages;
  final List<String> fallbackModels;

  /// 0 to 2; null keeps the model's default.
  final double? temperature;

  /// Ceiling on the answer's length; null keeps the model's default.
  final int? maxTokens;

  Map<String, Object?> toJson({bool stream = false}) => {
    'model': model,
    if (fallbackModels.isNotEmpty) 'models': [model, ...fallbackModels],
    'messages': [for (final message in messages) message.toJson()],
    'temperature': ?temperature,
    'max_tokens': ?maxTokens,
    if (stream) 'stream': true,
  };

  /// What [toJson] would send, without calling OpenRouter or reading the key.
  AiPreview preview() => AiPreview(
    model: model,
    fallbackModels: List.unmodifiable(fallbackModels),
    messages: List.unmodifiable(messages),
  );

  /// Returns a NEW request with [route] applied: the model and the fallbacks
  /// are replaced when the route sets them, and the route's context message
  /// goes first, before the other system messages. The original request is
  /// never modified; the route only lives for one call.
  AiRequest withRoute(AiRoute route) => AiRequest(
    model: route.model ?? model,
    fallbackModels: route.fallbackModels ?? fallbackModels,
    temperature: temperature,
    maxTokens: maxTokens,
    messages: [?route.context?.toMessage(), ...messages],
  );
}

/// The messages a request would send, as returned by [AiRequest.preview].
/// Plain values for a confirmation screen; nothing is sent.
final class AiPreview {
  const AiPreview({
    required this.model,
    this.fallbackModels = const [],
    required this.messages,
  });

  final String model;
  final List<String> fallbackModels;
  final List<AiMessage> messages;

  @override
  String toString() => [
    'Model: $model',
    if (fallbackModels.isNotEmpty) 'Fallbacks: ${fallbackModels.join(', ')}',
    for (final message in messages) '${message.role.name}: ${message.content}',
  ].join('\n');
}

/// A temporary route for one call: another model, other fallbacks, or an
/// extra context. Applied with [AiRequest.withRoute]; a null field keeps the
/// value of the request.
final class AiRoute {
  const AiRoute({this.model, this.fallbackModels, this.context});

  final String? model;
  final List<String>? fallbackModels;
  final AiContext? context;
}

/// Who the text is for and how the answer should read, sent as one system
/// message. Blank fields count as absent.
final class AiContext {
  const AiContext({this.who, this.how});

  /// Who is speaking, or who the text is for, in plain words.
  final String? who;

  /// How the answer should read, e.g. "short and informal".
  final String? how;

  bool get isEmpty => _clean(who) == null && _clean(how) == null;

  /// The system message for this context, or null when [isEmpty]. The two
  /// parts are separated by a blank line.
  AiMessage? toMessage() {
    final whoText = _clean(who);
    final howText = _clean(how);
    if (whoText == null && howText == null) return null;
    return AiMessage.system(
      [
        ?whoText,
        if (howText != null) 'Response style: $howText',
      ].join('\n\n'),
    );
  }

  static String? _clean(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }
}

/// Tokens counted by OpenRouter for one answer; [cost] in credits (US
/// dollars) when it reports it.
final class AiUsage {
  const AiUsage({
    required this.promptTokens,
    required this.completionTokens,
    this.cost,
  });

  final int promptTokens;
  final int completionTokens;
  final double? cost;

  int get totalTokens => promptTokens + completionTokens;

  static AiUsage? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    return AiUsage(
      promptTokens: (json['prompt_tokens'] as num?)?.toInt() ?? 0,
      completionTokens: (json['completion_tokens'] as num?)?.toInt() ?? 0,
      cost: (json['cost'] as num?)?.toDouble(),
    );
  }
}

/// The answer. [model] is the one that actually answered (a fallback may
/// have taken over); [finishReason] is `stop`, `length`, `content_filter`…
final class AiCompletion {
  const AiCompletion({
    required this.text,
    required this.model,
    this.finishReason,
    this.usage,
    this.id,
  });

  final String text;
  final String model;
  final String? finishReason;
  final AiUsage? usage;

  /// OpenRouter's generation id, to look the cost up later.
  final String? id;

  /// True when the answer was cut by [AiRequest.maxTokens].
  bool get truncated => finishReason == 'length';
}

/// One entry of the model catalogue. Prices are US dollars per token.
final class AiModel {
  const AiModel({
    required this.id,
    required this.name,
    this.contextLength,
    this.promptPrice,
    this.completionPrice,
  });

  final String id;
  final String name;
  final int? contextLength;
  final double? promptPrice;
  final double? completionPrice;

  /// True for the `:free` variants and models priced at zero.
  bool get free =>
      id.endsWith(':free') || (promptPrice == 0 && completionPrice == 0);

  static AiModel? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final pricing = json['pricing'];
    double? price(String field) => pricing is Map<String, Object?>
        ? double.tryParse('${pricing[field]}')
        : null;
    return AiModel(
      id: id,
      name: json['name'] is String ? json['name']! as String : id,
      contextLength: (json['context_length'] as num?)?.toInt(),
      promptPrice: price('prompt'),
      completionPrice: price('completion'),
    );
  }
}

/// What OpenRouter says about the key in use (`GET /key`).
final class OpenRouterKeyInfo {
  const OpenRouterKeyInfo({
    this.label,
    this.limit,
    this.limitRemaining,
    this.usage,
    this.freeTier = false,
  });

  final String? label;

  /// Spending ceiling of the key in credits; null when it has none.
  final double? limit;

  /// Credits left under [limit]; null without a ceiling.
  final double? limitRemaining;

  /// Credits spent with this key.
  final double? usage;

  /// True when the account never bought credits.
  final bool freeTier;

  static OpenRouterKeyInfo fromJson(Map<String, Object?> json) {
    final data = json['data'] is Map<String, Object?>
        ? json['data']! as Map<String, Object?>
        : json;
    return OpenRouterKeyInfo(
      label: data['label'] as String?,
      limit: (data['limit'] as num?)?.toDouble(),
      limitRemaining: (data['limit_remaining'] as num?)?.toDouble(),
      usage: (data['usage'] as num?)?.toDouble(),
      freeTier: data['is_free_tier'] == true,
    );
  }
}

/// Lifecycle of one call ([OpenRouterClient.complete], `stream`,
/// `transformText`). Every call emits [AiWorking], then exactly one of
/// [AiDone] or [AiFailed], with the same [id]. A cancelled stream emits no
/// end event.
sealed class AiActivity {
  const AiActivity(this.id);

  /// Identifies one call; unique within the client.
  final String id;
}

/// The call has started.
final class AiWorking extends AiActivity {
  const AiWorking(super.id);
}

/// The call succeeded. [truncated] is true when the answer was cut by
/// [AiRequest.maxTokens].
final class AiDone extends AiActivity {
  const AiDone(super.id, {this.truncated = false});

  final bool truncated;
}

/// The call failed with [error]. For an expected failure the client rethrows
/// that same [AiException]; for an unexpected error it reports [AiBadResponse]
/// here and rethrows the original error.
final class AiFailed extends AiActivity {
  const AiFailed(super.id, this.error);

  final AiException error;
}
