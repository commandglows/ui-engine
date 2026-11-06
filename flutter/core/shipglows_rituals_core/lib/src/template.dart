import 'period.dart';

/// The response shape expected from a ritual prompt.
enum RitualPromptType {
  text,
  check,
  singleChoice,
  multipleChoice,
  number,
  scale,
}

/// A stable, host-independent choice offered by a prompt.
class RitualOption {
  const RitualOption({required this.id, required this.label});

  final String id, label;

  Map<String, dynamic> toJson() => {'id': id, 'label': label};

  static RitualOption? read(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty ||
        raw['label'] is! String ||
        (raw['label'] as String).trim().isEmpty) {
      return null;
    }
    return RitualOption(id: raw['id'] as String, label: raw['label'] as String);
  }
}

/// A declarative comparison against an earlier prompt's response.
/// Exactly one of [equals] or [contains] must be supplied.
class RitualCondition {
  const RitualCondition({required this.promptId, this.equals, this.contains});

  final String promptId;
  final Object? equals;
  final String? contains;

  Map<String, dynamic> toJson() => {
    'promptId': promptId,
    if (equals != null) 'equals': equals,
    if (contains != null) 'contains': contains,
  };

  static RitualCondition? read(Object? raw) {
    if (raw is! Map ||
        raw['promptId'] is! String ||
        (raw['promptId'] as String).trim().isEmpty ||
        (raw.containsKey('equals') == raw.containsKey('contains')) ||
        (raw.containsKey('contains') && raw['contains'] is! String)) {
      return null;
    }
    return RitualCondition(
      promptId: raw['promptId'] as String,
      equals: raw['equals'],
      contains: raw['contains'] as String?,
    );
  }
}

/// A reusable question or checklist item. Sessions keep their own snapshot.
class RitualPrompt {
  const RitualPrompt(
    this.id,
    this.label, {
    bool check = false,
    this.type,
    this.options = const [],
    this.showWhen,
    this.minimum,
    this.maximum,
    this.step,
  }) : _legacyCheck = check;

  final String id, label;
  final bool _legacyCheck;
  final RitualPromptType? type;
  final List<RitualOption> options;
  final RitualCondition? showWhen;
  final num? minimum, maximum, step;

  /// Kept for source compatibility with v1 callers.
  bool get check =>
      type == null ? _legacyCheck : type == RitualPromptType.check;

  RitualPromptType get responseType =>
      type ?? (_legacyCheck ? RitualPromptType.check : RitualPromptType.text);

  bool get hasRichMetadata =>
      type != null ||
      options.isNotEmpty ||
      showWhen != null ||
      minimum != null ||
      maximum != null ||
      step != null;

  Map<String, dynamic> toJson({bool rich = false}) => {
    'id': id,
    'label': label,
    if (rich) 'type': _typeName(responseType),
    'check': check,
    if (rich && options.isNotEmpty)
      'options': options.map((option) => option.toJson()).toList(),
    if (rich && showWhen != null) 'showWhen': showWhen!.toJson(),
    if (rich && minimum != null) 'minimum': minimum,
    if (rich && maximum != null) 'maximum': maximum,
    if (rich && step != null) 'step': step,
  };

  static RitualPrompt? read(Object? raw, {bool rich = false}) {
    if (raw is! Map ||
        raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty ||
        raw['label'] is! String ||
        (raw['label'] as String).trim().isEmpty) {
      return null;
    }
    RitualPromptType? type;
    if (rich) {
      type = _readType(raw['type']);
      if (type == null || raw['check'] != (type == RitualPromptType.check)) {
        return null;
      }
    } else if (raw['check'] is! bool) {
      return null;
    }

    final options = <RitualOption>[];
    final rawOptions = raw['options'];
    if (rich && raw.containsKey('options')) {
      if (rawOptions is! List) return null;
      final ids = <String>{};
      for (final item in rawOptions) {
        final option = RitualOption.read(item);
        if (option == null || !ids.add(option.id)) return null;
        options.add(option);
      }
    } else if (!rich &&
        (raw.containsKey('type') || raw.containsKey('options'))) {
      return null;
    }

    final condition = rich && raw.containsKey('showWhen')
        ? RitualCondition.read(raw['showWhen'])
        : null;
    if ((rich && raw.containsKey('showWhen') && condition == null) ||
        (!rich && raw.containsKey('showWhen'))) {
      return null;
    }
    final minimum = raw['minimum'];
    final maximum = raw['maximum'];
    final step = raw['step'];
    if ((raw.containsKey('minimum') && minimum is! num) ||
        (raw.containsKey('maximum') && maximum is! num) ||
        (raw.containsKey('step') && step is! num) ||
        (rich &&
            (minimum is double && !minimum.isFinite ||
                maximum is double && !maximum.isFinite ||
                step is double && !step.isFinite)) ||
        (!rich &&
            (raw.containsKey('minimum') ||
                raw.containsKey('maximum') ||
                raw.containsKey('step')))) {
      return null;
    }

    final prompt = RitualPrompt(
      raw['id'] as String,
      raw['label'] as String,
      check: rich ? type == RitualPromptType.check : raw['check'] as bool,
      type: rich ? type : null,
      options: options,
      showWhen: condition,
      minimum: minimum as num?,
      maximum: maximum as num?,
      step: step as num?,
    );
    if (!_validPromptShape(prompt)) return null;
    return prompt;
  }
}

