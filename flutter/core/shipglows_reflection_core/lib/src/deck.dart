import 'standard_questions.dart';

/// The angle a question takes.
enum ReflectionLens {
  /// Stepping back: another person, another time, an outside eye.
  distance,

  /// What matters to the person, whoever is watching.
  whatMatters,

  /// Ideas the person holds about themselves.
  belief,

  /// What the person has already crossed, and where they are heading.
  growth,

  /// How someone else may see it. Unsafe under another person's control.
  otherView,

  /// The person's reading of a situation, or their part in it. Unsafe under
  /// another person's control.
  ownPart,
}

/// One question.
class ReflectionQuestion {
  /// Creates a question.
  const ReflectionQuestion(this.id, this.lens, this.fr, this.en);

  /// Stable id, the value to store.
  final String id;

  /// The angle it takes.
  final ReflectionLens lens;

  /// French wording.
  final String fr;

  /// English wording.
  final String en;

  /// The wording for [languageCode], French by default.
  String text(String languageCode) => languageCode == 'en' ? en : fr;
}

/// A set of questions an app offers, one at a time.
class ReflectionDeck {
  /// Creates a deck.
  const ReflectionDeck(this.questions);

  /// The standard questions. See the README before offering all of them.
  static const ReflectionDeck standard = ReflectionDeck(
    standardReflectionQuestions,
  );

  /// All the questions, in order.
  final List<ReflectionQuestion> questions;

  /// The question with this [id], if any.
  ReflectionQuestion? byId(String id) {
    for (final question in questions) {
      if (question.id == id) return question;
    }
    return null;
  }

  /// A deck with only these [ids], in the order of this deck.
  ///
  /// Prefer this for a sensitive audience: a question added to the standard
  /// bank later will not reach it unread.
  ReflectionDeck only(Iterable<String> ids) {
    final kept = ids.toSet();
    return ReflectionDeck([
      for (final question in questions)
        if (kept.contains(question.id)) question,
    ]);
  }

  /// A deck without any question taking one of these [lenses].
  ReflectionDeck withoutLenses(Iterable<ReflectionLens> lenses) {
    final removed = lenses.toSet();
    return ReflectionDeck([
      for (final question in questions)
        if (!removed.contains(question.lens)) question,
    ]);
  }

  /// This deck followed by [extra]. A question with the same id is replaced in
  /// place, which is how an app rewords one.
  ReflectionDeck plus(Iterable<ReflectionQuestion> extra) {
    final byId = <String, ReflectionQuestion>{
      for (final question in questions) question.id: question,
      for (final question in extra) question.id: question,
    };
    return ReflectionDeck(byId.values.toList());
  }

  /// The next question to ask, or `null` for an empty deck.
  ///
  /// [recent] lists ids already used, oldest first. A question never used comes
  /// before one that was, then the one used longest ago. Among equals, a
  /// different lens from the last question is preferred, starting at [seed]:
  /// pass the day to keep the same question all day and vary it the next.
  ReflectionQuestion? next({
    List<String> recent = const [],
    int seed = 0,
  }) {
    if (questions.isEmpty) return null;
    final start = seed.abs() % questions.length;
    final rotated = [
      ...questions.sublist(start),
      ...questions.sublist(0, start),
    ];
    final lastUse = <String, int>{
      for (var i = 0; i < recent.length; i++) recent[i]: i,
    };
    final oldest = rotated
        .map((question) => lastUse[question.id] ?? -1)
        .reduce((a, b) => a < b ? a : b);
    final candidates = [
      for (final question in rotated)
        if ((lastUse[question.id] ?? -1) == oldest) question,
    ];
    final lastLens = recent.isEmpty ? null : byId(recent.last)?.lens;
    for (final question in candidates) {
      if (question.lens != lastLens) return question;
    }
    return candidates.first;
  }
}
