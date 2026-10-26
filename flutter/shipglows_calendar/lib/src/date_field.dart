import 'dart:math' as math;

import 'package:flutter/cupertino.dart' show CupertinoPicker;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import 'dates.dart';
import 'strings.dart';

/// A form field holding a date, set by rolling one wheel per part (day,
/// month, year, and hour and minute with [withTime]) instead of typing. Its
/// calendar icon opens the date picker instead. Its value is a civil day at
/// UTC midnight like [calendarDay], or the wall time on UTC fields.
/// [quickPicks] offers chips under it: tomorrow, in a week, in 3 hours…
class CalendarDateField extends StatefulWidget {
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

  /// Date shown; null dims the wheels on [initialDate] until one is rolled.
  final DateTime? value;
  final ValueChanged<DateTime> onChanged;
  final bool withTime;
  final bool enabled;
  final bool quickPicks;

  /// Now in the calendar's zone, as a wall time on UTC fields, which the
  /// quick picks count from; the device's local time by default.
  final DateTime? now;
  final String? helperText;

  /// Day shown without a [value]; today by default.
  final DateTime? initialDate;
  final DateTime? firstDate;
  final DateTime? lastDate;

  /// Base decoration, given the label, helper text and calendar icon.
  final InputDecoration decoration;
  final CalendarStrings strings;

  @override
  State<CalendarDateField> createState() => _CalendarDateFieldState();
}

class _CalendarDateFieldState extends State<CalendarDateField> {
  static const _itemExtent = 32.0;
  static const _rows = 3;

  late int _day, _month, _year, _hour, _minute;
  late FixedExtentScrollController _days, _months, _years, _hours, _minutes;

  /// Wheels moved by the app rather than the user: their stops are not
  /// choices. The run tells apart overlapping moves.
  bool _syncing = false;
  int _run = 0;

  DateTime get _first => widget.firstDate ?? DateTime(1900);
  DateTime get _last => widget.lastDate ?? DateTime(9999, 12, 30);

  static int _daysIn(int year, int month) => DateTime.utc(year, month + 1, 0).day;

  /// The date the wheels show, the day kept within its month.
  DateTime get _shown => DateTime.utc(
    _year,
    _month,
    math.min(_day, _daysIn(_year, _month)),
    widget.withTime ? _hour : 0,
    widget.withTime ? _minute : 0,
  );

  DateTime _normalize(DateTime value) => DateTime.utc(
    value.year,
    value.month,
    value.day,
    widget.withTime ? value.hour : 0,
    widget.withTime ? value.minute : 0,
  );

  void _set(DateTime value) {
    _day = value.day;
    _month = value.month;
    _year = value.year.clamp(_first.year, _last.year);
    _hour = value.hour;
    _minute = value.minute;
  }

  DateTime _fallback() {
    final start = widget.initialDate ?? widget.now ?? DateTime.now();
    return DateTime.utc(start.year, start.month, start.day, 9);
  }

  @override
  void initState() {
    super.initState();
    _set(widget.value ?? _fallback());
    _days = FixedExtentScrollController(initialItem: _day - 1);
    _months = FixedExtentScrollController(initialItem: _month - 1);
    _years = FixedExtentScrollController(initialItem: _year - _first.year);
    _hours = FixedExtentScrollController(initialItem: _hour);
    _minutes = FixedExtentScrollController(initialItem: _minute);
  }

  @override
  void didUpdateWidget(CalendarDateField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final target = widget.value;
    if (widget.withTime && !oldWidget.withTime) {
      // The time wheels were not shown: start them afresh on the new time.
      if (target != null) _set(target);
      _hours.dispose();
      _minutes.dispose();
      _hours = FixedExtentScrollController(initialItem: _hour);
      _minutes = FixedExtentScrollController(initialItem: _minute);
    }
    if (target != null && _normalize(target) != _shown) _roll(target);
  }

  @override
  void dispose() {
    for (final controller in [_days, _months, _years, _hours, _minutes]) {
      controller.dispose();
    }
    super.dispose();
  }

