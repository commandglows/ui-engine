import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feelings/shipglows_feelings.dart';
import 'package:shipglows_lifeline_core/shipglows_lifeline_core.dart';

final _today = DateTime(2026, 11, 6);

LifelineSignal _signal(int weight, {int daysAgo = 0, bool critical = false}) =>
    LifelineSignal(
      id: 'w$weight',
      day: DateTime(2026, 11, 6 - daysAgo),
      weight: weight,
      critical: critical,
    );

LifelineLevel _level(List<LifelineSignal> signals) =>
    assessLifeline(signals, today: _today).level;

void main() {
  group('level', () {
    test('rises with the score', () {
      expect(_level([]), LifelineLevel.none);
      expect(_level([_signal(2)]), LifelineLevel.none);
      expect(_level([_signal(3)]), LifelineLevel.gentle);
      expect(_level([_signal(3), _signal(3)]), LifelineLevel.support);
    });

    test('many light signals alone never reach urgent', () {
      final light = [for (var i = 0; i < 14; i++) _signal(2, daysAgo: i)];
      expect(_level(light), LifelineLevel.support);
    });

    test('a high score with a strong signal reaches urgent', () {
      expect(
        _level([_signal(5), _signal(5, daysAgo: 1), _signal(5, daysAgo: 2)]),
        LifelineLevel.urgent,
      );
    });

    test('a critical signal alone reaches urgent', () {
      expect(_level([_signal(0, critical: true)]), LifelineLevel.urgent);
    });

    test('signals outside the window or in the future do not count', () {
      expect(_level([_signal(6, daysAgo: 14)]), LifelineLevel.none);
      expect(_level([_signal(6, daysAgo: 13)]), LifelineLevel.support);
      expect(_level([_signal(6, daysAgo: -1)]), LifelineLevel.none);
    });
  });

  group('showing the page', () {
    bool show(List<LifelineSignal> signals, LifelineMemory? memory) =>
        shouldShowLifeline(
          assessLifeline(signals, today: _today),
          memory,
          today: _today,
        );

    LifelineMemory shown(LifelineLevel level, int daysAgo) =>
        LifelineMemory(level: level, day: DateTime(2026, 11, 6 - daysAgo));

    test('never at the none level', () {
      expect(show([], null), isFalse);
    });

    test('never on a day that brought no signal', () {
      expect(show([_signal(6, daysAgo: 1)], null), isFalse);
    });

    test('waits out the cooldown of the same level', () {
      final gentle = [_signal(3)];
      expect(show(gentle, shown(LifelineLevel.gentle, 6)), isFalse);
      expect(show(gentle, shown(LifelineLevel.gentle, 7)), isTrue);
    });

    test('a lower level waits for the cooldown of the page shown', () {
      final gentle = [_signal(3)];
      expect(show(gentle, shown(LifelineLevel.support, 2)), isFalse);
      expect(show(gentle, shown(LifelineLevel.support, 3)), isTrue);
    });

    test('a firmer level shows at once', () {
      expect(show([_signal(6)], shown(LifelineLevel.gentle, 0)), isTrue);
    });

    test('urgent does not repeat the same day, but returns the next', () {
      final urgent = [_signal(0, critical: true)];
      expect(show(urgent, shown(LifelineLevel.urgent, 0)), isFalse);
      expect(show(urgent, shown(LifelineLevel.urgent, 1)), isTrue);
    });
  });

  group('memory', () {
    test('reads back what it wrote', () {
      final memory = LifelineMemory(level: LifelineLevel.support, day: _today);
      final read = LifelineMemory.fromJson(memory.toJson());
      expect(read?.level, LifelineLevel.support);
      expect(read?.day, _today);
    });

    test('a damaged memory reads as none', () {
      expect(LifelineMemory.fromJson('x'), isNull);
      expect(LifelineMemory.fromJson({'level': 'other', 'day': '2026-11-06'}), isNull);
      expect(LifelineMemory.fromJson({'level': 'gentle', 'day': 'hier'}), isNull);
    });
  });

  group('crisis words', () {
    test('finds them despite case, accents and apostrophes', () {
      expect(mentionsCrisis('envie de MOURIR'), isTrue);
      expect(mentionsCrisis('disparaître'), isTrue);
      expect(mentionsCrisis('en finir'), isTrue);
      expect(mentionsCrisis('me foutre en l’air'), isTrue);
      expect(mentionsCrisis('I want to die'), isTrue);
    });

    test('leaves other words and everyday phrases alone', () {
      expect(mentionsCrisis('barbouillée'), isFalse);
      expect(mentionsCrisis('mourir de rire'), isFalse);
    });
  });

  group('feeling weights', () {
    test('every listed word exists in the bank', () {
      for (final id in feelingWeights.keys) {
        expect(FeelingBank.standard.byId(id), isNotNull, reason: id);
      }
    });

    test('a word that is not listed weighs nothing', () {
      expect(feelingWeight('joy'), 0);
      expect(feelingWeight('despair'), greaterThanOrEqualTo(5));
    });
  });

  test('helplines have dialable numbers', () {
    const contacts = [
      FrenchHelplines.emergency,
      FrenchHelplines.police,
      FrenchHelplines.emergencySms,
      FrenchHelplines.suicidePrevention,
      FrenchHelplines.sosAmitie,
      FrenchHelplines.violenceAgainstWomen,
      FrenchHelplines.victimSupport,
      FrenchHelplines.drugsInfo,
    ];
    for (final contact in contacts) {
      expect(contact.number, matches(RegExp(r'^\d+$')), reason: contact.name);
    }
  });
}
