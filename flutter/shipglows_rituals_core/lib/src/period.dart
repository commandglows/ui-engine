/// A civil date in the calendar supplied by the caller, with no UTC conversion.
String ritualDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

/// Rejects malformed and normalized dates such as February 30.
DateTime? parseRitualDate(String? value) {
  if (value == null || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value))
    return null;
  final year = int.parse(value.substring(0, 4));
  if (year < 1) return null;
  final result = DateTime(
    year,
    int.parse(value.substring(5, 7)),
    int.parse(value.substring(8)),
  );
  return ritualDate(result) == value ? result : null;
}

/// Moves through civil days without assuming that every day lasts 24 hours.
DateTime addRitualDays(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
