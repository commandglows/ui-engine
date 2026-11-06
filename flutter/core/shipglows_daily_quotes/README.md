# shipglows_daily_quotes

A bank of short quotes for a daily card, in French and English. Pure Dart, offline,
no API and no account: every device shows the same quote on the same date. Display
stays in each app.

```dart
final quote = DailyQuotes.forContext(QuoteContext.recovery).of(DateTime.now());
quote?.text('fr');
quote?.author; // null for a line written for ShipGlows
```

- `DailyQuote(id, fr, en, contexts, author:, source:)`: `id` is what you store and
  never changes.
- `QuoteContext`: `ambition`, `recovery`, `relationships`.
- `DailyQuotes.forContext(context, quotes:)`: pass `quotes` to add an app's own.
- `of(date)` uses the calendar day as written, and repeats a quote only after all
  the others. Adding quotes reshuffles the coming days, so do not store a schedule.

## Choices

- **Allow-list, no default.** A quote appears only in the contexts it was reviewed
  for. "If you want it, you can" can shame a lapse or a victim of violence, so
  `recovery` and `relationships` are never filled in bulk.
- **Own lines first.** Quotes circulating online are often misattributed, and recent
  authors are under copyright. A named author must be in the public domain, with a
  precise reference. Translations are ours.
- **No API.** Free quote APIs need attribution, rate limit or go offline, and offer
  no reviewed French.
