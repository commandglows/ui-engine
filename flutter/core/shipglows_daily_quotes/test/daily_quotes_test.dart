import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_daily_quotes/shipglows_daily_quotes.dart';

void main() {
  test('bank ids are unique, texts filled, contexts set', () {
    expect(standardQuotes.map((quote) => quote.id).toSet().length, standardQuotes.length);
    for (final quote in standardQuotes) {
      expect(quote.fr.trim(), isNotEmpty, reason: quote.id);
      expect(quote.en.trim(), isNotEmpty, reason: quote.id);
      expect(quote.contexts, isNotEmpty, reason: quote.id);
      expect(quote.author == null, quote.source == null, reason: quote.id);
    }
  });

  for (final context in QuoteContext.values) {
    test('$context only holds its quotes, each once per cycle', () {
      final selection = DailyQuotes.forContext(context);
      expect(selection.quotes.every((quote) => quote.contexts.contains(context)), isTrue);
      final count = selection.quotes.length;
      final seen = {
        for (var day = 0; day < count; day++) selection.of(DateTime.utc(2026, 11, 1 + day))!.id,
      };
      expect(seen.length, count);
    });
  }

  test('the pick depends on the calendar day only', () {
    final selection = DailyQuotes.forContext(QuoteContext.recovery);
    expect(selection.of(DateTime(2026, 11, 7, 0, 1))!.id, selection.of(DateTime.utc(2026, 11, 7, 23, 59))!.id);
  });

  test('an empty selection gives no quote', () {
    expect(DailyQuotes.forContext(QuoteContext.ambition, quotes: const []).of(DateTime(2026)), isNull);
  });
}
