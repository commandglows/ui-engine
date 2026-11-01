import 'period.dart';

/// A reusable question or checklist item. Sessions keep their own snapshot.
class RitualPrompt {
  const RitualPrompt(this.id, this.label, {this.check = false});

  final String id, label;
  final bool check;

  Map<String, dynamic> toJson() => {'id': id, 'label': label, 'check': check};
}

/// The period is calculated in the civil calendar provided by the host.
DateTime ritualPeriod(RitualTemplate template, DateTime date) => template.weekly
    ? addRitualDays(date, -(date.weekday - DateTime.monday))
    : DateTime(date.year, date.month, date.day);

/// Product templates and personal copies share this portable v1 contract.
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

  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'title': title,
    'description': description,
    'cadence': weekly ? 'weekly' : 'daily',
    'prompts': prompts.map((prompt) => prompt.toJson()).toList(),
  };

  static RitualTemplate? read(Object? raw) {
    if (raw is! Map ||
        raw['version'] != 1 ||
        raw['id'] is! String ||
        (raw['id'] as String).trim().isEmpty ||
        raw['title'] is! String ||
        (raw['title'] as String).trim().isEmpty ||
        raw['description'] is! String ||
        !const {'daily', 'weekly'}.contains(raw['cadence']) ||
        raw['prompts'] is! List)
      return null;
    final prompts = <RitualPrompt>[];
    final ids = <String>{};
    for (final item in raw['prompts'] as List) {
      if (item is! Map ||
          item['id'] is! String ||
          (item['id'] as String).trim().isEmpty ||
          !ids.add(item['id'] as String) ||
          item['label'] is! String ||
          (item['label'] as String).trim().isEmpty ||
          item['check'] is! bool)
        return null;
      prompts.add(
        RitualPrompt(
          item['id'] as String,
          item['label'] as String,
          check: item['check'] as bool,
        ),
      );
    }
    if (prompts.isEmpty || prompts.length > 40) return null;
    return RitualTemplate(
      id: raw['id'] as String,
      title: raw['title'] as String,
      description: raw['description'] as String,
      weekly: raw['cadence'] == 'weekly',
      prompts: prompts,
    );
  }
}
