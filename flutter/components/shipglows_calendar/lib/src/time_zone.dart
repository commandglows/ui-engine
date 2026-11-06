/// How the calendar turns instants into days and hours.
///
/// [CalendarTimeZone.device] follows the device. An app that shows another
/// zone (an IANA zone chosen by the user, say) implements this seam with its
/// own time-zone database, so the package carries none.
///
/// Days are civil dates: only their year, month and day are read.
abstract class CalendarTimeZone {
  const CalendarTimeZone();

  /// The device's own zone.
  static const CalendarTimeZone device = _DeviceTimeZone();

  /// Stable name of the zone, used to know when the display changed.
  String get id;

  /// Epoch milliseconds of the first instant of [day]. Days around a
  /// daylight-saving change last 23 or 25 hours.
  int startOfDay(DateTime day);

  /// What a wall clock in this zone reads at [epochMilliseconds], as a UTC
  /// [DateTime] holding those fields (never converted again).
  DateTime wallClock(int epochMilliseconds);

  /// Offset from UTC at [epochMilliseconds], in minutes.
  int offsetMinutesAt(int epochMilliseconds);

  /// Every instant whose wall clock reads [wallTime] (UTC fields): none in a
  /// daylight-saving gap, two in a repeated hour.
  List<DateTime> instantsAt(DateTime wallTime);
}

class _DeviceTimeZone extends CalendarTimeZone {
  const _DeviceTimeZone();

  @override
  String get id => 'device';

  @override
  int startOfDay(DateTime day) =>
      DateTime(day.year, day.month, day.day).millisecondsSinceEpoch;

  @override
  DateTime wallClock(int epochMilliseconds) {
    final local = DateTime.fromMillisecondsSinceEpoch(epochMilliseconds);
    return DateTime.utc(
      local.year,
      local.month,
      local.day,
      local.hour,
      local.minute,
      local.second,
    );
  }

  @override
  int offsetMinutesAt(int epochMilliseconds) => DateTime.fromMillisecondsSinceEpoch(
    epochMilliseconds,
  ).timeZoneOffset.inMinutes;

  @override
  List<DateTime> instantsAt(DateTime wallTime) {
    final local = DateTime(
      wallTime.year,
      wallTime.month,
      wallTime.day,
      wallTime.hour,
      wallTime.minute,
    );
    // The device normalizes a time in a gap to another hour: that one does
    // not exist on the wall clock.
    return local.hour == wallTime.hour && local.minute == wallTime.minute
        ? [local.toUtc()]
        : const [];
  }
}
