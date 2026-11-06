# shipglows_feelings

A broad bank of words so people can name what they feel: emotions, states, urges
and body sensations, in French and English, grouped into 15 families. Pure Dart:
storage, wording around the words and safety routing stay in each app. The
picker lives in `shipglows_feeling_picker`.

```dart
final bank = FeelingBank.standard;
bank.search('coupable', languageCode: 'fr'); // finds Culpabilité
bank.labelOf('guilt', languageCode: 'fr'); // Culpabilité

// An app picks its own bank.
final mine = FeelingBank.standard
    .without(['urge_break'])
    .plus(const [
      Feeling('urge_use', FeelingFamily.urges, 'Envie de consommer', 'Urge to use'),
    ]);
```

- `Feeling(id, family, fr, en, aliases:)`: `id` is what you store and never
  changes. `aliases` only help search.
- `FeelingFamily`: joy, calm, strength, connection, curiosity, sadness, fear,
  anger, shame, disgust, confusion, exhaustion, loneliness, urges, body.
- `FeelingBank`: `feelings`, `families`, `ofFamily`, `byId`, `labelOf`, `search`,
  and `only`, `without`, `plus` to shape an app's own bank. `plus` replaces a
  word with the same id in place, which is how an app rewords one.
- The person's own words: `customFeelingId('un mot')` gives an id to store,
  `customFeelingText(id)` reads it back, and `labelOf` handles both. Empty text
  gives `null`; text is cut to `maxCustomFeelingLength`.

## Choices

- **Nouns and invariable phrases**, so a label never assumes a gender (« Colère »,
  « À bout »). Adjectives people actually type (« coupable », « seule ») are
  aliases, so search still finds them.
- **No score.** Words are not ranked as positive or negative here: feelings are
  not good or bad, and an app that needs a valence decides it for itself.
- **Nothing about wanting to die or disappear.** Such words call for a crisis
  response, which a word list cannot give. An app offering free words or strong
  words such as « Désespoir » owns that routing.

## Sources

Families and coverage draw on Cowen and Keltner, PNAS 2017 (27 categories of
reported emotion), Plutchik's families, and French feeling lists such as the
Université de Moncton's. Evidence that naming emotions precisely helps is real
but mixed: Vine et al., Nature Communications 2020, found richer negative
vocabularies tied to lower mental health, and warn that too many labels at once
could get in the way. So present the bank by family and search, never as a wall
of words, and promise no effect.
