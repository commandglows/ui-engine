import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'strings.dart';

/// Below this width a [MetricBarList] stacks each label above its bar, even
/// when it has a [MetricBarList.labelWidth].
const double _sideBySideMinWidth = 480;

/// Narrowest value column, so that short and long values still line up.
const double _valueMinWidth = 56;

/// One row of a [MetricBarList]: a [label], a [value] and the text shown for
/// it. Read as « Blog articles, 12 ».
@immutable
class MetricBarItem {
  /// Creates a row. [value] must be a finite number, zero or more.
  const MetricBarItem({
    required this.label,
    required this.value,
    this.valueLabel,
    this.color,
    this.subtitle,
    this.onTap,
  }) : assert(
         value >= 0 && value < double.infinity,
         'value must be finite and zero or more',
       );

  /// Name of the row, shown on one line.
  final String label;

  /// Amount the bar draws, relative to the list's maximum. Zero or more.
  final double value;

  /// Text shown on the right, already formatted by the app. Defaults to the
  /// value without decimals when it is whole, with one decimal otherwise.
  final String? valueLabel;

  /// Color of the filled part. Defaults to [ShipglowsTheme.accent].
  final Color? color;

  /// Muted second line under the label.
  final String? subtitle;

  /// Makes the row a button that runs this callback when tapped.
  final VoidCallback? onTap;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetricBarItem &&
          other.label == label &&
          other.value == value &&
          other.valueLabel == valueLabel &&
          other.color == color &&
          other.subtitle == subtitle &&
          other.onTap == onTap);

  @override
  int get hashCode =>
      Object.hash(label, value, valueLabel, color, subtitle, onTap);
}

/// A list of labelled horizontal bars, each with its value: a pipeline
/// funnel, content by type, top pages. Each row is one node read as
/// « label, value ». The bars are relative to [maxValue].
class MetricBarList extends StatelessWidget {
  /// Creates the list. Every option has a default that suits a plain list.
  const MetricBarList({
    super.key,
    required this.items,
    this.maxValue,
    this.maxItems,
    this.sort = false,
    this.barHeight = 8,
    this.labelWidth,
    this.emptyMessage,
  }) : assert(barHeight > 0),
       assert(maxItems == null || maxItems >= 0),
       assert(labelWidth == null || labelWidth > 0);

  /// The rows, in app order unless [sort] is set.
  final List<MetricBarItem> items;

  /// The value that fills a bar. Defaults to the largest [MetricBarItem.value]
  /// of [items]. A zero or unknown maximum draws empty bars.
  final double? maxValue;

  /// Shows at most this many rows; the others are hidden. Null shows all.
  final int? maxItems;

  /// Sorts the rows by value, largest first. Rows with equal values keep their
  /// app order.
  final bool sort;

  /// Height of each bar.
  final double barHeight;

  /// Width of a fixed label column left of each bar, used when the list is at
  /// least 480 wide. Null keeps each label above its bar.
  final double? labelWidth;

