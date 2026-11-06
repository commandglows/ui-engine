import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_reflection_core/shipglows_reflection_core.dart';

const _a = ReflectionQuestion('a', ReflectionLens.distance, 'A', 'A en');
const _b = ReflectionQuestion('b', ReflectionLens.distance, 'B', 'B en');
const _c = ReflectionQuestion('c', ReflectionLens.whatMatters, 'C', 'C en');
const _deck = ReflectionDeck([_a, _b, _c]);

ReflectionAnswer _answer(String id, DateTime day, {String? revisitOf}) =>
    ReflectionAnswer(
      id: id,
      day: day,
      question: 'Q',
      text: 'T',
      revisitOf: revisitOf,
    );

void main() {
  group('the deck', () {
    test('an empty deck has no next question', () {
      expect(const ReflectionDeck([]).next(), isNull);
    });

    test('never repeats while a question is left', () {
      expect(_deck.next(recent: ['a', 'c'])?.id, 'b');
    });

    test('comes back to the one used longest ago', () {
      expect(_deck.next(recent: ['b', 'c', 'a'])?.id, 'b');
    });

    test('prefers another lens than the last question', () {
      expect(_deck.next(recent: ['a'])?.id, 'c');
    });

    test('the same seed gives the same question, another seed moves on', () {
      expect(_deck.next(seed: 4)?.id, _deck.next(seed: 4)?.id);
      expect(_deck.next(seed: 1)?.id, 'b');
      expect(_deck.next(seed: 2)?.id, 'c');
    });

    test('filters and rewords', () {
      expect(_deck.only(['c', 'a']).questions, [_a, _c]);
      expect(_deck.withoutLenses([ReflectionLens.distance]).questions, [_c]);
      const reworded = ReflectionQuestion(
        'b',
        ReflectionLens.distance,
        'B2',
        'B2 en',
      );
      expect(_deck.plus([reworded]).questions, [_a, reworded, _c]);
    });

    test('standard ids are unique and every question has both languages', () {
      final questions = ReflectionDeck.standard.questions;
      expect(questions.map((q) => q.id).toSet().length, questions.length);
      for (final question in questions) {
        expect(question.fr, isNotEmpty);
        expect(question.en, isNotEmpty);
      }
    });
  });

  group('rereading', () {
    final today = DateTime(2026, 11, 6);

    test('offers the oldest answer old enough', () {
      final answers = [
        _answer('recent', DateTime(2026, 11, 1)),
        _answer('old', DateTime(2026, 8, 1)),
        _answer('older', DateTime(2026, 7, 1)),
      ];
      expect(answerToRevisit(answers, today: today)?.id, 'older');
    });

    test('does not offer an answer twice', () {
      final answers = [
        _answer('old', DateTime(2026, 7, 1)),
        _answer('new', DateTime(2026, 11, 1), revisitOf: 'old'),
      ];
      expect(answerToRevisit(answers, today: today), isNull);
    });

    test('offers nothing when everything is recent', () {
      final answers = [_answer('recent', DateTime(2026, 10, 20))];
      expect(answerToRevisit(answers, today: today), isNull);
    });
  });

  group('storage', () {
    test('an answer survives a round trip', () {
      const stored = {
        'id': '1',
        'day': '2026-11-06',
        'question': 'Q',
        'text': 'T',
        'questionId': 'a',
        'revisitOf': '0',
      };
      expect(ReflectionAnswer.read(stored)?.toJson(), stored);
    });

    test('a damaged answer is refused', () {
      expect(ReflectionAnswer.read('nope'), isNull);
      expect(ReflectionAnswer.read({'id': '1'}), isNull);
      expect(
        ReflectionAnswer.read({
          'id': '1',
          'day': 'not a date',
          'question': 'Q',
          'text': 'T',
        }),
        isNull,
      );
    });
  });
}
