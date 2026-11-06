/// Metrics dashboards for ShipGlows Flutter apps: the same tiles, trends and
/// layout everywhere, fed by each app's own data.
///
/// The package only draws. The app fetches, computes and formats its values
/// (currency, units, locale), then hands them over as a [Metric].
///
/// - [Metric] and [MetricDelta]: one value, its change and its recent
///   series; [MetricPolarity] says whether up is good;
///   [MetricDelta.between] computes the change; [MetricPoint] dates a value
///   (null for a gap).
/// - [MetricTile]: a value with its label, change badge and sparkline, plus
///   its loading, empty and error states.
/// - [MetricDeltaBadge]: the change alone, arrow and sign, green when good,
///   red when bad.
/// - [MetricSparkline]: the recent series as a small line;
///   [MetricSparkline.points] spaces dated points, breaks at gaps and shows
///   a point on hover.
/// - [MetricBarList]: labelled horizontal bars (a funnel, top pages).
/// - [MetricProgressBar] and [MetricProgressTile]: progress toward a
///   [MetricTarget] (« 3 of 5 »).
/// - [MetricFreshness] and [MetricFreshnessLine]: source, « Updated 2 h
///   ago », stale and partial badges.
/// - [MetricFormat]: integers, decimals, compact numbers (« 1.2k »),
///   percentages and durations in the app's language.
/// - [MetricGrid]: tiles in as many equal columns as the width allows.
/// - [MetricSection]: a titled group of tiles, with a [MetricPeriodSelector]
///   or any other control on the right.
/// - [MetricStrings] and [MetricStringsScope]: the app's texts.
library;

export 'src/bar_list.dart';
export 'src/delta_badge.dart';
export 'src/format.dart';
export 'src/freshness.dart';
export 'src/grid.dart';
export 'src/metric.dart';
export 'src/period_selector.dart';
export 'src/progress.dart';
export 'src/section.dart';
export 'src/sparkline.dart';
export 'src/strings.dart';
export 'src/tile.dart';
