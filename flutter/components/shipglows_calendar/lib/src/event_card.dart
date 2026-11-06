import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'event.dart';
import 'metrics.dart';
import 'strings.dart';

/// One event as a colored card: tap selects it, double tap edits it, and it
/// can be dragged ([draggable]) onto a day or an hour.
class CalendarEventCard extends StatelessWidget {
  const CalendarEventCard({
    super.key,
    required this.event,
    this.selected = false,
    this.short = false,
    this.draggable = false,
    this.onTap,
    this.onDoubleTap,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  final CalendarEvent event;
  final bool selected;

  /// Too short for its title: only the color shows.
  final bool short;

  final bool draggable;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = calendarEventColors(
      Theme.of(context).colorScheme,
      event,
    );
    final radius = BorderRadius.circular(metrics.cardRadius);
    final title = Text(
      event.title,
      maxLines: 3,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: foreground,
        fontSize: metrics.smallText,
        fontWeight: FontWeight.w600,
      ),
    );
    final card = Semantics(
      label: event.label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      child: Tooltip(
        message: CalendarStrings.fill(strings.eventHint, {
          'label': event.label,
        }),
        waitDuration: const Duration(milliseconds: 500),
        child: Material(
          color: background,
          borderRadius: radius,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            onDoubleTap: onDoubleTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              decoration: BoxDecoration(
                borderRadius: radius,
                border: Border.all(
                  color: selected ? foreground : background,
                  width: metrics.nowLineWidth,
                ),
              ),
              // The border is always drawn (in the card color when not
              // selected), so selecting never shifts the title.
              padding: EdgeInsets.all(
                math.max(0.0, metrics.cardInset - metrics.nowLineWidth),
              ),
              child: short ? const SizedBox.shrink() : title,
            ),
          ),
        ),
      ),
    );
    if (!draggable || !event.canMove) return card;
    return Draggable<CalendarEvent>(
      data: event,
      feedback: Material(
        color: background,
        elevation: 6,
        borderRadius: radius,
        child: SizedBox(
          width: metrics.dayWidth,
          child: Padding(padding: EdgeInsets.all(metrics.cardInset), child: title),
        ),
      ),
      childWhenDragging: Opacity(opacity: metrics.dimmedOpacity, child: card),
      child: MouseRegion(cursor: SystemMouseCursors.grab, child: card),
    );
  }
}
