import 'daily_quote.dart';
import 'standard_quotes.dart';

/// Quotes of one context, with one stable pick per calendar day.
class DailyQuotes {
  /// A selection reviewed for [context], from [quotes].
  factory DailyQuotes.forContext(QuoteContext context, {List<DailyQuote> quotes = standardQuotes}) {
    return DailyQuotes._(List.unmodifiable(quotes.where((quote) => quote.contexts.contains(context))));
  }

  const DailyQuotes._(this.quotes);

  /// Quotes of this selection, in bank order.
  final List<DailyQuote> quotes;

  /// Quote of the calendar day of [date], read as written so the quote changes
  /// at the person's midnight. `null` when the selection is empty.
  ///
  /// The same date always gives the same quote while the selection is
  /// unchanged, and no quote returns before all the others have appeared.
  DailyQuote? of(DateTime date) {
    final count = quotes.length;
    if (count == 0) return null;
    final dayNumber = DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    return quotes[(dayNumber * _stepFor(count)) % count];
  }

  /// A stride coprime with [count], so each quote comes once per cycle, far
  /// enough from 1 that bank neighbours do not follow each other.
  static int _stepFor(int count) {
    var step = (count * 0.618).floor().clamp(1, count);
    while (step.gcd(count) != 1) {
      step++;
    }
    return step;
  }
}