  /// Rolls [controller] to [target], the short way round when [count] items
  /// loop.
  Future<void> _move(
    FixedExtentScrollController controller,
    int target, {
    int? count,
  }) {
    if (!controller.hasClients) return Future.value();
    final raw = controller.selectedItem;
    var to = target;
    if (count != null) {
      var diff = target - raw % count;
      if (diff > count ~/ 2) diff -= count;
      if (diff < -(count ~/ 2)) diff += count;
      to = raw + diff;
    }
    if (to == raw) return Future.value();
    return controller.animateToItem(
      to,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  /// Rolls every wheel to [target] after this frame, like a slot machine
  /// stopping. Callers rebuild: from build-time hooks, or with setState.
  void _roll(DateTime target) {
    _set(target);
    _syncing = true;
    final run = ++_run;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || run != _run) return;
      await Future.wait([
        _move(_days, _day - 1, count: 31),
        _move(_months, _month - 1, count: 12),
        _move(_years, _year - _first.year),
        if (widget.withTime) ...[
          _move(_hours, _hour, count: 24),
          _move(_minutes, _minute, count: 60),
        ],
      ]);
      if (mounted && run == _run) _syncing = false;
    });
  }

  /// A wheel came to rest: the date it shows is the choice.
  void _settle() {
    if (_syncing) return;
    final shown = _shown;
    // A 31 on a 30-day month rolls back to the month's last day.
    if (_day > shown.day) setState(() => _roll(shown));
    final value = widget.value;
    if (value == null || _normalize(value) != shown) widget.onChanged(shown);
  }

  Future<void> _pick() async {
    final first = _first;
    final last = _last;
    final start = widget.value ?? _shown;
    var initial = DateTime(start.year, start.month, start.day);
    if (initial.isBefore(first)) initial = first;
    if (initial.isAfter(last)) initial = last;
    final day = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: widget.label,
    );
    if (day == null || !mounted) return;
    if (!widget.withTime) {
      widget.onChanged(calendarDay(day));
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (time == null) return;
    widget.onChanged(
      DateTime.utc(day.year, day.month, day.day, time.hour, time.minute),
    );
  }

  /// Each quick pick: its label and the date it gives.
  List<(String, DateTime)> _picks() {
    final strings = widget.strings;
    final local = widget.now ?? DateTime.now();
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
    if (widget.withTime) {
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
    if (!widget.quickPicks) return _field(context);
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
                onPressed: widget.enabled ? () => widget.onChanged(date) : null,
              ),
          ],
        ),
      ],
    );
  }

  Widget _wheel({
    required String label,
    required FixedExtentScrollController controller,
    required int count,
    required String Function(int index) text,
    required ValueChanged<int> onSelected,
    bool looping = true,
    bool Function(int index)? dimmed,
    int flex = 2,
  }) {
    final style = Theme.of(context).textTheme.bodyLarge;
    Widget item(int index) => Center(
      child: Text(
        text(index),
        style: dimmed?.call(index) ?? false
            ? style?.copyWith(color: Theme.of(context).disabledColor)
            : style,
      ),
    );
    void changed(int index) {
      if (!_syncing) setState(() => onSelected(index % count));
    }

    return Expanded(
      flex: flex,
      child: Semantics(
        label: label,
        child: looping
            ? CupertinoPicker(
                scrollController: controller,
                itemExtent: _itemExtent,
                looping: true,
                onSelectedItemChanged: changed,
                children: [for (var i = 0; i < count; i++) item(i)],
              )
            : CupertinoPicker.builder(
                scrollController: controller,
                itemExtent: _itemExtent,
                childCount: count,
                onSelectedItemChanged: changed,
                itemBuilder: (_, index) => item(index),
              ),
      ),
    );
  }

  Widget _field(BuildContext context) {
    final strings = widget.strings;
    String two(int value) => value.toString().padLeft(2, '0');
    final day = _wheel(
      label: strings.wheelDay,
      controller: _days,
      count: 31,
      text: (index) => '${index + 1}',
      dimmed: (index) => index + 1 > _daysIn(_year, _month),
      onSelected: (index) => _day = index + 1,
    );
    final month = _wheel(
      label: strings.wheelMonth,
      controller: _months,
      count: 12,
      flex: 3,
      text: (index) => strings.monthsShort[index],
      onSelected: (index) => _month = index + 1,
    );
    final year = _wheel(
      label: strings.wheelYear,
      controller: _years,
      count: _last.year - _first.year + 1,
      looping: false,
      flex: 3,
      text: (index) => '${_first.year + index}',
      onSelected: (index) => _year = _first.year + index,
    );
    final french = strings.languageCode == 'fr';
    return InputDecorator(
      isEmpty: false,
      decoration: widget.decoration.copyWith(
        labelText: widget.label,
        helperText: widget.helperText,
        enabled: widget.enabled,
        suffixIcon: IconButton(
          tooltip: strings.chooseDate,
          onPressed: widget.enabled ? _pick : null,
          icon: Icon(
            widget.withTime
                ? Icons.edit_calendar_outlined
                : Icons.calendar_today,
          ),
        ),
      ),
      child: SizedBox(
        height: _itemExtent * _rows,
        child: Opacity(
          opacity: widget.value == null ? 0.5 : 1,
          child: IgnorePointer(
            ignoring: !widget.enabled,
            // Desktop mice drag the wheels too, not only touch.
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(
                context,
              ).copyWith(dragDevices: PointerDeviceKind.values.toSet()),
              child: NotificationListener<ScrollEndNotification>(
                onNotification: (_) {
                  _settle();
                  return false;
                },
                child: Row(
                  children: [
                    ...french ? [day, month] : [month, day],
                    year,
                    if (widget.withTime) ...[
                      const SizedBox(width: 12),
                      _wheel(
                        label: strings.wheelHour,
                        controller: _hours,
                        count: 24,
                        text: two,
                        onSelected: (index) => _hour = index,
                      ),
                      _wheel(
                        label: strings.wheelMinute,
                        controller: _minutes,
                        count: 60,
                        text: two,
                        onSelected: (index) => _minute = index,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
