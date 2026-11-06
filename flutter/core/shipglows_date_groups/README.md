# shipglows_date_groups

Sorts anything by date and cuts it into sections: « Aujourd’hui », « Hier »,
« Il y a une semaine », months, or periods of your own. Pure Dart, French and
English. To draw the sections and a period filter, see
`shipglows_date_sections`.

```dart
final groups = groupByDate(
  invoices,
  dateOf: (invoice) => invoice.paidAt, // null goes under « Sans date »
  now: DateTime.now(),
  strings: DateStrings.fr,
);
for (final group in groups) {
  print('${group.title}: ${group.items.length}');
}
```

By default: À venir, Aujourd’hui, Hier, 7 derniers jours, Il y a une semaine,
Il y a deux semaines, Il y a trois semaines, then one group per month. Empty
groups are left out.

## Adapting to the density

`groupByDensity()` picks the headings from what there is. A quiet history reads
Aujourd’hui, Hier, 7 derniers jours, Il y a quelques semaines, Plus ancien. A
section holding more than `maxPerGroup` items is cut further: today into hours
(« Il y a moins de 3 h », « Il y a 5 h »), yesterday into morning, afternoon and
evening, the week into days (« Mardi 3 novembre »), older into years, months and
days.

```dart
final groups = groupByDensity(
  items,
  dateOf: (item) => item.date,
  now: DateTime.now(),
  strings: DateStrings.fr,
  maxPerGroup: 3,
);
```

Neighbouring hours are joined until each group holds `minPerGroup` items, so a
busy day does not turn into one heading per row. Headings about hours age: refresh
`now` every minute while the list stays on screen.

## Choosing the sections

```dart
groupByDate(
  items,
  dateOf: (item) => item.date,
  now: now,
  strings: DateStrings.en,
  periods: [
    DatePeriod.today,
    DatePeriod.thisWeek(firstWeekday: DateTime.sunday),
    DatePeriod.lastMonth,
    DatePeriod.daysAgo(from: 31, to: 90, title: 'This quarter or so'),
    DatePeriod.custom(
      id: 'school-year',
      title: 'School year',
      span: (today) => DateSpan(first: DateTime(today.year, 9), last: today),
    ),
  ],
  rest: DateRest.years, // or months, or single: « Older »
  newestFirst: false,
);
```

An item goes to the **first** period that contains it, so order the periods from
the most to the least precise.

## Filtering

A period also filters: resolve it once, then test each item.

```dart
final span = DatePeriod.last30Days.spanAt(now);
final recent = items.where((item) => span.contains(item.date));
```

`DatePeriod.range(DateSpan(first: start, last: end))` holds dates the person
chose; its title reads « Du 3 novembre au 7 novembre 2026 ».

`DatePeriod.lastHour` counts back from the clock, to the minute, instead of in
whole days.

## Days are calendar days

« Hier » means the previous calendar day, not 24 hours ago, and a daylight saving
change never shifts a day. A UTC value is an instant, shown on the device's
calendar. A date stored without a time must be passed as a local
`DateTime(year, month, day)`, or `DateTime.utc(2026, 11, 6)` could land on the
5th in Montréal.

`now` is always passed in. Keep one value per screen and refresh it when the day
changes, so a list left open overnight moves on.
