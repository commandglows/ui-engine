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
  });

  final RitualTemplate template;
  final String periodStart;
  final String? recordId;
  final Map<String, String> answers;
  final Set<String> checked, referenceIds;
  final bool completed;

  /// JSON v1 is a data contract, never executable template code.
  Map<String, dynamic> toJson() => {
    'version': 1,
    'recordId': ?recordId,
    'templateId': template.id,
    'template': template.toJson(),
    'periodStart': periodStart,
    'state': completed ? 'completed' : 'draft',
    'answers': answers,
    'checked': checked.toList(),
    'referenceIds': referenceIds.toList(),
  };

  static RitualPage read(Map<String, dynamic> raw, {String? recordId}) {
    final template = RitualTemplate.read(raw['template']);
    final start = raw['periodStart'];
    final answers = raw['answers'];
    final checked = raw['checked'];
    final references = raw['referenceIds'];
    if (raw['version'] != 1 ||
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
        !const {'draft', 'completed'}.contains(raw['state'])) {
      throw const FormatException('Invalid or unsupported ritual page');
    }
    return RitualPage(
      template: template,
      periodStart: start,
      recordId: recordId ?? raw['recordId'] as String?,
      answers: Map<String, String>.from(answers),
      checked: checked.cast<String>().toSet(),
      referenceIds: references.cast<String>().toSet(),
      completed: raw['state'] == 'completed',
    );
  }
}
