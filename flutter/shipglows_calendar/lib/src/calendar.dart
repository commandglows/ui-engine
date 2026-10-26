import 'package:flutter/material.dart';
import 'package:shipglows_theme/shipglows_theme.dart';

import 'agenda.dart';
import 'dates.dart';
import 'event.dart';
import 'metrics.dart';
import 'month_view.dart';
import 'strings.dart';
import 'time_grid.dart';
import 'time_zone.dart';
import 'toolbar.dart';

/// A complete calendar: the toolbar and the day, week, month or agenda view,
/// sliding to the next period when the date changes.
///
/// The app owns the date and the events; the calendar owns which view is
/// shown. Below [CalendarMetrics.agendaBreakpoint] the day and week views
/// give way to the agenda. A tap on a month day opens it in the day view,
/// « +N » lists that day.
///
/// Moves and resizes are proposals: the calendar reports them and the app
/// decides (save, ask for confirmation, refuse).
class ShipglowsCalendar extends StatefulWidget {
  const ShipglowsCalendar({
    super.key,
    required this.events,
    required this.date,
    required this.onDateChanged,
    this.timeZone = CalendarTimeZone.device,
    this.clock,
    this.initialView,
    this.views = CalendarView.values,
    this.onViewChanged,
    this.selectedEventId,
    this.onEventTap,
    this.onEventEdit,
    this.onEventDropped,
    this.onEventResized,
    this.onSlotDoubleTap,
    this.toolbarActions = const [],
    this.header,
    this.panelBuilder,
    this.strings = CalendarStrings.fr,
    this.metrics = CalendarMetrics.standard,
  });

  /// Events of at least the visible days; the others are ignored.
  final List<CalendarEvent> events;

  /// Day in view.
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;
  final CalendarTimeZone timeZone;

  /// Current time; defaults to [DateTime.now].
  final DateTime Function()? clock;

  /// First view; the week, or the agenda on a narrow window.
  final CalendarView? initialView;

  /// Views offered, in this order.
  final List<CalendarView> views;
  final ValueChanged<CalendarView>? onViewChanged;
  final String? selectedEventId;
  final ValueChanged<CalendarEvent>? onEventTap;

  /// Double tap on an event, its resize handle, or the agenda edit button.
  final ValueChanged<CalendarEvent>? onEventEdit;
  final ValueChanged<CalendarDrop>? onEventDropped;
  final CalendarResizeCallback? onEventResized;

  /// Double tap on an empty hour: create an event starting there.
  final ValueChanged<DateTime>? onSlotDoubleTap;

  /// Buttons after the view switch.
  final List<Widget> toolbarActions;

  /// Shown between the toolbar and the view (filters, a notice…).
  final Widget? header;

  /// Draws the surface under the view; a tinted card by default.
  final Widget Function(BuildContext context, Widget child)? panelBuilder;
  final CalendarStrings strings;
  final CalendarMetrics metrics;

  @override
  State<ShipglowsCalendar> createState() => _ShipglowsCalendarState();
}

class _ShipglowsCalendarState extends State<ShipglowsCalendar> {
  CalendarView? _view;

  /// The agenda shows one day (from « +N ») rather than a week.
  bool _singleDay = false;

  /// 1 when the last move went forward in time, -1 backward.
  int _direction = 1;

  @override
  void didUpdateWidget(ShipglowsCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.date != oldWidget.date) {
      _direction = widget.date.isBefore(oldWidget.date) ? -1 : 1;
    }
  }

  void _show(CalendarView view, {bool singleDay = false}) {
    if (!widget.views.contains(view)) return;
    setState(() {
      _view = view;
      _singleDay = singleDay;
    });
    widget.onViewChanged?.call(view);
  }

  Widget _panel(BuildContext context, Widget child) =>
      widget.panelBuilder?.call(context, child) ??
      Card(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: .96),
        child: Padding(padding: widget.metrics.padding, child: child),
      );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final metrics = widget.metrics;
      final views = widget.views;
      final narrow = constraints.maxWidth < metrics.agendaBreakpoint;
      var chosen =
          _view ??
          widget.initialView ??
          (narrow ? CalendarView.agenda : CalendarView.week);
      if (!views.contains(chosen)) chosen = views.first;
      final effective =
          narrow &&
              views.contains(CalendarView.agenda) &&
              (chosen == CalendarView.day || chosen == CalendarView.week)
          ? CalendarView.agenda
          : chosen;
      final range = CalendarRange.of(
        effective,
        widget.date,
        singleDay: _singleDay,
      );
      final now = (widget.clock ?? DateTime.now)();
      final today = calendarDay(
        widget.timeZone.wallClock(now.millisecondsSinceEpoch),
      );
      final key = ValueKey('$effective:${range.start}:${range.days}');
      final reduceMotion = MediaQuery.disableAnimationsOf(context);

      final view = switch (effective) {
        CalendarView.month => CalendarMonthView(
          date: widget.date,
          events: widget.events,
          today: today,
          timeZone: widget.timeZone,
          selectedEventId: widget.selectedEventId,
          onDayTap: (day) {
            widget.onDateChanged(day);
            _show(CalendarView.day);
          },
          onShowDay: (day) {
            widget.onDateChanged(day);
            _show(CalendarView.agenda, singleDay: true);
          },
          onEventTap: widget.onEventTap,
          onEventDoubleTap: widget.onEventEdit,
          onEventDropped: widget.onEventDropped,
          strings: widget.strings,
          metrics: metrics,
        ),
        CalendarView.day || CalendarView.week => CalendarTimeGrid(
          range: range,
          events: widget.events,
          timeZone: widget.timeZone,
          clock: widget.clock,
          selectedEventId: widget.selectedEventId,
          onEventTap: widget.onEventTap,
          onEventDoubleTap: widget.onEventEdit,
          onEventDropped: widget.onEventDropped,
          onEventResized: widget.onEventResized,
          onSlotDoubleTap: widget.onSlotDoubleTap,
          strings: widget.strings,
          metrics: metrics,
        ),
        CalendarView.agenda => CalendarAgenda(
          range: range,
          events: widget.events,
          today: today,
          timeZone: widget.timeZone,
          selectedEventId: widget.selectedEventId,
          onEventTap: widget.onEventTap,
          onEventEdit: widget.onEventEdit,
          strings: widget.strings,
          metrics: metrics,
        ),
      };

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CalendarToolbar(
            view: chosen,
            date: widget.date,
            today: today,
            onDateChanged: widget.onDateChanged,
            views: views,
            onViewChanged: _show,
            actions: widget.toolbarActions,
            strings: widget.strings,
            metrics: metrics,
          ),
          SizedBox(height: metrics.gap),
          ?widget.header,
          if (effective != chosen)
            Padding(
              padding: metrics.padding,
              child: Text(widget.strings.narrowNotice),
            ),
          ClipRect(
            child: AnimatedSwitcher(
              duration: reduceMotion
                  ? Duration.zero
                  : ShipglowsTheme.of(context).motionNormal,
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topCenter,
                children: [...previous, ?current],
              ),
              transitionBuilder: (child, animation) {
                // The new period comes from the side it lies on; the old
                // one leaves the other way.
                final incoming = child.key == key;
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween(
                      begin: Offset(
                        .04 * _direction * (incoming ? 1 : -1),
                        0,
                      ),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child: KeyedSubtree(key: key, child: _panel(context, view)),
            ),
          ),
        ],
      );
    },
  );
}
