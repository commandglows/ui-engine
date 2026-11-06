# shipglows_reflection_core

Questions that make a person look again: stepping back, another angle, an idea
held about oneself, what they have already crossed. One at a time, without
repeating. Answers the person keeps can be reread later. Pure Dart: storage,
surrounding wording and who may be asked what stay in each app. The question card
lives in `shipglows_reflection_prompt`.

```dart
final deck = ReflectionDeck.standard.withoutLenses(const [
  ReflectionLens.otherView,
  ReflectionLens.ownPart,
]);

final question = deck.next(recent: usedIds, seed: dayNumber);
question?.text('fr');

final older = answerToRevisit(keptAnswers, today: DateTime.now());
```

- `ReflectionQuestion(id, lens, fr, en)`: store the `id`, which never changes.
- `ReflectionDeck`: `only`, `withoutLenses`, `plus` shape an app's own deck. `next`
  picks a question never used, then the one used longest ago, and prefers a new
  lens. Add an id to `recent` when the person answers or moves on, not when the
  question appears: with `seed` set to the day, it stays the same until then.
- `ReflectionAnswer`: keeps the question as it was read. `read` returns `null` for
  a damaged entry, so one bad entry never loses the others.
- `answerToRevisit`: the oldest kept answer at least 30 days old, not reread yet.

## Who may be asked what

These questions push, and pushing can hurt. A question that helps one person to
grow can tell another that they caused what is done to them.

- **`otherView` and `ownPart` are unsafe under another person's control.** « Quelle
  part dépend de toi ? » or « Comment l'autre le raconterait-il ? » feed self-blame
  and the doubt that control creates. Offer them only where the app knows no one
  is exposed, which is rarely knowable.
- **For an audience exposed to violence, use `only` with reviewed ids**, not a lens
  filter: a question added here later must not reach them unread.
- **Stop when it hurts.** Every question can be skipped without a reason. An app
  should offer a way to stop and something calming, and watch free text for a
  crisis (`mentionsCrisis` in `shipglows_lifeline_core`).

## Choices

- **No score, no count.** An answer is never rated, and the deck does not track
  streaks.
- **Distance rather than « why ».** Kross, Ayduk and Mischel, Psychological Science
  2005, compared recalling an anger-eliciting experience from a self-immersed or a
  self-distanced perspective. Asking why did not raise negative affect when the
  person took a distanced view. Lab studies on recalled anger, not on an app: a
  reason for the wording, not a promised effect.
- **Answers are not a record of progress.** Rereading compares two moments of the
  person's own words. Nothing is concluded for them.

The wording has not been reviewed by a specialist. Have it reviewed before release.
