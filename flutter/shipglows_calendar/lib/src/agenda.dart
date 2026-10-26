import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'dates.dart';
import 'event.dart';
import 'metrics.dart';
import 'strings.dart';
import 'time_zone.dart';

/// The events of [range] as a list grouped by day: the view for narrow
/// windows, and for reading many events at once. Each event appears under
/// its first day in the range.
class CalendarAgenda extends StatelessWidget {
  const CalendarAgenda({
    super.key,
    required this.range,
    required this.events,
    required this.today,
    this.timeZone = CalendarTimeZone.device,
    this.selectedEventId,
    this.onEventTap,
    this.onEventEdit,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  final CalendarRange range;
  final List<CalendarEvent> events;
  final DateTime today;
  final CalendarTimeZone timeZone;
  final String? selectedEventId;
  final ValueChanged<CalendarEvent>? onEventTap;

  /// Shows an edit button on each row.
  final ValueChanged<CalendarEvent>? onEventEdit;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final roles = ShipglowsTheme.of(context);
    final theme = Theme.of(context);
    final placed = <String>{};
    final days = <(DateTime, List<CalendarSegment>)>[];
    for (final day in range.dates) {
      final segments = calendarSegmentsOn(
        events,
        day,
        timeZone,
      ).where((segment) => placed.add(segment.event.id)).toList();
      if (segments.isNotEmpty) days.add((day, segments));
    }
    if (days.isEmpty) {
      return Padding(padding: metrics.padding, child: Text(strings.empty));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (day, segments) in days) ...[
          Padding(
            padding: EdgeInsets.fromLTRB(
              metrics.gap,
              metrics.gap,
              metrics.gap,
              roles.spaceXs,
            ),
            child: Semantics(
              header: true,
              child: Text(
                calendarSameDay(day, today)
                    ? CalendarStrings.fill(strings.todayDay, {
                        'day': strings.longDate(day),
                      })
                    : strings.longDate(day),
                style: theme.textTheme.labelLarge?.copyWith(
                  color: calendarSameDay(day, today)
                      ? roles.accent
                      : roles.textMuted,
                ),
              ),
            ),
          ),
          for (final segment in segments) _row(context, segment.event),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, CalendarEvent event) {
    final (color, _) = calendarEventColors(
      Theme.of(context).colorScheme,
      event,
    );
    return ListTile(
      selected: event.id == selectedEventId,
      leading: Container(
        width: metrics.nowLineWidth * 2,
        height: metrics.markerHeight,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(metrics.nowLineWidth),
        ),
      ),
      minLeadingWidth: 0,
      title: Text(event.title),
      subtitle: event.description == null ? null : Text(event.description!),
      onTap: onEventTap == null ? null : () => onEventTap!(event),
      trailing: onEventEdit == null
          ? null
          : IconButton(
              tooltip: CalendarStrings.fill(strings.edit, {
                'title': event.title,
              }),
              icon: const Icon(Icons.edit_calendar),
              onPressed: () => onEventEdit!(event),
            ),
    );
  }
}
