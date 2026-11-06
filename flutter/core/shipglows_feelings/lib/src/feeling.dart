/// A family of feelings: where a person starts when a word does not come.
enum FeelingFamily {
  joy('Joie et plaisir', 'Joy and pleasure'),
  calm('Calme et sécurité', 'Calm and safety'),
  strength('Force et élan', 'Strength and drive'),
  connection('Lien et tendresse', 'Connection and tenderness'),
  curiosity('Curiosité et surprise', 'Curiosity and surprise'),
  sadness('Tristesse et peine', 'Sadness and hurt'),
  fear('Peur et inquiétude', 'Fear and worry'),
  anger('Colère et agacement', 'Anger and annoyance'),
  shame('Honte et culpabilité', 'Shame and guilt'),
  disgust('Dégoût et rejet', 'Disgust and aversion'),
  confusion('Flou et doute', 'Confusion and doubt'),
  exhaustion('Fatigue et vide', 'Tiredness and emptiness'),
  loneliness('Solitude et manque', 'Loneliness and missing'),
  urges('Ce dont j’ai envie', 'What I feel like doing'),
  body('Dans mon corps', 'In my body');

  const FeelingFamily(this.fr, this.en);

  /// French name.
  final String fr;

  /// English name.
  final String en;

  /// Name for [languageCode]: French for `fr`, English otherwise.
  String label(String languageCode) => languageCode == 'fr' ? fr : en;
}

/// One word for what a person can feel.
class Feeling {
  const Feeling(this.id, this.family, this.fr, this.en, {this.aliases = const []});

  /// Stable id, the value to store. Never changes, even if a label does.
  final String id;

  /// Family this word is listed under.
  final FeelingFamily family;

  /// French label: a noun or an invariable phrase, so it assumes no gender.
  final String fr;

  /// English label.
  final String en;

  /// Other words that should find this one in search, never displayed.
  final List<String> aliases;

  /// Label for [languageCode]: French for `fr`, English otherwise.
  String label(String languageCode) => languageCode == 'fr' ? fr : en;
}
