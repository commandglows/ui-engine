/// The largest epoch millisecond a Dart [DateTime] can hold.
const _maxEpochMillis = 8640000000000000;

/// Converts a Convex number (epoch milliseconds) to a local [DateTime].
///
/// Anything else (null, text, NaN, out of range) gives the epoch,
/// 1970-01-01, so a bad timestamp never breaks a screen.
DateTime convexMillisToDateTime(Object? value) {
  if (value is! num || !value.isFinite || value.abs() > _maxEpochMillis) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  return DateTime.fromMillisecondsSinceEpoch(value.toInt());
}

/// The epoch milliseconds of [value], the form Convex stores timestamps in.
int dateTimeToConvexMillis(DateTime value) => value.millisecondsSinceEpoch;
