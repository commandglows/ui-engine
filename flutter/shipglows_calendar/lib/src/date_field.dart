import 'package:flutter/material.dart';

import 'dates.dart';
import 'strings.dart';

/// A form field holding a date, picked from a calendar in one tap instead of
/// typed. [withTime] then asks for the time too. Its value is a civil day at
/// UTC midnight like [calendarDay], or the wall time on UTC fields.
/// [quickPicks] offers chips under it: tomorrow, in a week, in 3 hours…
class CalendarDateField extends StatelessWidget {
  const CalendarDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = false,
    this.enabled = true,
    this.quickPicks = true,
    this.now,
    this.helperText,
    this.initialDate,
    this.firstDate,
    this.lastDate,
    this.decoration = const InputDecoration(),
    this.strings = CalendarStrings.fr,
  });

  final String label;

  /// Date shown; null shows [CalendarStrings.chooseDate].
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool withTime;
  final bool enabled;
  final bool quickPicks;

  /// Now in the calendar's zone, as a wall time on UTC fields, which the
  /// quick picks count from; the device's local time by default.
  final DateTime? now;
  final String? helperText;

  /// Day the picker opens on without a [value]; today by default.
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Base decoration, given the label, helper text and calendar icon.
  final InputDecoration decoration;
  final CalendarStrings strings;

  Future<void> _pick(BuildContext context) async {
    final first = firstDate ?? DateTime(1900);
    final last = lastDate ?? DateTime(9999, 12, 30);
    final start = value ?? initialDate ?? DateTime.now();
    var initial = DateTime(start.year, start.month, start.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: label,
    );
    if (day == null || !context.mounted) return;
    if (!withTime) {
      onChanged(calendarDay(day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: value?.hour ?? 9,
        minute: value?.minute ?? 0,
      ),
    );
    if (time == null) return;
    onChanged(
      DateTime.utc(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  /// Each quick pick: its label and the date it gives.
  List<(String, DateTime)> _picks() {
    final local = now ?? DateTime.now();
    final wall = DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
    );
    final today = calendarDay(wall);
    final inMonth = DateTime.utc(
      today.year,
      today.month + 1,
      today.day.clamp(1, DateTime.utc(today.year, today.month + 2, 0).day),
    );
    DateTime at9(DateTime day) =>
        DateTime.utc(day.year, day.month, day.day, 9);
    String hours(int count) =>
        CalendarStrings.fill(strings.inHours, {'count': count});
    if (withTime) {
      return [
        (hours(1), wall.add(const Duration(hours: 1))),
        (hours(3), wall.add(const Duration(hours: 3))),
        ('${strings.tomorrow} 09:00', at9(calendarAddDays(today, 1))),
        (strings.inWeek, at9(calendarAddDays(today, 7))),
      ];
    }
    return [
      (strings.today, today),
      (strings.tomorrow, calendarAddDays(today, 1)),
      (strings.dayAfterTomorrow, calendarAddDays(today, 2)),
      (strings.inWeek, calendarAddDays(today, 7)),
      (strings.inMonth, inMonth),
    ];
  }

  @override
  Widget build(BuildContext context) {
    if (!quickPicks) return _field(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(context),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (text, date) in _picks())
              ActionChip(
                label: Text(text),
                onPressed: enabled ? () => onChanged(date) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _field(BuildContext context) {
    final date = value;
    final text = date == null
        ? strings.chooseDate
        : withTime
        ? strings.longDateTime(date)
        : strings.longDate(date);
    return Semantics(
      button: true,
      enabled: enabled,
      child: InkWell(
        onTap: enabled ? () => _pick(context) : null,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          isEmpty: false,
          decoration: decoration.copyWith(
            labelText: label,
            helperText: helperText,
            enabled: enabled,
            suffixIcon: Icon(
              withTime ? Icons.edit_calendar_outlined : Icons.calendar_today,
            ),
          ),
          child: Text(
            text,
            style: date == null
                ? TextStyle(color: Theme.of(context).hintColor)
                : null,
          ),
        ),
      ),
    );
  }
}
