# shipglows_date_sections

Draws a list cut by date, with an optional period filter. Only draws: the logic
and the texts come from `shipglows_date_groups`, re-exported here, and the app
writes its own rows. Colors and spacing come from `ShipglowsTheme`.

```dart
DateSectionsView<Invoice>(
  groups: groupByDate(
    invoices,
    dateOf: (invoice) => invoice.paidAt,
    now: now,
    strings: DateStrings.fr,
  ),
  itemBuilder: (context, invoice) => InvoiceRow(invoice),
  empty: const Text('Rien ici pour l’instant.'),
)
```

- `DateSectionsView`: ready scroll view with an optional `header` and an `empty`
  widget shown when no section has an item.
- `SliverDateSections`: the same rows inside your own `CustomScrollView`.
- `headingBuilder` replaces the default heading.

## Filtering by period

```dart
DatePeriod? period;

DatePeriodFilter(
  value: period,
  onChanged: (next) => setState(() => period = next),
  strings: DateStrings.fr,
)

final span = period?.spanAt(now);
final shown = span == null
    ? invoices
    : invoices.where((invoice) => span.contains(invoice.paidAt));
```

Chips: Tout, Aujourd’hui, Hier, 7 derniers jours, 30 derniers jours, Ce mois-ci,
Cette année, Personnalisé. Personnalisé opens Flutter's date range picker, which
needs the app's `MaterialLocalizations`; it then shows the chosen dates, and
another tap changes them. `periods`, `showAll`, `allLast`, `showCustom`, `firstDate` and
`lastDate` adjust the choices.

## With a timeline

`shipglows_timeline` draws its own groups; hand it the result:

```dart
TimelineView(
  groups: [
    for (final group in groupByDate(notes, dateOf: (n) => n.date, now: now, strings: DateStrings.fr))
      TimelineGroup(
        id: group.id,
        title: group.title,
        entries: [for (final note in group.items) note.toEntry()],
      ),
  ],
)
```

For that, depend on `shipglows_date_groups` alone.
