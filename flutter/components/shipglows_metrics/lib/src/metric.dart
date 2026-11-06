import 'package:flutter/foundation.dart';

/// Which way a change is good: more sign-ups is good, a longer load time is
/// bad, a number of open tabs is neither.
enum MetricPolarity { higherIsBetter, lowerIsBetter, neutral }

/// Which way a value moved.
enum MetricDirection { up, down, flat }

/// How a value changed against the previous period.
@immutable
class MetricDelta {
  const MetricDelta(
    this.ratio, {
    this.label,
    this.polarity = MetricPolarity.higherIsBetter,
    this.flatThreshold = 0.005,
  });

  /// The change from [previous] to [current] as a fraction of [previous]:
  /// `(current − previous) / |previous|`, so 120 against 100 is 0.2.
  ///
  /// When [previous] is 0 there is no fraction to take: the ratio is 0 when
  /// [current] is 0 too, +1 (shown as +100 %) when [current] is above 0, and
  /// −1 (−100 %) when it is below 0. Non-finite numbers, and a ratio too large
  /// to be finite, give 0, so the ratio is never NaN or infinite.
  factory MetricDelta.between(
    num current,
    num previous, {
    MetricPolarity polarity = MetricPolarity.higherIsBetter,
    String? label,
  }) {
    final now = current.toDouble();
    final before = previous.toDouble();
    final double ratio;
    if (!now.isFinite || !before.isFinite) {
      ratio = 0;
    } else if (before == 0) {
      ratio = now == 0 ? 0 : (now > 0 ? 1 : -1);
    } else {
      final fraction = (now - before) / before.abs();
      ratio = fraction.isFinite ? fraction : 0;
    }
    return MetricDelta(ratio, label: label, polarity: polarity);
  }

  /// The change as a fraction: 0.12 for +12 %, -0.3 for -30 %.
  final double ratio;

  /// The text shown, formatted by the app (« +340 », « +1,2 pt »); defaults
  /// to [ratio] as a signed percentage.
  final String? label;

  /// Which way the change is good; see [MetricPolarity].
  final MetricPolarity polarity;

  /// Under this absolute [ratio], the value counts as unchanged.
  final double flatThreshold;

  /// Which way the value moved, or [MetricDirection.flat] under
  /// [flatThreshold].
  MetricDirection get direction {
    if (ratio.abs() < flatThreshold) return MetricDirection.flat;
    return ratio > 0 ? MetricDirection.up : MetricDirection.down;
  }

  /// Whether the change is good (true), bad (false) or neither (null).
  bool? get isFavorable => switch (polarity) {
    MetricPolarity.neutral => null,
    MetricPolarity.higherIsBetter => switch (direction) {
      MetricDirection.up => true,
      MetricDirection.down => false,
      MetricDirection.flat => null,
    },
    MetricPolarity.lowerIsBetter => switch (direction) {
      MetricDirection.up => false,
      MetricDirection.down => true,
      MetricDirection.flat => null,
    },
  };

  @override
  bool operator ==(Object other) =>
      other is MetricDelta &&
      other.ratio == ratio &&
      other.label == label &&
      other.polarity == polarity &&
      other.flatThreshold == flatThreshold;

  @override
  int get hashCode => Object.hash(ratio, label, polarity, flatThreshold);
}

/// One dated value of a metric, for a sparkline that is spaced by date.
@immutable
class MetricPoint {
  const MetricPoint(this.at, this.value);

  /// The day, or moment, the value belongs to.
  final DateTime at;

  /// The value. Null means there was no data then: a gap in the line, not a
  /// zero.
  final double? value;

  @override
  bool operator ==(Object other) =>
      other is MetricPoint && other.at == at && other.value == value;

  @override
  int get hashCode => Object.hash(at, value);
}

/// One value of a dashboard, already formatted by the app.
@immutable
class Metric {
  const Metric({
    required this.label,
    required this.value,
    this.delta,
    this.series = const [],
    this.points = const [],
    this.caption,
  });

  /// What is measured: « Revenue », « Active users ».
  final String label;

  /// The value as shown: « 1 240 € », « 98,2 % ».
  final String value;

  /// The change against the previous period; no badge without it.
  final MetricDelta? delta;

  /// Recent values, oldest first, spaced evenly and drawn as a sparkline;
  /// none under two. For simple undated values: when [points] is not empty,
  /// [points] is drawn instead.
  final List<double> series;

  /// Recent dated values, oldest first, drawn as a sparkline spaced by their
  /// date, with a gap wherever a value is null. When this is not empty it is
  /// drawn instead of [series].
  final List<MetricPoint> points;

  /// Under the value, muted: what the change is measured against
  /// (« vs. last 7 days »).
  final String? caption;

  @override
  bool operator ==(Object other) =>
      other is Metric &&
      other.label == label &&
      other.value == value &&
      other.delta == delta &&
      listEquals(other.series, series) &&
      listEquals(other.points, points) &&
      other.caption == caption;

  @override
  int get hashCode => Object.hash(
    label,
    value,
    delta,
    Object.hashAll(series),
    Object.hashAll(points),
    caption,
  );
}
