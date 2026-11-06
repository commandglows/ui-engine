import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'dates.dart';
import 'event.dart';
import 'metrics.dart';
import 'strings.dart';
import 'time_zone.dart';

/// The days of one week in a row of compact cells: tap a day to select it,
/// drop an event on it to move it there. Built for phones; scrolls when the
/// row is wider than the screen.
class CalendarDayStrip extends StatelessWidget {
  const CalendarDayStrip({
    super.key,
    required this.range,
    required this.events,
    required this.today,
    this.timeZone = CalendarTimeZone.device,
    this.selectedDay,
    this.onDayTap,
    this.onEventDropped,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  final CalendarRange range;
  final List<CalendarEvent> events;
  final DateTime today;
  final CalendarTimeZone timeZone;
  final DateTime? selectedDay;
  final ValueChanged<DateTime>? onDayTap;
  final ValueChanged<CalendarDrop>? onEventDropped;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: metrics.compactCellHeight * 2,
    child: ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: range.days,
      itemBuilder: (context, index) {
        final day = calendarAddDays(range.start, index);
        return Padding(
          padding: EdgeInsets.only(right: metrics.gap / 2),
          child: SizedBox(
            width: metrics.compactCellHeight * 1.5,
            child: CalendarDayCell(
              day: day,
              label: strings.stripDay(day),
              events: events,
              today: today,
              timeZone: timeZone,
              selected: selectedDay != null && calendarSameDay(selectedDay!, day),
              onTap: onDayTap,
              onEventDropped: onEventDropped,
              strings: strings,
              metrics: metrics,
            ),
          ),
        );
      },
    ),
  );
}

/// One compact day: its label and how many events it holds. Tap selects it;
/// dropping an event moves it there. Fills its parent.
class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    super.key,
    required this.day,
    required this.label,
    required this.events,
    required this.today,
    this.timeZone = CalendarTimeZone.device,
    this.selected = false,
    this.onTap,
    this.onEventDropped,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  final DateTime day;
  final String label;
  final List<CalendarEvent> events;
  final DateTime today;
  final CalendarTimeZone timeZone;
  final bool selected;
  final ValueChanged<DateTime>? onTap;
  final ValueChanged<CalendarDrop>? onEventDropped;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final roles = ShipglowsTheme.of(context);
    final count = events
        .where((event) => event.segmentOn(day, timeZone) != null)
        .length;
    final isToday = calendarSameDay(day, today);
    final countLabel = count == 0
        ? strings.noEvents
        : CalendarStrings.fill(strings.eventCount, {'count': count});
    final dayLabel = strings.longDate(day);
    final semanticLabel =
        '${isToday ? CalendarStrings.fill(strings.todayDay, {'day': dayLabel}) : dayLabel}, $countLabel';
    final radius = BorderRadius.circular(roles.radiusSm);
    void tap() => onTap?.call(day);

    return DragTarget<CalendarEvent>(
      onWillAcceptWithDetails: (details) =>
          onEventDropped != null &&
          details.data.canMove &&
          !calendarSameDay(details.data.startDay(timeZone), day),
      onAcceptWithDetails: (details) =>
          onEventDropped!(CalendarDrop(event: details.data, day: day)),
      builder: (context, candidates, rejected) {
        final highlighted = candidates.isNotEmpty;
        final strong = selected || highlighted || isToday;
        return Semantics(
          button: true,
          selected: selected,
          label: semanticLabel,
          excludeSemantics: true,
          onTap: onTap == null ? null : tap,
          child: AnimatedScale(
            scale: highlighted ? 1.06 : 1,
            duration: roles.motionFast,
            child: Material(
              color: selected || highlighted
                  ? roles.highlight
                  : roles.surfaceRaised,
              borderRadius: radius,
              child: InkWell(
                borderRadius: radius,
                onTap: onTap == null ? null : tap,
                child: AnimatedContainer(
                  duration: roles.motionFast,
                  padding: EdgeInsets.all(roles.spaceXs),
                  decoration: BoxDecoration(
                    borderRadius: radius,
                    border: Border.all(
                      color: strong ? roles.focus : roles.border,
                      width: selected || highlighted ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: strong ? roles.onHighlight : roles.textMuted,
                          fontWeight: isToday || selected
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                      if (count > 0)
                        Text(
                          '$count',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: roles.text,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
