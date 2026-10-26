import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'dates.dart';
import 'metrics.dart';
import 'strings.dart';

/// A small month for a side panel: tap a day to go to it. The day in view
/// is highlighted, today is in the accent color.
class CalendarMiniMonth extends StatelessWidget {
  const CalendarMiniMonth({
    super.key,
    required this.date,
    required this.onDateChanged,
    this.today,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  /// Day in view; its month is shown.
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final DateTime? today;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final range = CalendarRange.of(CalendarView.month, date);
    return Column(
      children: [
        Text(strings.month(date), style: theme.textTheme.titleSmall),
        ExcludeSemantics(
          child: Row(
            children: [
              for (final name in strings.weekdays)
                Expanded(child: Center(child: Text(name.substring(0, 1)))),
            ],
          ),
        ),
        for (var row = 0; row < 6; row++)
          Row(
            children: [
              for (var column = 0; column < 7; column++)
                Expanded(
                  child: SizedBox(
                    height: metrics.miniCellHeight,
                    child: _day(
                      context,
                      calendarAddDays(range.start, row * 7 + column),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  Widget _day(BuildContext context, DateTime day) {
    final roles = ShipglowsTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final isToday = today != null && calendarSameDay(day, today!);
    return Semantics(
      label: strings.longDate(day),
      selected: calendarSameDay(day, date),
      excludeSemantics: true,
      button: true,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: calendarSameDay(day, date)
              ? scheme.primaryContainer
              : null,
        ),
        onPressed: () => onDateChanged(day),
        child: Text(
          '${day.day}',
          style: TextStyle(
            fontWeight: isToday ? FontWeight.w700 : null,
            color: isToday
                ? roles.accent
                : day.month == date.month
                ? null
                : roles.textMuted,
          ),
        ),
      ),
    );
  }
}