  /// Text shown, muted, when [items] is empty. Defaults to
  /// [MetricStrings.noData].
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final texts = MetricStrings.of(context);
    if (items.isEmpty) {
      return Semantics(
        container: true,
        child: Text(
          emptyMessage ?? texts.noData,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: theme.textMuted),
        ),
      );
    }
    final rows = _visibleItems();
    final scale = maxValue ?? _largestValue(items);
    final animate = !MediaQuery.disableAnimationsOf(context);
    return Semantics(
      container: true,
      child: LayoutBuilder(
        builder: (_, constraints) {
          final sideWidth =
              labelWidth != null && constraints.maxWidth >= _sideBySideMinWidth
              ? labelWidth
              : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, item) in rows.indexed) ...[
                if (i > 0) SizedBox(height: theme.spaceSm),
                _BarRow(
                  item: item,
                  valueLabel:
                      item.valueLabel ?? _defaultValueLabel(item.value, texts),
                  fraction: _fractionOf(item.value, scale),
                  barHeight: barHeight,
                  labelWidth: sideWidth,
                  animate: animate,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  /// The rows to draw: sorted when [sort] is set, cut to [maxItems].
  List<MetricBarItem> _visibleItems() {
    final order = [for (var i = 0; i < items.length; i++) i];
    if (sort) {
      order.sort((a, b) {
        final byValue = items[b].value.compareTo(items[a].value);
        return byValue != 0 ? byValue : a.compareTo(b);
      });
    }
    final limit = maxItems;
    final Iterable<int> kept = limit == null ? order : order.take(limit);
    return [for (final i in kept) items[i]];
  }
}

/// The largest value of [items], or zero when there are none.
double _largestValue(List<MetricBarItem> items) {
  var largest = 0.0;
  for (final item in items) {
    if (item.value > largest) largest = item.value;
  }
  return largest;
}

/// The share of [scale] that [value] fills, from 0 to 1. A zero or unknown
/// scale fills nothing, so it never divides by zero.
double _fractionOf(double value, double scale) {
  if (scale <= 0 || !scale.isFinite) return 0;
  return (value / scale).clamp(0.0, 1.0).toDouble();
}

/// The value without decimals when whole, else one decimal in the app's
/// decimal separator.
String _defaultValueLabel(double value, MetricStrings texts) =>
    value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toStringAsFixed(1).replaceFirst('.', texts.decimalSeparator);

/// One row: label, bar and value, in a stacked or a side-by-side layout.
class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.item,
    required this.valueLabel,
    required this.fraction,
    required this.barHeight,
    required this.labelWidth,
    required this.animate,
  });

  final MetricBarItem item;
  final String valueLabel;

  /// Share of the track to fill, from 0 to 1.
  final double fraction;
  final double barHeight;

  /// Width of the label column, or null when the label stacks above the bar.
  final double? labelWidth;

  /// False when the platform asks for reduced motion: the bar jumps.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final color = item.color ?? theme.accent;
    final subtitle = item.subtitle;
    final onTap = item.onTap;

    final label = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: textTheme.bodyMedium?.copyWith(color: theme.text),
        ),
        if (subtitle != null)
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(color: theme.textMuted),
          ),
      ],
    );
    final valueText = Text(
      valueLabel,
      textAlign: TextAlign.end,
      style: textTheme.labelLarge?.copyWith(
        color: theme.text,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
    final track = animate
        ? TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: fraction),
            duration: theme.motionNormal,
            builder: (_, shown, _) => _track(theme, color, shown),
          )
        : _track(theme, color, fraction);
    final bar = ExcludeSemantics(
      child: SizedBox(height: barHeight, child: track),
    );

    final width = labelWidth;
    final Widget layout = width == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(child: label),
                  SizedBox(width: theme.spaceSm),
                  valueText,
                ],
              ),
              SizedBox(height: theme.spaceXs),
              bar,
            ],
          )
        : Row(
            children: [
              SizedBox(width: width, child: label),
              SizedBox(width: theme.spaceSm),
              Expanded(child: bar),
              SizedBox(width: theme.spaceSm),
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: _valueMinWidth),
                child: valueText,
              ),
            ],
          );

    final Widget body = onTap == null
        ? layout
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(theme.radiusSm),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: theme.controlMinHeight),
                child: layout,
              ),
            ),
          );

    return Semantics(
      label: [item.label, valueLabel, ?subtitle].join(', '),
      button: onTap != null,
      excludeSemantics: true,
      child: body,
    );
  }

  /// The track: a rounded strip in [ShipglowsTheme.border] with [color] filling
  /// [shown] of its width from the start edge.
  Widget _track(ShipglowsTheme theme, Color color, double shown) =>
      DecoratedBox(
        decoration: BoxDecoration(
          color: theme.border,
          borderRadius: BorderRadius.circular(theme.radiusSm),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(theme.radiusSm),
          child: FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: shown,
            heightFactor: 1,
            child: ColoredBox(color: color),
          ),
        ),
      );
}
