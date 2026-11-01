import 'period.dart';
import 'template.dart';

/// A host-owned item that a person can associate with a ritual page.
/// The package has no knowledge of goals, projects, health records or accounts.
class RitualReference {
  const RitualReference({required this.id, required this.label});
  final String id, label;
}

/// A page keeps its original questions and civil period across model edits.
/// [recordId] belongs to the host's store; reference IDs have meaning only there.
class RitualPage {
  const RitualPage({
    required this.template,
    required this.periodStart,
    this.recordId,
    this.answers = const {},
    this.checked = const {},
    this.referenceIds = const {},
    this.completed = false,
    this.values = const {},
  });

  final RitualTemplate template;
  final String periodStart;
  final String? recordId;

  /// Legacy text responses. Unknown text keys are preserved for old documents.
  final Map<String, String> answers;

  /// Legacy checklist state retained for v1 callers and documents.
  final Set<String> checked;
  final Set<String> referenceIds;
  final bool completed;

  /// New typed responses, keyed by prompt ID.
  final Map<String, Object?> values;

  /// The visible prompts in template order, using current page responses.
  List<RitualPrompt> get visiblePrompts =>
      template.prompts.where(isPromptVisible).toList(growable: false);

  /// Whether [prompt] is visible under its declarative prior-prompt condition.
  bool isPromptVisible(RitualPrompt prompt) =>
      _isPromptVisible(prompt, <String>{});

  bool _isPromptVisible(RitualPrompt prompt, Set<String> visiting) {
    final condition = prompt.showWhen;
    if (condition == null) return true;
    if (!visiting.add(prompt.id)) return false;
    RitualPrompt? source;
    for (final candidate in template.prompts) {
      if (candidate.id == condition.promptId) {
        source = candidate;
        break;
      }
    }
    if (source == null) return false;
    if (!_isPromptVisible(source, visiting)) return false;
    final response = _responseFor(source);
    if (response == null) return false;
    if (condition.contains != null) {
      return response is List && response.contains(condition.contains);
    }
    final expected = condition.equals;
    final step = source.step;
    if (response is num && expected is num && step != null) {
      final origin = source.minimum ?? 0;
      final actualTick = (response - origin) / step;
      final expectedTick = (expected - origin) / step;
      return actualTick.isFinite &&
          expectedTick.isFinite &&
          actualTick.round() == expectedTick.round();
    }
    return response == condition.equals;
  }

  /// Resolve by ID for renderers that hold prompt IDs rather than objects.
  bool isPromptIdVisible(String promptId) {
    for (final prompt in template.prompts) {
      if (prompt.id == promptId) return isPromptVisible(prompt);
    }
    return false;
  }

  Object? _responseFor(RitualPrompt prompt) {
    if (values.containsKey(prompt.id)) return values[prompt.id];
    return switch (prompt.responseType) {
      RitualPromptType.text => answers[prompt.id],
      RitualPromptType.check => checked.contains(prompt.id),
      _ => null,
    };
  }

  /// JSON v1 remains byte-shape compatible for pages without rich data.
  Map<String, dynamic> toJson() {
    final rich = template.hasRichMetadata || values.isNotEmpty;
    return {
      'version': rich ? 2 : 1,
      if (recordId != null) 'recordId': recordId,
      'templateId': template.id,
      'template': template.toJson(),
      'periodStart': periodStart,
      'state': completed ? 'completed' : 'draft',
      'answers': answers,
      'checked': checked.toList(),
      'referenceIds': referenceIds.toList(),
      if (rich) 'values': values,
    };
  }

  /// JSON data is validated and never interpreted as executable template code.
  static RitualPage read(Map<String, dynamic> raw, {String? recordId}) {
    final version = raw['version'];
    final template = RitualTemplate.read(raw['template']);
    final start = raw['periodStart'];
    final answers = raw['answers'];
    final checked = raw['checked'];
    final references = raw['referenceIds'];
    final rawValues = raw['values'];
    if ((version != 1 && version != 2) ||
        template == null ||
        raw['templateId'] != template.id ||
        start is! String ||
        parseRitualDate(start) == null ||
        (template.weekly &&
            parseRitualDate(start)!.weekday != DateTime.monday) ||
        answers is! Map ||
        answers.keys.any((key) => key is! String) ||
        answers.values.any((value) => value is! String) ||
        checked is! List ||
        checked.any((value) => value is! String) ||
        references is! List ||
        references.any((value) => value is! String) ||
        (raw['recordId'] != null && raw['recordId'] is! String) ||
        !const {'draft', 'completed'}.contains(raw['state']) ||
        (version == 1 &&
            (template.hasRichMetadata || raw.containsKey('values'))) ||
        (version == 2 && rawValues is! Map)) {
      throw const FormatException('Invalid or unsupported ritual page');
    }

    final values = <String, Object?>{};
    if (version == 2) {
      final typedValues = rawValues as Map;
      if (typedValues.keys.any((key) => key is! String)) {
        throw const FormatException('Invalid or unsupported ritual page');
      }
      final prompts = {
        for (final prompt in template.prompts) prompt.id: prompt,
      };
      for (final entry in typedValues.entries) {
        final prompt = prompts[entry.key as String];
        if (prompt == null || !_validResponse(prompt, entry.value)) {
          throw const FormatException('Invalid or unsupported ritual page');
        }
        values[entry.key as String] = entry.value;
      }
    }

    return RitualPage(
      template: template,
      periodStart: start,
      recordId: recordId ?? raw['recordId'] as String?,
      answers: Map<String, String>.from(answers),
      checked: checked.cast<String>().toSet(),
      referenceIds: references.cast<String>().toSet(),
      completed: raw['state'] == 'completed',
      values: values,
    );
  }
}

bool _validResponse(RitualPrompt prompt, Object? value) {
  final optionIds = prompt.options.map((option) => option.id).toSet();
  switch (prompt.responseType) {
    case RitualPromptType.text:
      return value is String;
    case RitualPromptType.check:
      return value is bool;
    case RitualPromptType.singleChoice:
      return value is String && optionIds.contains(value);
    case RitualPromptType.multipleChoice:
      if (value is! List || value.any((item) => item is! String)) return false;
      final selected = value.cast<String>();
      return selected.toSet().length == selected.length &&
          selected.every(optionIds.contains);
    case RitualPromptType.number:
    case RitualPromptType.scale:
      if (value is! num || (value is double && !value.isFinite)) return false;
      final minimum = prompt.minimum;
      final maximum = prompt.maximum;
      final step = prompt.step;
      if ((minimum != null && value < minimum) ||
          (maximum != null && value > maximum)) {
        return false;
      }
      if (prompt.responseType == RitualPromptType.scale &&
          (minimum == null || maximum == null || step == null)) {
        return false;
      }
      if (step != null) {
        final increments = (value - (minimum ?? 0)) / step;
        if (!increments.isFinite ||
            (increments - increments.round()).abs() > 1e-9)
          return false;
      }
      return true;
  }
}
