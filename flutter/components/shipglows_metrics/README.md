# shipglows_metrics

Metrics dashboards: the same tiles, trends and layout in every app. Only
draws: the app fetches, computes and formats its values (currency, units,
locale) and hands them over. Depends on `shipglows_theme` and
`shipglows_icons`.

- `Metric(label:, value:, delta:, series:, caption:)`: one value, already
  formatted (« 1 240 € »), its change and its recent values, oldest first.
- `MetricDelta(0.12, polarity:, label:)`: the change as a fraction.
  `MetricPolarity.higherIsBetter` (default), `lowerIsBetter` (load time,
  churn) or `neutral` decides the color; under `flatThreshold` (0.5 %) it
  counts as unchanged. `label` replaces the default « +12 % ».
- `MetricTile(metric, onTap:)`: label, value in `fontDisplay` with tabular
  figures, `MetricDeltaBadge`, caption and sparkline on `surfaceRaised` with
  a `border` outline. Read as one sentence (« Revenue, 1 240 €, up 12 %,
  vs. last week »). `MetricTile.loading(label:)`, `.empty(label:, message:)`
  and `.error(label:, message:, onRetry:)` keep the label and the value
  line's height, so the dashboard does not jump when data arrives. Every
  state takes an optional `icon:` before the label (decorative, in `icon`
  or the app's own `iconColor:`; the value stays in `text`). ContentGlows'
  Search Console cards use it.
- `MetricDeltaBadge(delta)`: arrow and signed text in a pill, `success` when
  good, `danger` when bad, `textMuted` when neither, so the trend never
  rests on color alone. New base icons `trendUp`, `trendDown`, `trendFlat`.
- `MetricSparkline(values, color:)`: a small line with a faint area under
  it, decorative (no semantics); nothing under two values. In a tile it
  takes the badge's color.
- `MetricGrid(children:, minTileWidth: 220, maxColumns: 4)`: equal columns,
  as many as fit, the tiles of a row as tall as the tallest; one column on a
  phone. Its children must not use `LayoutBuilder` (rows are measured with
  `IntrinsicHeight`).
- `MetricSection(title:, trailing:, child:)`: a heading, a control on its
  right (under it below 480 wide), then the grid.
- `MetricPeriodSelector(periods: [MetricPeriod(value, '7 j'), …], selected:,
  onChanged:)`: the periods as a segmented button, `highlight` on the
  selected one.
- `MetricDelta.between(current, previous)`: the change computed, never
  NaN; from 0 it reads +100 % (or −100 %, or 0 when both are 0).
- `Metric(points: [MetricPoint(day, value), …])`: dated values drawn by
  `MetricSparkline.points`, spaced by date; a null value is a gap that
  breaks the line. Hover or touch shows the nearest point (`describe:` for
  its text). Takes precedence over `series`.
- `MetricTile(…, density: MetricTileDensity.compact)`: smaller padding,
  value and sparkline, no caption on screen (still read).
- `MetricBarList(items: [MetricBarItem(label:, value:, valueLabel:)], …)`:
  labelled horizontal bars (a funnel, content by type, top pages);
  `labelWidth:` puts labels in a column from 480 wide, `sort:`, `maxItems:`,
  `maxValue:`; rows with `onTap` are buttons. Tracks in `border`.
- `MetricProgressBar(target: MetricTarget(value: 3, target: 5))` and
  `MetricProgressTile(label:, target:, caption:)`: « 3 of 5 », the fill turns
  `success` once reached.
- `MetricSection(subtitle:, freshness: MetricFreshness(source:, updatedAt:,
  stale:, partial:))`: a muted line « Google Search Console · Updated 2 h
  ago » with « Stale » and « Partial data » badges (`MetricFreshnessLine`
  alone elsewhere).
- `MetricFormat.of(context)`: `integer` (« 1 240 »), `decimal`, `compact`
  (« 1.2k », « 2,5M »), `percent(signed:)` and `duration` (« 2 min 5 s »),
  with the separators, minus sign and units of `MetricStrings`.
- `MetricStrings.en`, `.fr` (picked from the app locale) or the app's own;
  `MetricStringsScope` in `MaterialApp.builder` for the whole app.

```dart
MetricSection(
  title: 'Activité',
  trailing: MetricPeriodSelector(
    periods: const [MetricPeriod(7, '7 j'), MetricPeriod(30, '30 j')],
    selected: days,
    onChanged: setDays,
  ),
  child: MetricGrid(children: [
    MetricTile(Metric(
      label: 'Revenus',
      value: '1 240 €',
      delta: const MetricDelta(0.12),
      series: revenueByDay,
      caption: 'vs. 7 jours précédents',
    )),
    const MetricTile(Metric(
      label: 'Temps de chargement',
      value: '1,2 s',
      delta: MetricDelta(-0.08, polarity: MetricPolarity.lowerIsBetter),
    )),
    const MetricTile.loading(label: 'Utilisateurs actifs'),
  ]),
)
```
