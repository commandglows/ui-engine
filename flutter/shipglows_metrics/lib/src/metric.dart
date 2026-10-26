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

  /// The change as a fraction: 0.12 for +12 %, -0.3 for -30 %.
  final double ratio;

  /// The text shown, formatted by the app (« +340 », « +1,2 pt »); defaults
  /// to [ratio] as a signed percentage.
  final String? label;

  final MetricPolarity polarity;

  /// Under this absolute [ratio], the value counts as unchanged.
  final double flatThreshold;

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

/// One value of a dashboard, already formatted by the app.
@immutable
class Metric {
  const Metric({
    required this.label,
    required this.value,
    this.delta,
    this.series = const [],
    this.caption,
  });

  /// What is measured: « Revenue », « Active users ».
  final String label;

  /// The value as shown: « 1 240 € », « 98,2 % ».
  final String value;

  /// The change against the previous period; no badge without it.
  final MetricDelta? delta;

  /// Recent values, oldest first, drawn as a sparkline; none under two.
  final List<double> series;

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
      other.caption == caption;

  @override
  int get hashCode =>
      Object.hash(label, value, delta, Object.hashAll(series), caption);
}
