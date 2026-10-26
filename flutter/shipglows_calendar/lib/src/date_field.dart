import 'package:flutter/material.dart';

import 'dates.dart';
import 'strings.dart';

/// A form field holding a date, picked from a calendar in one tap instead of
/// typed. [withTime] then asks for the time too. Its value is a civil day at
/// UTC midnight like [calendarDay], or the wall time on UTC fields.
class CalendarDateField extends StatelessWidget {
  const CalendarDateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.withTime = false,
    this.enabled = true,
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

  @override
  Widget build(BuildContext context) {
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
