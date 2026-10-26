import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// One period a dashboard can show: the app's own [value] (an enum, a
/// `Duration`) and its short [label] (« 7 j », « 30 j », « 12 mois »).
@immutable
class MetricPeriod<T> {
  const MetricPeriod(this.value, this.label);

  final T value;
  final String label;
}

/// The periods side by side, the [selected] one highlighted.
class MetricPeriodSelector<T> extends StatelessWidget {
  const MetricPeriodSelector({
    super.key,
    required this.periods,
    required this.selected,
    required this.onChanged,
  });

  final List<MetricPeriod<T>> periods;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    return SegmentedButton<T>(
      segments: [
        for (final period in periods)
          ButtonSegment<T>(value: period.value, label: Text(period.label)),
      ],
      selected: {selected},
      showSelectedIcon: false,
      onSelectionChanged: (values) => onChanged(values.first),
      style: SegmentedButton.styleFrom(
        foregroundColor: theme.textMuted,
        selectedForegroundColor: theme.onHighlight,
        selectedBackgroundColor: theme.highlight,
        side: BorderSide(color: theme.border, width: theme.lineWidth),
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
