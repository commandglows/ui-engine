# shipglows_tag_picker

Tap a few words out of a list: feelings, contexts, triggers. Only draws: the
app owns the vocabulary, the wording and the storage. Colors and spacing come
from `ShipglowsTheme`.

```dart
TagPicker(
  title: 'Which words fit today?',
  helper: 'Optional',
  options: const [
    TagOption(id: 'calm', label: 'Calm'),
    TagOption(id: 'tired', label: 'Tired'),
  ],
  selected: selected,
  onChanged: (next) => setState(() => selected = next),
  maxSelected: 3,
  limitMessage: 'Three words at most. Remove one to pick another.',
)
```

- `TagOption(id:, label:)`: store the stable `id`, show the `label`.
- `maxSelected`: at the limit the other chips are disabled and `limitMessage`
  says why, announced to screen readers. A selected chip can always be removed.
- A selected id missing from `options` is kept and passed back in `onChanged`,
  so an app can retire a word without losing older answers.

Selection shows a check mark as well as a color. The title is a heading for
screen readers.
