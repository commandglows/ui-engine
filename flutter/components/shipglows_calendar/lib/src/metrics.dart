import 'package:flutter/material.dart';

/// Sizes of the calendar views. [CalendarMetrics.standard] fits most apps;
/// pass your own (`const CalendarMetrics(hourHeight: 48)`) to change one.
@immutable
class CalendarMetrics {
  const CalendarMetrics({
    this.agendaBreakpoint = 460,
    this.hourHeight = 58,
    this.timeGutter = 60,
    this.dayWidth = 56,
    this.viewportHeight = 580,
    this.monthCellHeight = 130,
    this.compactCellHeight = 44,
    this.miniCellHeight = 32,
    this.allDayRowHeight = 88,
    this.headerHeight = 48,
    this.markerHeight = 32,
    this.resizeHandleSize = 18,
    this.collisionGap = 3,
    this.cardInset = 7,
    this.cardRadius = 8,
    this.smallText = 11,
    this.nowLineWidth = 2,
    this.monthVisibleItems = 3,
    this.gap = 12,
    this.snapMinutes = 15,
    this.dimmedOpacity = .38,
  });

  static const standard = CalendarMetrics();

  /// Below this width, the day and week views give way to the agenda.
  final double agendaBreakpoint;

  /// Height of one hour in the day and week grids.
  final double hourHeight;

  /// Width of the hour labels column.
  final double timeGutter;

  /// Narrowest day column; wider screens share their width.
  final double dayWidth;

  /// Height of the day and week grids, which scroll inside.
  final double viewportHeight;

  /// Shortest cell of the month view.
  final double monthCellHeight;

  /// Cell height of the compact month and the day strip (a touch target).
  final double compactCellHeight;

  /// Cell height of the mini month.
  final double miniCellHeight;

  final double allDayRowHeight;
  final double headerHeight;

  /// Height of a marker (an event without duration).
  final double markerHeight;

  final double resizeHandleSize;

  /// Space between overlapping events.
  final double collisionGap;

  final double cardInset;
  final double cardRadius;
  final double smallText;
  final double nowLineWidth;

  /// Events shown in a month cell before « +N ».
  final int monthVisibleItems;

  final double gap;

  /// Moves and resizes land on multiples of these minutes.
  final int snapMinutes;

  /// Opacity of an event while it is dragged, and of the grid lines.
  final double dimmedOpacity;

  EdgeInsets get padding => EdgeInsets.all(gap);
}
