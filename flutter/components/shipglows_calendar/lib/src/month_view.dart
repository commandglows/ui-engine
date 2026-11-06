import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'dates.dart';
import 'day_strip.dart';
import 'event.dart';
import 'event_card.dart';
import 'metrics.dart';
import 'strings.dart';
import 'time_zone.dart';

/// One month from Monday. The full view shows six weeks with the events of
/// each day as cards (« +N » past [CalendarMetrics.monthVisibleItems]);
/// [compact] shows only the days of the month with their event count, for
/// phones. Dropping an event on a day moves it there.
class CalendarMonthView extends StatelessWidget {
  const CalendarMonthView({
    super.key,
    required this.date,
    required this.events,
    required this.today,
    this.timeZone = CalendarTimeZone.device,
    this.compact = false,
    this.selectedDay,
    this.selectedEventId,
    this.onDayTap,
    this.onShowDay,
    this.onEventTap,
    this.onEventDoubleTap,
    this.onEventDropped,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  /// Any day of the month shown.
  final DateTime date;
  final List<CalendarEvent> events;
  final DateTime today;
  final CalendarTimeZone timeZone;
  final bool compact;
  final DateTime? selectedDay;
  final String? selectedEventId;

  /// The day number was tapped (the full view usually opens that day).
  final ValueChanged<DateTime>? onDayTap;

  /// « +N » was tapped: show every event of that day.
  final ValueChanged<DateTime>? onShowDay;
  final ValueChanged<CalendarEvent>? onEventTap;
  final ValueChanged<CalendarEvent>? onEventDoubleTap;
  final ValueChanged<CalendarDrop>? onEventDropped;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) =>
      compact ? _compact(context) : _full(context);

  Widget _weekdayRow(BuildContext context, {required bool initials}) =>
      ExcludeSemantics(
        child: Row(
          children: [
            for (final name in strings.weekdays)
              Expanded(
                child: Text(
                  initials ? name.substring(0, 1) : name,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ShipglowsTheme.of(context).textMuted,
                  ),
                ),
              ),
          ],
        ),
      );

  Widget _compact(BuildContext context) {
    final roles = ShipglowsTheme.of(context);
    final range = CalendarRange.month(date);
    final leading = range.start.weekday - DateTime.monday;
    final cells = ((leading + range.days + 6) ~/ 7) * 7;
    return Column(
      children: [
        _weekdayRow(context, initials: true),
        SizedBox(height: roles.spaceXs),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: metrics.compactCellHeight,
            crossAxisSpacing: roles.spaceXs,
            mainAxisSpacing: roles.spaceXs,
          ),
          itemCount: cells,
          itemBuilder: (context, index) {
            final offset = index - leading;
            if (offset < 0 || offset >= range.days) {
              return const SizedBox.shrink();
            }
            final day = calendarAddDays(range.start, offset);
            return CalendarDayCell(
              day: day,
              label: '${day.day}',
              events: events,
              today: today,
              timeZone: timeZone,
              selected:
                  selectedDay != null && calendarSameDay(selectedDay!, day),
              onTap: onDayTap,
              onEventDropped: onEventDropped,
              strings: strings,
              metrics: metrics,
            );
          },
        ),
      ],
    );
  }

  Widget _full(BuildContext context) {
    final range = CalendarRange.of(CalendarView.month, date);
    return Column(
      children: [
        _weekdayRow(context, initials: false),
        SizedBox(height: metrics.collisionGap),
        for (var row = 0; row < range.days ~/ 7; row++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var column = 0; column < 7; column++)
                  Expanded(
                    child: _cell(
                      context,
                      calendarAddDays(range.start, row * 7 + column),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _cell(BuildContext context, DateTime day) {
    final theme = Theme.of(context);
    final roles = ShipglowsTheme.of(context);
    final segments = calendarSegmentsOn(events, day, timeZone);
    final isToday = calendarSameDay(day, today);
    final inMonth = day.month == date.month;
    final line = theme.colorScheme.outlineVariant.withValues(
      alpha: metrics.dimmedOpacity,
    );
    return DragTarget<CalendarEvent>(
      onWillAcceptWithDetails: (details) =>
          onEventDropped != null &&
          details.data.canMove &&
          !calendarSameDay(details.data.startDay(timeZone), day),
      onAcceptWithDetails: (details) =>
          onEventDropped!(CalendarDrop(event: details.data, day: day)),
      builder: (context, candidates, rejected) => AnimatedContainer(
        duration: roles.motionFast,
        constraints: BoxConstraints(minHeight: metrics.monthCellHeight),
        decoration: BoxDecoration(
          color: candidates.isNotEmpty
              ? roles.highlight.withValues(alpha: .6)
              : null,
          border: Border.all(color: line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Semantics(
                label: isToday
                    ? CalendarStrings.fill(strings.todayDay, {
                        'day': strings.longDate(day),
                      })
                    : strings.longDate(day),
                excludeSemantics: true,
                button: onDayTap != null,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: const CircleBorder(),
                    minimumSize: Size.square(metrics.markerHeight),
                    padding: EdgeInsets.zero,
                    backgroundColor: isToday ? roles.accent : null,
                    foregroundColor: isToday
                        ? roles.onAccent
                        : inMonth
                        ? roles.text
                        : roles.textMuted,
                  ),
                  onPressed: onDayTap == null ? null : () => onDayTap!(day),
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      fontWeight: isToday ? FontWeight.w700 : null,
                    ),
                  ),
                ),
              ),
            ),
            for (final segment in segments.take(metrics.monthVisibleItems))
              Padding(
                padding: EdgeInsets.all(metrics.collisionGap),
                child: CalendarEventCard(
                  event: segment.event,
                  selected: segment.event.id == selectedEventId,
                  draggable: onEventDropped != null,
                  onTap: onEventTap == null
                      ? null
                      : () => onEventTap!(segment.event),
                  onDoubleTap: onEventDoubleTap == null
                      ? null
                      : () => onEventDoubleTap!(segment.event),
                  strings: strings,
                  metrics: metrics,
                ),
              ),
            if (segments.length > metrics.monthVisibleItems)
              TextButton(
                onPressed: onShowDay == null ? null : () => onShowDay!(day),
                child: Text(
                  CalendarStrings.fill(strings.more, {
                    'count': segments.length - metrics.monthVisibleItems,
                  }),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
