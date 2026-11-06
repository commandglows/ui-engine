import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'dates.dart';
import 'time_zone.dart';

/// One thing on the calendar. Each app converts its own data to these; the
/// calendar never stores or interprets them further.
@immutable
class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.title,
    required this.start,
    this.end,
    this.allDay = false,
    this.description,
    this.colorKey,
    this.color,
    this.onColor,
    this.canMove = true,
    this.canResize = true,
  });

  final String id;
  final String title;

  /// All-day: the first day (only its year, month and day are read).
  /// Otherwise the instant it starts.
  final DateTime start;

  /// All-day: the last day, included. Otherwise the instant it ends; null,
  /// or not after [start], draws a marker (a point in time).
  final DateTime? end;

  final bool allDay;

  /// Shown under the title in the agenda and read with it by screen readers
  /// (its date, its state…).
  final String? description;

  /// Events with the same key share a color (a project, a path…). Defaults
  /// to [id].
  final String? colorKey;

  /// Card color and the color on it; both default to the theme palette.
  final Color? color;
  final Color? onColor;

  /// Whether it can be dragged to another day or time.
  final bool canMove;

  /// Whether its end can be dragged.
  final bool canResize;

  /// A point in time rather than a span.
  bool get isMarker => !allDay && (end == null || !end!.isAfter(start));

  /// Title and description, as read by screen readers.
  String get label => description == null ? title : '$title, $description';

  /// The part of this event on [day] in [zone], or null when it is not on
  /// that day.
  CalendarSegment? segmentOn(DateTime day, CalendarTimeZone zone) {
    final date = calendarDay(day);
    if (allDay) {
      final first = calendarDay(start);
      var last = calendarDay(end ?? start);
      if (last.isBefore(first)) last = first;
      if (date.isBefore(first) || date.isAfter(last)) return null;
      return CalendarSegment._(this, date, null, null, date.isBefore(last));
    }
    final dayStart = zone.startOfDay(date);
    final dayEnd = zone.startOfDay(calendarAddDays(date, 1));
    final first = start.millisecondsSinceEpoch;
    if (isMarker) {
      return first >= dayStart && first < dayEnd
          ? CalendarSegment._(this, date, first, first, false)
          : null;
    }
    final last = end!.millisecondsSinceEpoch;
    if (first >= dayEnd || last <= dayStart) return null;
    return CalendarSegment._(
      this,
      date,
      math.max(first, dayStart),
      math.min(last, dayEnd),
      last > dayEnd,
    );
  }

  /// The civil day it starts on in [zone].
  DateTime startDay(CalendarTimeZone zone) => allDay
      ? calendarDay(start)
      : calendarDay(zone.wallClock(start.millisecondsSinceEpoch));
}

/// The part of an event on one day.
@immutable
class CalendarSegment {
  const CalendarSegment._(
    this.event,
    this.day,
    this.startMilliseconds,
    this.endMilliseconds,
    this.continuesAfter,
  );

  final CalendarEvent event;
  final DateTime day;

  /// Visible start and end on this day, in epoch milliseconds; null for an
  /// all-day event.
  final int? startMilliseconds;
  final int? endMilliseconds;

  /// Whether the event goes on the next day.
  final bool continuesAfter;

  bool get timed => startMilliseconds != null;
}

/// Where an event was dropped: on [day], at [instant] when dropped on the
/// hours of the day or week grid, otherwise on the day itself (all-day row,
/// month cell, day strip).
@immutable
class CalendarDrop {
  const CalendarDrop({required this.event, required this.day, this.instant});

  final CalendarEvent event;
  final DateTime day;
  final DateTime? instant;
}

/// Called with the new end of a resized event: a civil day for an all-day
/// event (the last one, included), an instant otherwise.
typedef CalendarResizeCallback =
    void Function(CalendarEvent event, DateTime end);

/// Events of [events] on [day], all-day first, then by start and title.
List<CalendarSegment> calendarSegmentsOn(
  Iterable<CalendarEvent> events,
  DateTime day,
  CalendarTimeZone zone,
) {
  final segments = [
    for (final event in events) ?event.segmentOn(day, zone),
  ];
  segments.sort(compareCalendarSegments);
  return segments;
}

/// All-day first, then by start, then by title and id.
int compareCalendarSegments(CalendarSegment a, CalendarSegment b) {
  if (a.timed != b.timed) return a.timed ? 1 : -1;
  final order = (a.startMilliseconds ?? 0).compareTo(b.startMilliseconds ?? 0);
  if (order != 0) return order;
  final title = a.event.title.compareTo(b.event.title);
  return title != 0 ? title : a.event.id.compareTo(b.event.id);
}

/// Background and foreground of [event]'s card: its own colors, or the
/// palette color its [CalendarEvent.colorKey] falls on.
(Color, Color) calendarEventColors(ColorScheme scheme, CalendarEvent event) {
  final palette = [
    (scheme.primaryContainer, scheme.onPrimaryContainer),
    (scheme.secondaryContainer, scheme.onSecondaryContainer),
    (scheme.tertiaryContainer, scheme.onTertiaryContainer),
  ];
  final key = event.colorKey ?? event.id;
  final pick =
      palette[key.codeUnits.fold<int>(0, (sum, value) => sum + value) %
          palette.length];
  return (event.color ?? pick.$1, event.onColor ?? pick.$2);
}
