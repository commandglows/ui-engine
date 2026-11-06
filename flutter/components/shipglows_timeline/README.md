# shipglows_timeline

One vertical thread for entries of different kinds: check-ins, notes, life
events, activity. Only draws: the app adapts its data, chooses the order and
the groups, and writes every string. Colors and spacing come from
`ShipglowsTheme`.

```dart
TimelineView(
  header: const WeeklySummary(),
  empty: const Text('Nothing here yet.'),
  groups: [
    TimelineGroup(
      id: '2026-11',
      title: 'November 2026',
      entries: const [
        TimelineEntry(
          id: 'check-in-1',
          title: 'Friday 6 November',
          subtitle: 'Mood: fine',
          icon: Icons.wb_sunny_outlined,
          tags: ['Calm', 'Work'],
        ),
      ],
    ),
  ],
)
```

- `TimelineEntry(id:, title:, subtitle:, icon:, tags:, semanticLabel:, onTap:)`:
  one row. Without `semanticLabel`, its texts read as one sentence.
- `TimelineGroup(id:, title:, entries:)`: a heading for screen readers, then its
  rows. Groups can mean anything: months, years, sessions.
- `TimelineView`: ready scroll view with an optional `header` and an `empty`
  widget shown when no group has an entry.
- `SliverTimeline`: the same rows inside your own `CustomScrollView`.

Rows are built only near the viewport, so a long history costs little. The rail
mirrors in right-to-left. For a calendar with periods and times, use
`shipglows_calendar`; for a winding map of milestones, `shipglows_journey_map`.
