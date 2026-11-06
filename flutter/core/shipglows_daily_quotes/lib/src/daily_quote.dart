/// A setting a quote has been reviewed for. A quote only appears where it is
/// explicitly listed: nothing is shown by default in a sensitive context.
enum QuoteContext {
  /// Pursuing a long-term goal.
  ambition,

  /// Regaining control over a use or an addiction, without shaming a lapse.
  recovery,

  /// Wellbeing around relationship violence: never asks anyone to endure,
  /// forgive or try harder, and never excuses harm.
  relationships,
}

/// One short quote.
class DailyQuote {
  const DailyQuote(this.id, this.fr, this.en, this.contexts, {this.author, this.source});

  /// Stable id, the value to store. Never changes, even if the text does.
  final String id;

  /// French text.
  final String fr;

  /// English text.
  final String en;

  /// Contexts this quote has been reviewed for.
  final Set<QuoteContext> contexts;

  /// Author, or `null` for a line written for ShipGlows.
  final String? author;

  /// Precise reference in the author's work, when there is an [author].
  final String? source;

  /// Text for [languageCode]: French for `fr`, English otherwise.
  String text(String languageCode) => languageCode == 'fr' ? fr : en;
}
