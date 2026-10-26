import 'package:flutter/material.dart';

import 'dates.dart';
import 'metrics.dart';
import 'strings.dart';

/// Today, previous and next period, the period title (tap to pick a date)
/// and the view switch, wrapping on narrow screens. [actions] follow them.
class CalendarToolbar extends StatelessWidget {
  const CalendarToolbar({
    super.key,
    required this.view,
    required this.date,
    required this.today,
    required this.onDateChanged,
    this.views = CalendarView.values,
    this.onViewChanged,
    this.actions = const [],
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  /// View shown in the switch; previous and next move by its period.
  final CalendarView view;

  /// Day in view.
  final DateTime date;

  /// Today in the calendar's zone.
  final DateTime today;

  final ValueChanged<DateTime> onDateChanged;

  /// Views offered in the switch; one view hides it.
  final List<CalendarView> views;
  final ValueChanged<CalendarView>? onViewChanged;
  final List<Widget> actions;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  Future<void> _pickDate(BuildContext context) async {
    final selected = await showDatePicker(
      context: context,
      initialDate: DateTime(date.year, date.month, date.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(9999, 12, 30),
    );
    if (selected != null) onDateChanged(calendarDay(selected));
  }

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: metrics.gap,
    runSpacing: metrics.gap,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      FilledButton(
        onPressed: () => onDateChanged(calendarDay(today)),
        child: Text(strings.today),
      ),
      IconButton(
        tooltip: strings.previous,
        onPressed: () => onDateChanged(calendarShift(view, date, -1)),
        icon: const Icon(Icons.chevron_left),
      ),
      IconButton(
        tooltip: strings.next,
        onPressed: () => onDateChanged(calendarShift(view, date, 1)),
        icon: const Icon(Icons.chevron_right),
      ),
      Tooltip(
        message: strings.chooseDate,
        child: TextButton(
          onPressed: () => _pickDate(context),
          child: Text(strings.period(view, date)),
        ),
      ),
      if (views.length > 1 && onViewChanged != null)
        SegmentedButton<CalendarView>(
          showSelectedIcon: false,
          selected: {view},
          segments: [
            for (final value in views)
              ButtonSegment(value: value, label: Text(strings.view(value))),
          ],
          onSelectionChanged: (values) => onViewChanged!(values.single),
        ),
      ...actions,
    ],
  );
}
