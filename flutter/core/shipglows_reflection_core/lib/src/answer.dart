/// An answer the person chose to keep.
class ReflectionAnswer {
  /// Creates an answer. [day] counts by its date only.
  const ReflectionAnswer({
    required this.id,
    required this.day,
    required this.question,
    required this.text,
    this.questionId,
    this.revisitOf,
  });

  /// Reads a stored answer, or returns `null` if it is damaged.
  static ReflectionAnswer? read(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final question = raw['question'];
    final text = raw['text'];
    final questionId = raw['questionId'];
    final revisitOf = raw['revisitOf'];
    final day = raw['day'] is String
        ? DateTime.tryParse(raw['day'] as String)
        : null;
    if (id is! String ||
        id.isEmpty ||
        question is! String ||
        text is! String ||
        text.trim().isEmpty ||
        day == null ||
        (questionId != null && questionId is! String) ||
        (revisitOf != null && revisitOf is! String)) {
      return null;
    }
    return ReflectionAnswer(
      id: id,
      day: day,
      question: question,
      text: text,
      questionId: questionId as String?,
      revisitOf: revisitOf as String?,
    );
  }

  /// Stable id.
  final String id;

  /// The day it was written.
  final DateTime day;

  /// The question as it was read, kept even if the wording changes later.
  final String question;

  /// What the person wrote.
  final String text;

  /// Id of the question, if it came from a deck.
  final String? questionId;

  /// Id of the older answer this one rereads, if any.
  final String? revisitOf;

  /// The stored form.
  Map<String, Object> toJson() => {
    'id': id,
    'day': _date(day),
    'question': question,
    'text': text,
    'questionId': ?questionId,
    'revisitOf': ?revisitOf,
  };
}

/// The oldest answer worth rereading today, or `null`.
///
/// It is at least [minAgeDays] old and has not been reread yet, so that a
/// reread looks at a distance instead of going over the same day again.
ReflectionAnswer? answerToRevisit(
  List<ReflectionAnswer> answers, {
  required DateTime today,
  int minAgeDays = 30,
}) {
  final reread = {for (final answer in answers) ?answer.revisitOf};
  ReflectionAnswer? oldest;
  for (final answer in answers) {
    if (reread.contains(answer.id) ||
        _daysBetween(answer.day, today) < minAgeDays) {
      continue;
    }
    if (oldest == null || answer.day.isBefore(oldest.day)) oldest = answer;
  }
  return oldest;
}

/// Calendar days between two dates, whatever the clock changes in between.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

String _date(DateTime day) {
  final year = day.year.toString().padLeft(4, '0');
  final month = day.month.toString().padLeft(2, '0');
  final date = day.day.toString().padLeft(2, '0');
  return '$year-$month-$date';
}
