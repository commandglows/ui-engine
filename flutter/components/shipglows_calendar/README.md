# shipglows_calendar

One calendar for every app. Each app keeps its own data (actions, posts,
habits…) and converts it to `CalendarEvent`s; the package draws them and
reports what the user does. It stores nothing.

- `CalendarEvent(id:, title:, start:, end:, allDay:, description:, colorKey:)`:
  all-day events take civil days (`end` included), the others instants; no
  `end` draws a marker. Events with the same `colorKey` share a palette
  color. `canMove` / `canResize` lock them.
- `CalendarTimeZone`: how instants become days and hours.
  `CalendarTimeZone.device` follows the device; an app showing an IANA zone
  implements the four methods with its own database (the package ships
  none). Days of 23 or 25 hours are drawn as they are.
- `ShipglowsCalendar(events:, date:, onDateChanged:)`: toolbar (today,
  previous, next, period title opening a date picker, view switch, your
  `toolbarActions`) and the day, week, month or agenda view, sliding to the
  next period. Below `agendaBreakpoint` (700) the day and week views become
  the agenda. `header` sits between the toolbar and the view,
  `panelBuilder` draws the surface under it.
- Moves and resizes are proposals: `onEventDropped(CalendarDrop(event, day,
  instant))` (instant when dropped on an hour, snapped to `snapMinutes`,
  15 by default; the grid shows where it lands while dragging),
  `onEventResized(event, end)`, `onSlotDoubleTap(instant)`, `onEventEdit`.
  The app saves, asks or refuses.
- Building blocks for other layouts: `CalendarToolbar`, `CalendarTimeGrid`,
  `CalendarMonthView` (`compact: true` shows only day numbers and counts,
  for phones), `CalendarDayStrip` (one week of compact days),
  `CalendarDayCell`, `CalendarMiniMonth`, `CalendarAgenda`,
  `CalendarEventCard`. Their drop targets accept `Draggable<CalendarEvent>`,
  so the app's own list tiles can be dragged onto a day.
- Dates: `calendarDay`, `calendarAddDays`, `calendarSameDay`,
  `calendarShift(view, date, step)`, `CalendarRange.of(view, date)`,
  `.week`, `.month`. `parseCivilDate('2026-10-18')` reads a `YYYY-MM-DD`
  day (null otherwise).
- `CalendarDateField(label:, value:, onChanged:)`: the form field for any
  date the user enters, never a `YYYY-MM-DD` text field. One wheel per part
  (day, month, year; hour and minute with `withTime: true`) rolls with the
  mouse wheel, a mouse drag or a finger; the calendar icon on the right
  opens the date picker (then the time picker). Chips under it pick
  quickly: today, tomorrow, the day after, in a week, in a month; with the
  time, in 1 h, in 3 h, tomorrow 09:00, in a week. They count from `now`,
  the wall time in the app's zone (the device's by default), and roll the
  wheels to the date; `quickPicks: false` hides them. The value is a civil
  day at UTC midnight, or a wall time on UTC fields; a null `value` dims
  the wheels on `initialDate`. `firstDate` / `lastDate` bound the year
  wheel and the picker; a 31 on a 30-day month rolls back to the 30th.
- Texts: `CalendarStrings.fr`, `.en`, `forLocale(locale)`, `copyWith`.
  Short labels in the same language: `shortDay(day)` « sam. 18 oct. »,
  `shortDateTime(date)` « sam. 18 oct. à 14:05 », `shortRange(start, end)`
  « 12 – 18 oct. » (the year appears only outside `reference`, today by
  default), `longDateTime(date)` « lundi 26 octobre 2026 à 09:00 ».
  Sizes: `CalendarMetrics` (`const CalendarMetrics(hourHeight: 48)`).
- Colors come from `ShipglowsTheme` and the `ColorScheme`; reduced motion
  turns the slide off.

```dart
ShipglowsCalendar(
  events: [for (final task in tasks) task.toCalendarEvent()],
  date: date,
  onDateChanged: (day) => setState(() => date = day),
  timeZone: CalendarTimeZone.device,
  strings: CalendarStrings.forLocale(Localizations.localeOf(context)),
  selectedEventId: selected,
  onEventTap: (event) => setState(() => selected = event.id),
  onEventEdit: (event) => openEditor(event.id),
  onEventDropped: (drop) => reschedule(drop.event.id, drop.day, drop.instant),
)
```
