import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feelings/shipglows_feelings.dart';

void main() {
  final bank = FeelingBank.standard;

  group('standard words', () {
    test('ids are unique and every label is filled', () {
      final ids = standardFeelings.map((feeling) => feeling.id).toSet();
      expect(ids.length, standardFeelings.length);
      for (final feeling in standardFeelings) {
        expect(feeling.fr.trim(), isNotEmpty, reason: feeling.id);
        expect(feeling.en.trim(), isNotEmpty, reason: feeling.id);
      }
    });

    test('French labels are unique, so two chips never look the same', () {
      final labels = standardFeelings.map((feeling) => feeling.fr).toSet();
      expect(labels.length, standardFeelings.length);
    });

    test('the bank is broad and every family has words', () {
      expect(standardFeelings.length, greaterThanOrEqualTo(200));
      expect(bank.families, FeelingFamily.values);
    });

    test('offers no words about wanting to die or disappear', () {
      final everything = standardFeelings
          .expand((f) => [f.fr, f.en, ...f.aliases])
          .join(' ')
          .toLowerCase();
      for (final word in ['mourir', 'suicid', 'disparaitre', 'disparaître']) {
        expect(everything, isNot(contains(word)));
      }
    });
  });

  group('search', () {
    test('finds a noun from the adjective people type', () {
      final found = bank.search('coupable', languageCode: 'fr');
      expect(found.first.id, 'guilt');
    });

    test('ignores case and accents', () {
      final found = bank.search('COLERE', languageCode: 'fr');
      expect(found.first.id, 'anger');
    });

    test('puts a label match before an alias match', () {
      final found = bank.search('peur', languageCode: 'fr');
      expect(found.first.id, 'fear');
    });

    test('finds a word in the other language', () {
      final found = bank.search('angry', languageCode: 'fr');
      expect(found.map((feeling) => feeling.id), contains('anger'));
    });

    test('an empty query returns every word', () {
      expect(bank.search('  ', languageCode: 'fr').length, bank.feelings.length);
    });
  });

  group('labels', () {
    test('follow the language, and stay unknown for a retired id', () {
      expect(bank.labelOf('guilt', languageCode: 'fr'), 'Culpabilité');
      expect(bank.labelOf('guilt', languageCode: 'en'), 'Guilt');
      expect(bank.labelOf('retired', languageCode: 'fr'), isNull);
    });
  });

  group('the person’s own words', () {
    test('are tidied, and read back through labelOf', () {
      final id = customFeelingId('  un   mot à moi ');
      expect(id, 'custom:un mot à moi');
      expect(customFeelingText(id!), 'un mot à moi');
      expect(bank.labelOf(id, languageCode: 'fr'), 'un mot à moi');
    });

    test('blank text gives no id, and long text is cut', () {
      expect(customFeelingId('   '), isNull);
      final long = customFeelingId('a' * 100)!;
      expect(customFeelingText(long)!.length, maxCustomFeelingLength);
    });

    test('a plain id is not a custom word', () {
      expect(customFeelingText('guilt'), isNull);
    });
  });

  group('an app’s own bank', () {
    test('only and without keep the bank’s order', () {
      expect(
        bank.only(['fear', 'joy']).feelings.map((f) => f.id).toList(),
        ['joy', 'fear'],
      );
      expect(bank.without(['joy']).byId('joy'), isNull);
    });

    test('plus replaces in place and adds the rest at the end', () {
      const reworded = Feeling('joy', FeelingFamily.joy, 'Grande joie', 'Joy');
      const added = Feeling('urge_use', FeelingFamily.urges, 'Envie de consommer', 'Urge to use');
      final mine = bank.only(['joy', 'fear']).plus([reworded, added]);

      expect(mine.feelings.map((f) => f.id).toList(), ['joy', 'fear', 'urge_use']);
      expect(mine.labelOf('joy', languageCode: 'fr'), 'Grande joie');
    });

    test('families leaves out those without words', () {
      expect(bank.only(['joy']).families, [FeelingFamily.joy]);
    });
  });
}
