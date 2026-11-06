# shipglows_reflection_prompt

One question and a private field to answer it. Only draws: the app chooses the
question (see `shipglows_reflection_core`), stores what is kept and decides what
comes next. Colors and spacing come from `ShipglowsTheme`.

```dart
ReflectionPrompt(
  lens: 'Prendre du recul',
  question: question.text('fr'),
  privacyNote: 'Ta réponse reste sur ce téléphone.',
  strings: ReflectionPromptStrings.fr,
  onKeep: (answer) => store.keep(answer), // false keeps the text in the field
  onMoveOn: (draft) => setState(() => question = deck.next(...)),
)
```

- Writing is optional. Without text only « Une autre question » shows; with text,
  keeping becomes the main button and moving on says the text will not be kept.
- `quote`: earlier words to look at again, above the question.
- `onMoveOn` receives the draft, then the card forgets it. An app may read it to
  watch for a crisis and must not store it.
- **Drafts do not linger:** the field empties when the question changes and when
  the app leaves the foreground. Set `forgetDraftInBackground: false` only for
  content that is not sensitive.
- The app protects the screen itself, for instance from screenshots.
