# shipglows_feeling_picker

Helps a person put words on what they feel without facing a wall of words: a few
suggested words inline, then a sheet with the whole `shipglows_feelings` bank, by
family and by search, plus their own word when none fits. Only draws: the app
stores the ids it receives. Chips come from `shipglows_tag_picker`, colors from
`ShipglowsTheme`.

```dart
FeelingPicker(
  title: 'Which words fit?',
  bank: FeelingBank.standard,
  suggestions: const ['calm', 'fatigue', 'joy', 'worry'],
  selected: selected,
  onChanged: (next) => setState(() => selected = next),
  maxSelected: 5,
  languageCode: 'en',
)
```

- `suggestions`: ids shown inline. Words already picked are always shown too.
- The sheet opens from « See all the words ». Families start closed, each with a
  few example words, because people find a word more easily by starting from the
  family that feels closest. Picked words stay on top, removable.
- Search covers labels in both languages and aliases, so an adjective finds its
  noun. When the search is not an exact word, the person can add it as their own
  (`allowCustom`, on by default). It is stored as a `customFeelingId`.
- `FeelingPickerStrings.fr` / `.en`, or your own: every string. `languageCode`
  defaults to the ambient locale.
- `showFeelingBankSheet` opens the sheet from your own button.

Selection changes are reported as they happen, so closing the sheet loses nothing.
