# shipglows_bulk_delete

A dialog to delete many items at once: the person picks the types and the period,
sees how many items that means as they choose, and can include pinned items. It
deletes nothing itself: the app gives it what may be deleted and removes what
comes back. Colors and spacing come from `ShipglowsTheme`.

```dart
final chosen = await showBulkDeleteDialog(
  context: context,
  strings: BulkDeleteStrings.fr,
  categories: const [
    BulkDeleteCategory(id: 'voice', label: 'Voix'),
    BulkDeleteCategory(id: 'clipboard', label: 'Presse-papiers'),
    // Long-lived content starts unchosen.
    BulkDeleteCategory(id: 'snippet', label: 'Snippets', selected: false),
  ],
  entries: [
    for (final note in notes)
      BulkDeleteEntry(
        id: note.id,
        category: 'voice',
        date: note.updatedAt,
        protected: note.pinned,
      ),
  ],
);
if (chosen != null) {
  await deleteAll(chosen);
}
```

- **Periods:** Dernière heure (chosen at first), Aujourd’hui, 5 derniers jours,
  Dernière semaine, Personnalisé, Tout. `periods` and `initialPeriod` change
  them, with any `DatePeriod` from `shipglows_date_groups`.
- **Undated items** only match Tout.
- **Pinned items** (`protected`) stay out unless the person ticks the box, which
  only shows when the current choices match some.
- **Safety:** Cancel holds the focus, so Enter never deletes, and the confirm
  button states the count: « Supprimer 12 éléments ».
- `notice` adds a line, for what stays out of reach.

Personnalisé uses Flutter's date range picker, which needs the app's
`MaterialLocalizations`.
