# shipglows_lifeline_core

The logic of a progressive lifeline: from what a person notes, decide whether to
offer help, how firmly, and when to leave them alone. Pure Dart. The page is in
`shipglows_lifeline`; storage and wording stay in each app.

```dart
final assessment = assessLifeline(signals, today: today);
if (shouldShowLifeline(assessment, memory, today: today)) {
  // Show the page for assessment.level, then save a new LifelineMemory.
}
```

- `LifelineSignal(id:, day:, weight:, critical:)`: one thing noted on a civil day.
- `LifelineLevel`: `none`, `gentle`, `support`, `urgent`.
- `LifelineRules`: the 14-day window, the score of each level (3, 6, 15), the
  weight that counts as strong (5) and the cooldowns.
- `assessLifeline`: `urgent` needs a critical signal, or a high score with at
  least one strong signal. Many light signals alone stop at `support`.
- `shouldShowLifeline`: only when today brought a signal, so a good day is never
  interrupted because of last week. After a page, the same level or a lower one
  waits out its cooldown (7, 3 and 1 days). A higher level shows at once.
- `feelingWeight(id)`: the weight of a `shipglows_feelings` word. Unlisted words
  weigh nothing.
- `mentionsCrisis(text)`: true when free text talks about wanting to die or
  harming oneself, ignoring case and accents.
- `FrenchHelplines`: helplines of France, each with its audience and hours.
  Checked on 2026-11-06 on service-public.gouv.fr, masecurite.interieur.gouv.fr,
  arretonslesviolences.gouv.fr and Santé publique France. Re-check them regularly.

## Limits

This is not risk detection. The weights and thresholds are an editorial judgement,
not a validated instrument, and have not been reviewed by a clinician. A person
in danger may note nothing, so help must stay visible at all times, whatever this
package returns. Too many false alarms also teach people to ignore the page
(Mental Health App Crisis Support Assessment Framework, Frontiers in Digital
Health, 2026), hence the cooldowns.

The steps follow the logic of the Safety Planning Intervention (Stanley and
Brown): coping first, then people, then professionals, then emergency services.
