import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shipglows_date_groups/shipglows_date_groups.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

/// A wrap of chips to pick one period: everything, a named period, or dates
/// chosen in a range picker. The choice is owned by the caller.
class DatePeriodFilter extends StatelessWidget {
  /// Creates a filter.
  const DatePeriodFilter({
    super.key,
    required this.value,
    required this.onChanged,
    required this.strings,
    this.periods,
    this.showAll = true,
    this.showCustom = true,
    this.firstDate,
    this.lastDate,
  });

  /// The current period; null means everything.
  final DatePeriod? value;

  /// Called with the new period; null means everything.
  final ValueChanged<DatePeriod?> onChanged;

  /// Texts of the chips.
  final DateStrings strings;

  /// Named choices, in display order. Defaults to [DatePeriod.filters].
  final List<DatePeriod>? periods;

  /// Whether to offer [DateStrings.all].
  final bool showAll;

  /// Whether to offer [DateStrings.custom], which opens a date range picker.
  final bool showCustom;

  /// Earliest day the range picker offers. Defaults to 1 January 2000.
  final DateTime? firstDate;

  /// Latest day the range picker offers. Defaults to the end of ten years from
  /// now.
  final DateTime? lastDate;

  bool get _isRange => value?.id == DatePeriod.rangeId;

  Future<void> _pickRange(BuildContext context) async {
    final first = firstDate ?? DateTime(2000);
    final last = lastDate ?? DateTime(DateTime.now().year + 10, 12, 31);
    final current = _isRange ? value?.spanAt(DateTime.now()) : null;
    final start = current?.first;
    final end = current?.last;
    final initial =
        start != null &&
            end != null &&
            !start.isBefore(first) &&
            !end.isAfter(last)
        ? DateTimeRange(start: start, end: end)
        : null;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: first,
      lastDate: last,
      initialDateRange: initial,
    );
    if (picked == null) return;
    onChanged(
      DatePeriod.range(DateSpan(first: picked.start, last: picked.end)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShipglowsTheme.of(context);
    final current = value;
    return Wrap(
      spacing: theme.spaceSm,
      runSpacing: theme.spaceSm,
      children: [
        if (showAll)
          _chip(
            theme,
            label: strings.all,
            selected: current == null,
            onTap: () {
              if (current != null) onChanged(null);
            },
          ),
        for (final period in periods ?? DatePeriod.filters)
          _chip(
            theme,
            label: period.titleIn(strings),
            selected: current?.id == period.id,
            onTap: () {
              if (current?.id != period.id) onChanged(period);
            },
          ),
        if (showCustom)
          _chip(
            theme,
            label: _isRange ? current!.titleIn(strings) : strings.custom,
            selected: _isRange,
            onTap: () => unawaited(_pickRange(context)),
          ),
      ],
    );
  }

  Widget _chip(
    ShipglowsTheme theme, {
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      selectedColor: theme.highlight,
      checkmarkColor: theme.onHighlight,
      labelStyle: TextStyle(color: selected ? theme.onHighlight : theme.text),
      onSelected: (_) => onTap(),
    );
  }
}
