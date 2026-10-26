import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'dates.dart';
import 'event.dart';
import 'event_card.dart';
import 'metrics.dart';
import 'strings.dart';
import 'time_zone.dart';

const _hour = 3600000;
const _minute = 60000;

String _clock(DateTime wall) =>
    '${wall.hour.toString().padLeft(2, '0')}:${wall.minute.toString().padLeft(2, '0')}';

String _offset(int minutes) =>
    'UTC${minutes < 0 ? '-' : '+'}${(minutes.abs() ~/ 60).toString().padLeft(2, '0')}:${(minutes.abs() % 60).toString().padLeft(2, '0')}';

/// Days as columns of hours, with an all-day row on top: the day and week
/// views.
///
/// Overlapping events share their column in lanes. Dragging an event shows
/// where it will land, on [CalendarMetrics.snapMinutes]; dragging the
/// bottom of a timed event (or the right edge of an all-day one) changes its
/// end. A red line marks the current time. Days of 23 or 25 hours (daylight
/// saving) are drawn as they are, each hour labelled with its offset.
class CalendarTimeGrid extends StatefulWidget {
  const CalendarTimeGrid({
    super.key,
    required this.range,
    required this.events,
    this.timeZone = CalendarTimeZone.device,
    this.clock,
    this.selectedEventId,
    this.onEventTap,
    this.onEventDoubleTap,
    this.onEventDropped,
    this.onEventResized,
    this.onSlotDoubleTap,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  final CalendarRange range;
  final List<CalendarEvent> events;
  final CalendarTimeZone timeZone;

  /// Current time; defaults to [DateTime.now].
  final DateTime Function()? clock;
  final String? selectedEventId;
  final ValueChanged<CalendarEvent>? onEventTap;

  /// Double tap on an event, or tap on its resize handle: edit it.
  final ValueChanged<CalendarEvent>? onEventDoubleTap;
  final ValueChanged<CalendarDrop>? onEventDropped;
  final CalendarResizeCallback? onEventResized;

  /// Double tap on an empty slot: create an event starting at that instant.
  final ValueChanged<DateTime>? onSlotDoubleTap;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  State<CalendarTimeGrid> createState() => _CalendarTimeGridState();
}

typedef _Hover = ({DateTime day, int minutes, int length});

class _CalendarTimeGridState extends State<CalendarTimeGrid> {
  final _scroll = ScrollController();
  final _columns = <DateTime, GlobalKey>{};
  final _resize = <String, double>{};
  final _resizeOrigin = <String, double>{};
  final _resizeDays = <String, double>{};
  String? _scrolledFor;
  Offset? _doubleTapAt;
  _Hover? _hover;
  Timer? _timer;

  CalendarMetrics get _metrics => widget.metrics;
  CalendarTimeZone get _zone => widget.timeZone;
  int get _now => (widget.clock ?? DateTime.now)().millisecondsSinceEpoch;

  @override
  void initState() {
    super.initState();
    // Moves the current-time line.
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _scroll.dispose();
    super.dispose();
  }

  /// Minutes [minutes] rounded to the snap step.
  int _snap(double minutes) =>
      (minutes / _metrics.snapMinutes).round() * _metrics.snapMinutes;

  double _snapPixels(double pixels) =>
      _snap(pixels / _metrics.hourHeight * 60) / 60 * _metrics.hourHeight;

  /// Minutes after midnight where a dragged card whose top-left corner is at
  /// [global] lands in the column of [day].
  int? _minutesAt(DateTime day, Offset global, int dayMinutes) {
    final box = _columns[day]?.currentContext?.findRenderObject();
    if (box is! RenderBox) return null;
    final local = box.globalToLocal(global);
    final last = math.max(0, dayMinutes - _metrics.snapMinutes);
    return math.min(
      last,
      math.max(0, _snap(local.dy / _metrics.hourHeight * 60)),
    );
  }

  /// Scrolls to an hour before the first event of the range, or to the
  /// current hour, once per range and zone.
  void _scrollOnce(List<DateTime> days) {
    final key = '${widget.range.start}:${days.length}:${_zone.id}';
    if (_scrolledFor == key) return;
    _scrolledFor = key;
    double? first;
    for (final day in days) {
      final midnight = _zone.startOfDay(day);
      for (final segment in calendarSegmentsOn(widget.events, day, _zone)) {
        if (!segment.timed) continue;
        final hours = (segment.startMilliseconds! - midnight) / _hour;
        first = first == null ? hours : math.min(first, hours);
      }
    }
    final hour = first != null
        ? first - 1
        : _zone.wallClock(_now).hour.toDouble();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.jumpTo(
          (hour * _metrics.hourHeight).clamp(
            0.0,
            _scroll.position.maxScrollExtent,
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final days = widget.range.dates;
      _columns.removeWhere((day, _) => !widget.range.contains(day));
      _scrollOnce(days);
      final starts = [
        for (final day in days) _zone.startOfDay(day),
        _zone.startOfDay(widget.range.end),
      ];
      final maxHours = [
        for (var index = 0; index < days.length; index++)
          (starts[index + 1] - starts[index]) / _hour,
      ].reduce(math.max);
      final width = constraints.maxWidth.isFinite
          ? constraints.maxWidth
          : _metrics.timeGutter + _metrics.dayWidth * days.length;
      final dayWidth = math.max(
        _metrics.dayWidth,
        (width - _metrics.timeGutter) / days.length,
      );
      return SizedBox(
        height: _metrics.viewportHeight,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: _metrics.timeGutter + dayWidth * days.length,
            child: Column(
              children: [
                _header(days, dayWidth),
                _allDayRow(days, dayWidth),
                Expanded(
                  child: SingleChildScrollView(
                    controller: _scroll,
                    child: SizedBox(
                      height: maxHours * _metrics.hourHeight,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _gutter(maxHours),
                          for (var index = 0; index < days.length; index++)
                            SizedBox(
                              width: dayWidth,
                              child: _column(
                                days[index],
                                starts[index],
                                starts[index + 1],
                                dayWidth,
                                maxHours,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _header(List<DateTime> days, double dayWidth) {
    final roles = ShipglowsTheme.of(context);
    final today = calendarDay(_zone.wallClock(_now));
    return SizedBox(
      height: _metrics.headerHeight,
      child: Row(
        children: [
          SizedBox(width: _metrics.timeGutter),
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: Center(
                child: Text(
                  widget.strings.column(day),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: calendarSameDay(day, today) ? roles.accent : null,
                    fontWeight: calendarSameDay(day, today)
                        ? FontWeight.w700
                        : null,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _allDayRow(List<DateTime> days, double dayWidth) {
    final roles = ShipglowsTheme.of(context);
    return SizedBox(
      height: _metrics.allDayRowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: _metrics.timeGutter,
            child: Center(
              child: Text(
                widget.strings.allDay,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: _metrics.smallText),
              ),
            ),
          ),
          for (final day in days)
            SizedBox(
              width: dayWidth,
              child: DragTarget<CalendarEvent>(
                onWillAcceptWithDetails: (details) =>
                    widget.onEventDropped != null && details.data.canMove,
                onAcceptWithDetails: (details) => widget.onEventDropped!(
                  CalendarDrop(event: details.data, day: day),
                ),
                builder: (context, candidates, rejected) => AnimatedContainer(
                  duration: roles.motionFast,
                  color: candidates.isNotEmpty
                      ? roles.highlight.withValues(alpha: .6)
                      : null,
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        for (final segment in calendarSegmentsOn(
                          widget.events,
                          day,
                          _zone,
                        ).where((segment) => !segment.timed))
                          _allDayCard(segment, dayWidth),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _card(CalendarEvent event, {bool short = false}) => CalendarEventCard(
    event: event,
    selected: event.id == widget.selectedEventId,
    short: short,
    draggable: widget.onEventDropped != null,
    onTap: widget.onEventTap == null ? null : () => widget.onEventTap!(event),
    onDoubleTap: widget.onEventDoubleTap == null
        ? null
        : () => widget.onEventDoubleTap!(event),
    strings: widget.strings,
    metrics: _metrics,
  );

  Widget _allDayCard(CalendarSegment segment, double dayWidth) {
    final event = segment.event;
    final resizable =
        event.allDay &&
        event.canResize &&
        widget.onEventResized != null &&
        !segment.continuesAfter;
    return Padding(
      padding: EdgeInsets.all(_metrics.collisionGap),
      child: resizable
          ? Stack(
              children: [
                _card(event),
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  width: _metrics.resizeHandleSize,
                  child: _daysHandle(event, dayWidth),
                ),
              ],
            )
          : _card(event),
    );
  }

  Widget _daysHandle(CalendarEvent event, double dayWidth) => Semantics(
    button: true,
    label: CalendarStrings.fill(widget.strings.resizeDays, {
      'title': event.title,
    }),
    child: Tooltip(
      message: widget.strings.resizeDaysHint,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeLeftRight,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onEventDoubleTap == null
              ? null
              : () => widget.onEventDoubleTap!(event),
          onHorizontalDragDown: (details) =>
              _resizeOrigin[event.id] = details.globalPosition.dx,
          onHorizontalDragUpdate: (details) => _resizeDays[event.id] =
              details.globalPosition.dx -
              (_resizeOrigin[event.id] ?? details.globalPosition.dx),
          onHorizontalDragCancel: () {
            _resizeOrigin.remove(event.id);
            _resizeDays.remove(event.id);
          },
          onHorizontalDragEnd: (_) {
            _resizeOrigin.remove(event.id);
            final days = ((_resizeDays.remove(event.id) ?? 0) / dayWidth)
                .round();
            if (days == 0) return;
            final first = calendarDay(event.start);
            final last = calendarAddDays(
              calendarDay(event.end ?? event.start),
              days,
            );
            widget.onEventResized!(event, last.isBefore(first) ? first : last);
          },
          child: Icon(Icons.drag_indicator, size: _metrics.resizeHandleSize),
        ),
      ),
    ),
  );

  Widget _gutter(double maxHours) => SizedBox(
    width: _metrics.timeGutter,
    child: Column(
      children: [
        for (var hour = 0; hour < maxHours; hour++)
          SizedBox(
            height: _metrics.hourHeight,
            child: Align(
              alignment: Alignment.topCenter,
              child: Text(
                '${hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(fontSize: _metrics.smallText),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _column(
    DateTime day,
    int midnight,
    int next,
    double width,
    double maxHours,
  ) {
    final roles = ShipglowsTheme.of(context);
    final scheme = Theme.of(context).colorScheme;
    final line = scheme.outlineVariant.withValues(
      alpha: _metrics.dimmedOpacity,
    );
    final hours = (next - midnight) / _hour;
    final dayMinutes = (next - midnight) ~/ _minute;
    final key = _columns.putIfAbsent(day, GlobalKey.new);

    // Lanes: each event takes the first lane free at its start.
    final timed = calendarSegmentsOn(
      widget.events,
      day,
      _zone,
    ).where((segment) => segment.timed).toList();
    final laneEnds = <int>[];
    final placed = <(CalendarSegment, int)>[];
    for (final segment in timed) {
      final first = segment.startMilliseconds!;
      final last = segment.endMilliseconds!;
      final occupiedEnd = last == first
          ? first + (_metrics.markerHeight / _metrics.hourHeight * _hour).round()
          : last;
      var lane = laneEnds.indexWhere((end) => end <= first);
      if (lane < 0) {
        lane = laneEnds.length;
        laneEnds.add(occupiedEnd);
      } else {
        laneEnds[lane] = occupiedEnd;
      }
      placed.add((segment, lane));
    }
    final lanes = math.max(1, laneEnds.length);
    final hover = _hover != null && calendarSameDay(_hover!.day, day)
        ? _hover
        : null;
    final now = _now;

    return DragTarget<CalendarEvent>(
      onWillAcceptWithDetails: (details) =>
          widget.onEventDropped != null && details.data.canMove,
      onMove: (details) {
        final minutes = _minutesAt(day, details.offset, dayMinutes);
        if (minutes == null) return;
        final event = details.data;
        final length = event.allDay || event.isMarker
            ? 60
            : event.end!.difference(event.start).inMinutes;
        if (_hover?.minutes != minutes || !calendarSameDay(_hover!.day, day)) {
          setState(() => _hover = (day: day, minutes: minutes, length: length));
        }
      },
      onLeave: (_) => setState(() => _hover = null),
      onAcceptWithDetails: (details) {
        final minutes = _minutesAt(day, details.offset, dayMinutes) ?? 0;
        setState(() => _hover = null);
        widget.onEventDropped!(
          CalendarDrop(
            event: details.data,
            day: day,
            instant: DateTime.fromMillisecondsSinceEpoch(
              midnight + minutes * _minute,
              isUtc: true,
            ),
          ),
        );
      },
      builder: (context, candidates, rejected) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
        onDoubleTap: widget.onSlotDoubleTap == null
            ? null
            : () {
                final minutes = ((_doubleTapAt?.dy ?? 0) /
                        _metrics.hourHeight *
                        60 ~/
                        _metrics.snapMinutes) *
                    _metrics.snapMinutes;
                widget.onSlotDoubleTap!(
                  DateTime.fromMillisecondsSinceEpoch(
                    midnight + minutes * _minute,
                    isUtc: true,
                  ),
                );
              },
        child: SizedBox(
          key: key,
          height: maxHours * _metrics.hourHeight,
          child: Stack(
            children: [
              for (var hour = 0; hour < hours; hour++)
                Positioned(
                  top: hour * _metrics.hourHeight,
                  left: 0,
                  right: 0,
                  height: _metrics.hourHeight,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(color: line),
                        left: BorderSide(color: line),
                      ),
                    ),
                    child: hours == 24
                        ? null
                        : Align(
                            alignment: Alignment.topRight,
                            child: Text(
                              '${_clock(_zone.wallClock(midnight + hour * _hour))} ${_offset(_zone.offsetMinutesAt(midnight + hour * _hour))}',
                              style: TextStyle(
                                fontSize: _metrics.smallText,
                                color: roles.textMuted,
                              ),
                            ),
                          ),
                  ),
                ),
              if (hover != null)
                Positioned(
                  top: hover.minutes / 60 * _metrics.hourHeight,
                  left: _metrics.collisionGap,
                  right: _metrics.collisionGap,
                  height: math.max(
                    _metrics.markerHeight,
                    hover.length / 60 * _metrics.hourHeight,
                  ),
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: roles.highlight.withValues(alpha: .5),
                        borderRadius: BorderRadius.circular(
                          _metrics.cardRadius,
                        ),
                        border: Border.all(color: roles.focus, width: 2),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(_metrics.cardInset),
                        child: Text(
                          _clock(
                            _zone.wallClock(
                              midnight + hover.minutes * _minute,
                            ),
                          ),
                          style: TextStyle(
                            fontSize: _metrics.smallText,
                            fontWeight: FontWeight.w700,
                            color: roles.onHighlight,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              for (final (segment, lane) in placed)
                _timedCard(segment, lane, lanes, midnight, width),
              if (now >= midnight && now < next)
                Positioned(
                  top: (now - midnight) / _hour * _metrics.hourHeight,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: Container(
                      height: _metrics.nowLineWidth,
                      color: scheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timedCard(
    CalendarSegment segment,
    int lane,
    int lanes,
    int midnight,
    double width,
  ) {
    final event = segment.event;
    final first = segment.startMilliseconds!;
    final last = segment.endMilliseconds!;
    final span = (last - first) / _hour * _metrics.hourHeight;
    final marker = first == last;
    final delta = segment.continuesAfter ? 0.0 : (_resize[event.id] ?? 0.0);
    final resizable =
        !marker &&
        !event.allDay &&
        event.canResize &&
        widget.onEventResized != null &&
        !segment.continuesAfter &&
        span >= _metrics.markerHeight;
    return Positioned(
      top: (first - midnight) / _hour * _metrics.hourHeight,
      left: lane * width / lanes + _metrics.collisionGap,
      width: width / lanes - _metrics.collisionGap * 2,
      height: marker
          ? _metrics.markerHeight
          : math.max(_metrics.nowLineWidth, span + delta),
      child: Stack(
        fit: StackFit.expand,
        children: [
          _card(event, short: !marker && span < _metrics.markerHeight),
          if (_resize.containsKey(event.id))
            Positioned(
              right: _metrics.cardInset,
              bottom: _metrics.resizeHandleSize,
              child: IgnorePointer(
                child: Text(
                  _clock(
                    _zone.wallClock(
                      event.end!.millisecondsSinceEpoch +
                          (delta / _metrics.hourHeight * 60).round() * _minute,
                    ),
                  ),
                  style: TextStyle(
                    fontSize: _metrics.smallText,
                    fontWeight: FontWeight.w700,
                    color: calendarEventColors(
                      Theme.of(context).colorScheme,
                      event,
                    ).$2,
                  ),
                ),
              ),
            ),
          if (resizable)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: _metrics.resizeHandleSize,
              child: _endHandle(event),
            ),
        ],
      ),
    );
  }

  Widget _endHandle(CalendarEvent event) => Semantics(
    button: true,
    label: CalendarStrings.fill(widget.strings.resize, {'title': event.title}),
    child: Tooltip(
      message: widget.strings.resizeHint,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeUpDown,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onEventDoubleTap == null
              ? null
              : () => widget.onEventDoubleTap!(event),
          onVerticalDragDown: (details) =>
              _resizeOrigin[event.id] = details.globalPosition.dy,
          onVerticalDragStart: (_) => setState(() => _resize[event.id] = 0),
          onVerticalDragUpdate: (details) => setState(() {
            _resize[event.id] = _snapPixels(
              details.globalPosition.dy -
                  (_resizeOrigin[event.id] ?? details.globalPosition.dy),
            );
          }),
          onVerticalDragCancel: () => setState(() {
            _resize.remove(event.id);
            _resizeOrigin.remove(event.id);
          }),
          onVerticalDragEnd: (_) {
            _resizeOrigin.remove(event.id);
            final minutes =
                ((_resize.remove(event.id) ?? 0) / _metrics.hourHeight * 60)
                    .round();
            setState(() {});
            if (minutes == 0) return;
            var end = event.end!.toUtc().add(Duration(minutes: minutes));
            if (!end.isAfter(event.start)) {
              end = event.start.toUtc().add(
                Duration(minutes: _metrics.snapMinutes),
              );
            }
            widget.onEventResized!(event, end);
          },
          child: Center(
            child: Icon(
              Icons.drag_handle,
              size: _metrics.resizeHandleSize,
              color: calendarEventColors(
                Theme.of(context).colorScheme,
                event,
              ).$2,
            ),
          ),
        ),
      ),
    ),
  );
}
