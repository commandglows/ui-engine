# shipglows_patterns

Finds what tends to go with a tracked value in a self-tracking app: mood and
context, sleep and habits, cravings and triggers. Pure Dart, no storage, no
wording: the app turns its entries into observations and writes its own
sentences.

```dart
final findings = findPatterns([
  for (final day in days)
    PatternObservation(value: day.mood, tags: day.tags),
]);
```

- `PatternObservation(value:, tags:)`: one tracked period. Non-finite values
  are ignored.
- `PatternRules(minObservations:, minWithTag:, minWithoutTag:, minGap:)`: the
  guards, by default 10 observations, 3 with the tag, 3 without it and a gap
  of 0.25 between the two means. `minGap` is in the unit of `value`, so a
  1-10 scale needs its own.
- `findPatterns(observations, rules:)`: returns `PatternFinding`s (`tag`,
  `countWith`, `countWithout`, `meanWith`, `meanWithout`, `gap`), widest gap
  first, in a stable order. Below the guards it returns nothing: too little
  data gives no answer rather than a weak one.

A finding describes the person's own entries. No significance test runs and
nothing here proves a cause, so word it as a lead the person can check ("often,
when..."), never as an explanation or a diagnosis.

Tag counts live in `shipglows_organize` (`tagCounts`).
