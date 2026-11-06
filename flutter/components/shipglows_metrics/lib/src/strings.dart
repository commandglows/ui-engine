import 'package:flutter/widgets.dart';

import 'metric.dart';

/// Texts of the metrics: the states of a tile, the words a screen reader
/// says for a change (the arrow and color say it on screen), how numbers,
/// percentages and durations are written, and how fresh the data is. The app picks the language: [en], [fr], or
/// its own values, once for the app with [MetricStringsScope].
@immutable
class MetricStrings {
  const MetricStrings({
    required this.up,
    required this.down,
    required this.flat,
    required this.loading,
    required this.noData,
    required this.retry,
    this.decimalSeparator = '.',
    this.groupSeparator = ',',
    this.percentSuffix = '%',
    this.thousandSuffix = 'k',
    this.millionSuffix = 'M',
    this.billionSuffix = 'B',
    this.secondShort = 's',
    this.minuteShort = 'min',
    this.hourShort = 'h',
    this.dayShort = 'd',
    this.stale = 'Stale',
    this.partial = 'Partial data',
    this.updatedJustNow = 'Updated just now',
    this.updatedAgo = 'Updated {time} ago',
    this.ofTarget = '{value} of {target}',
  });

  /// Spoken before a change: « up 12 % ».
  final String up;
  final String down;
  final String flat;

  /// Spoken while a tile loads.
  final String loading;

  /// Default message of an empty tile.
  final String noData;

  /// Button of a tile whose loading failed.
  final String retry;

  final String decimalSeparator;

  /// Between groups of three digits: « 1,240 », « 1 240 » (narrow no-break
  /// space in French).
  final String groupSeparator;

  /// After the number of a default percentage: « % » in English, a narrow
  /// no-break space and « % » in French.
  final String percentSuffix;

  /// Compact numbers: « 1.2k », « 3.4M », « 2B » (« 2 Md » in French).
  final String thousandSuffix;
  final String millionSuffix;
  final String billionSuffix;

  /// Duration units: « 45 s », « 12 min », « 3 h », « 2 d ».
  final String secondShort;
  final String minuteShort;
  final String hourShort;
  final String dayShort;

  /// Badge of data that was not refreshed on time.
  final String stale;

  /// Badge of data known to be incomplete (the last days still arriving).
  final String partial;

  final String updatedJustNow;

  /// « {time} » is replaced by a duration (« 2 h »).
  final String updatedAgo;

  /// Progress toward a target; « {value} » and « {target} » are replaced.
  final String ofTarget;

  static const en = MetricStrings(
    up: 'up',
    down: 'down',
    flat: 'unchanged',
    loading: 'Loading',
    noData: 'No data yet',
    retry: 'Retry',
  );

  static const fr = MetricStrings(
    up: 'en hausse de',
    down: 'en baisse de',
    flat: 'stable',
    loading: 'Chargement',
    noData: 'Pas encore de données',
    retry: 'Réessayer',
    decimalSeparator: ',',
    groupSeparator: ' ',
    percentSuffix: ' %',
    billionSuffix: ' Md',
    dayShort: 'j',
    stale: 'Données anciennes',
    partial: 'Données partielles',
    updatedJustNow: 'Mis à jour à l’instant',
    updatedAgo: 'Mis à jour il y a {time}',
    ofTarget: '{value} sur {target}',
  );

  /// The [MetricStringsScope] above [context]; without one, [fr] when the
  /// app locale is French, [en] otherwise.
  static MetricStrings of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MetricStringsScope>()
          ?.strings ??
      (Localizations.maybeLocaleOf(context)?.languageCode == 'fr' ? fr : en);

  /// The spoken word of [direction].
  String labelOf(MetricDirection direction) => switch (direction) {
    MetricDirection.up => up,
    MetricDirection.down => down,
    MetricDirection.flat => flat,
  };

  /// [delta]'s own label, else its ratio as a signed percentage with at most
  /// one decimal: « +12 % », « −0,4 % ».
  String formatDelta(MetricDelta delta) {
    final label = delta.label;
    if (label != null) return label;
    // Rounded first, so 0.04 * 100 (4.000…01) reads « 4 », not « 4.0 ».
    final percent = (delta.ratio.abs() * 1000).round() / 10;
    final digits = percent < 10 && percent != percent.roundToDouble() ? 1 : 0;
    final number = percent
        .toStringAsFixed(digits)
        .replaceFirst('.', decimalSeparator);
    final sign = switch (delta.direction) {
      MetricDirection.up => '+',
      MetricDirection.down => '−',
      MetricDirection.flat => '',
    };
    return '$sign$number$percentSuffix';
  }

  MetricStrings copyWith({
    String? up,
    String? down,
    String? flat,
    String? loading,
    String? noData,
    String? retry,
    String? decimalSeparator,
    String? groupSeparator,
    String? percentSuffix,
    String? thousandSuffix,
    String? millionSuffix,
    String? billionSuffix,
    String? secondShort,
    String? minuteShort,
    String? hourShort,
    String? dayShort,
    String? stale,
    String? partial,
    String? updatedJustNow,
    String? updatedAgo,
    String? ofTarget,
  }) => MetricStrings(
    up: up ?? this.up,
    down: down ?? this.down,
    flat: flat ?? this.flat,
    loading: loading ?? this.loading,
    noData: noData ?? this.noData,
    retry: retry ?? this.retry,
    decimalSeparator: decimalSeparator ?? this.decimalSeparator,
    groupSeparator: groupSeparator ?? this.groupSeparator,
    percentSuffix: percentSuffix ?? this.percentSuffix,
    thousandSuffix: thousandSuffix ?? this.thousandSuffix,
    millionSuffix: millionSuffix ?? this.millionSuffix,
    billionSuffix: billionSuffix ?? this.billionSuffix,
    secondShort: secondShort ?? this.secondShort,
    minuteShort: minuteShort ?? this.minuteShort,
    hourShort: hourShort ?? this.hourShort,
    dayShort: dayShort ?? this.dayShort,
    stale: stale ?? this.stale,
    partial: partial ?? this.partial,
    updatedJustNow: updatedJustNow ?? this.updatedJustNow,
    updatedAgo: updatedAgo ?? this.updatedAgo,
    ofTarget: ofTarget ?? this.ofTarget,
  );
}

/// The app's own [MetricStrings] for every metric below it, set once (in
/// `MaterialApp.builder`, say) instead of per tile.
class MetricStringsScope extends InheritedWidget {
  const MetricStringsScope({
    super.key,
    required this.strings,
    required super.child,
  });

  final MetricStrings strings;

  @override
  bool updateShouldNotify(MetricStringsScope oldWidget) =>
      strings != oldWidget.strings;
}