bool _validPromptShape(RitualPrompt prompt) {
  final type = prompt.responseType;
  final choices =
      type == RitualPromptType.singleChoice ||
      type == RitualPromptType.multipleChoice;
  if (choices != prompt.options.isNotEmpty) return false;
  final numeric =
      type == RitualPromptType.number || type == RitualPromptType.scale;
  if (!numeric &&
      (prompt.minimum != null ||
          prompt.maximum != null ||
          prompt.step != null)) {
    return false;
  }
  if (numeric &&
      ((prompt.minimum != null && !prompt.minimum!.isFinite) ||
          (prompt.maximum != null && !prompt.maximum!.isFinite) ||
          (prompt.minimum != null &&
              prompt.maximum != null &&
              prompt.minimum! > prompt.maximum!) ||
          (prompt.step != null &&
              (!prompt.step!.isFinite || prompt.step! <= 0)))) {
    return false;
  }
  if (type == RitualPromptType.scale &&
      (prompt.minimum == null ||
          prompt.maximum == null ||
          prompt.step == null)) {
    return false;
  }
  if (type == RitualPromptType.scale &&
      !((prompt.maximum! - prompt.minimum!) / prompt.step!).isFinite) {
    return false;
  }
  return true;
}

String _typeName(RitualPromptType type) => switch (type) {
  RitualPromptType.text => 'text',
  RitualPromptType.check => 'check',
  RitualPromptType.singleChoice => 'singleChoice',
  RitualPromptType.multipleChoice => 'multipleChoice',
  RitualPromptType.number => 'number',
  RitualPromptType.scale => 'scale',
};

RitualPromptType? _readType(Object? value) => switch (value) {
  'text' => RitualPromptType.text,
  'check' => RitualPromptType.check,
  'singleChoice' => RitualPromptType.singleChoice,
  'multipleChoice' => RitualPromptType.multipleChoice,
  'number' => RitualPromptType.number,
  'scale' => RitualPromptType.scale,
  _ => null,
};

/// The period is calculated in the civil calendar provided by the host.
DateTime ritualPeriod(RitualTemplate template, DateTime date) => template.weekly
    ? addRitualDays(date, -(date.weekday - DateTime.monday))
    : DateTime(date.year, date.month, date.day);

/// Product templates and personal copies share this portable contract.
class RitualTemplate {
  const RitualTemplate({
    required this.id,
    required this.title,
    required this.weekly,
    required this.prompts,
    this.description = '',
  });

  final String id, title, description;
  final bool weekly;
  final List<RitualPrompt> prompts;

  bool get hasRichMetadata => prompts.any((prompt) => prompt.hasRichMetadata);

  Map<String, dynamic> toJson() => {
    'version': hasRichMetadata ? 2 : 1,
    'id': id,
    'title': title,
    'description': description,
    'cadence': weekly ? 'weekly' : 'daily',
    'prompts': prompts
        .map((prompt) => prompt.toJson(rich: hasRichMetadata))
        .toList(),
  };

  static RitualTemplate? read(Object? raw) {
    if (raw is! Map ||
        (raw['version'] != 1 && raw['version'] != 2) ||
        raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty ||
        raw['title'] is! String ||
        (raw['title'] as String).trim().isEmpty ||
        raw['description'] is! String ||
        !const {'daily', 'weekly'}.contains(raw['cadence']) ||
        raw['prompts'] is! List) {
      return null;
    }
    final rich = raw['version'] == 2;
    final prompts = <RitualPrompt>[];
    final ids = <String>{};
    for (final item in raw['prompts'] as List) {
      final prompt = RitualPrompt.read(item, rich: rich);
      if (prompt == null || !ids.add(prompt.id)) return null;
      prompts.add(prompt);
    }
    if (prompts.isEmpty || prompts.length > 40) return null;

    final prior = <String, RitualPrompt>{};
    for (final prompt in prompts) {
      final condition = prompt.showWhen;
      if (condition != null) {
        final source = prior[condition.promptId];
        if (source == null || !_validCondition(source, condition)) return null;
      }
      prior[prompt.id] = prompt;
    }
    return RitualTemplate(
      id: raw['id'] as String,
      title: raw['title'] as String,
      description: raw['description'] as String,
      weekly: raw['cadence'] == 'weekly',
      prompts: prompts,
    );
  }
}

bool _validCondition(RitualPrompt source, RitualCondition condition) {
  final hasEquals = condition.equals != null;
  final hasContains = condition.contains != null;
  if (hasEquals == hasContains) return false;
  final value = condition.equals;
  return switch (source.responseType) {
    RitualPromptType.text => hasEquals && value is String,
    RitualPromptType.check => hasEquals && value is bool,
    RitualPromptType.number || RitualPromptType.scale =>
      hasEquals &&
          value is num &&
          (value is! double || value.isFinite) &&
          (source.minimum == null || value >= source.minimum!) &&
          (source.maximum == null || value <= source.maximum!) &&
          (source.step == null ||
              _onStep(value, source.minimum ?? 0, source.step!)),
    RitualPromptType.singleChoice =>
      hasEquals &&
          value is String &&
          source.options.any((option) => option.id == value),
    RitualPromptType.multipleChoice =>
      hasContains &&
          source.options.any((option) => option.id == condition.contains),
  };
}

bool _onStep(num value, num origin, num step) {
  final increments = (value - origin) / step;
  return increments.isFinite && (increments - increments.round()).abs() <= 1e-9;
}
