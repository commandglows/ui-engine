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
/// is down or refuses the request (OpenRouter `models`).
final class AiRequest {
  const AiRequest({
    required this.model,
    required this.messages,
    this.fallbackModels = const [],
    this.temperature,
    this.maxTokens,
  });

  /// A single instruction applied to [text]: the usual shape of a text
  /// action (rewrite, translate, clean a dictation).
  factory AiRequest.transform({
    required String model,
    required String instruction,
    required String text,
    List<String> fallbackModels = const [],
    double? temperature,
    int? maxTokens,
  }) => AiRequest(
    model: model,
    fallbackModels: fallbackModels,
    temperature: temperature,
    maxTokens: maxTokens,
    messages: [AiMessage.system(instruction), AiMessage.user(text)],
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
