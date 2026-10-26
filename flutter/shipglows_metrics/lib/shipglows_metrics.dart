/// Metrics dashboards for ShipGlows Flutter apps: the same tiles, trends and
/// layout everywhere, fed by each app's own data.
///
/// The package only draws. The app fetches, computes and formats its values
/// (currency, units, locale), then hands them over as a [Metric].
///
/// - [Metric] and [MetricDelta]: one value, its change and its recent
///   series; [MetricPolarity] says whether up is good.
/// - [MetricTile]: a value with its label, change badge and sparkline, plus
///   its loading, empty and error states.
/// - [MetricDeltaBadge]: the change alone, arrow and sign, green when good,
///   red when bad.
/// - [MetricSparkline]: the recent series as a small line.
/// - [MetricGrid]: tiles in as many equal columns as the width allows.
/// - [MetricSection]: a titled group of tiles, with a [MetricPeriodSelector]
///   or any other control on the right.
/// - [MetricStrings] and [MetricStringsScope]: the app's texts.
library;

export 'src/delta_badge.dart';
export 'src/grid.dart';
export 'src/metric.dart';
export 'src/period_selector.dart';
export 'src/section.dart';
export 'src/sparkline.dart';
export 'src/strings.dart';
export 'src/tile.dart';
