import 'package:flutter/widgets.dart';

import 'strings.dart';

/// Writes numbers, percentages and durations with the separators, suffixes,
/// minus sign and unit words of [strings]. Every method is total: it never
/// throws, and a NaN or infinite number reads as an em dash.
@immutable
class MetricFormat {
  const MetricFormat(this.strings);

  /// The separators, suffixes and unit words used by every method.
  final MetricStrings strings;

  /// The formatter for the [MetricStringsScope] above [context], or the
  /// locale default.
  static MetricFormat of(BuildContext context) =>
      MetricFormat(MetricStrings.of(context));

  static const _none = '—';
  static const _minus = '−';

  /// Most decimals [decimal] writes; more would only add noise.
  static const _maxDigits = 20;

  /// Divisors of the compact units: none, thousand, million, billion.
  static const _divisors = <double>[1.0, 1e3, 1e6, 1e9];

  /// [value] rounded to a whole number and grouped by three: 1240 gives
  /// "1,240", -1240 gives "−1,240".
  String integer(num value) => value.isFinite ? _text(value, 0) : _none;

  /// [value] with at most [digits] decimals, trailing zeros dropped: 2.0
  /// gives "2", 98.24 gives "98.2" with the default of one decimal.
  String decimal(num value, {int digits = 1}) =>
      value.isFinite ? _text(value, _places(digits)) : _none;

  /// Short form of [value]: under one thousand it is [integer]; from then
  /// on a k, M or B suffix with one decimal under ten (1200 gives "1.2k",
  /// 15300 gives "15k", 2500000 gives "2.5M"). A value that rounds up to the
  /// next unit moves to it: 999 950 gives "1M", not "1000k".
  String compact(num value) {
    if (!value.isFinite) return _none;
    final magnitude = value.abs().toDouble();
    var unit = 0;
    while (unit < _divisors.length - 1 && magnitude >= _divisors[unit + 1]) {
      unit++;
    }
    var scaled = _roundUnit(magnitude / _divisors[unit], unit);
    if (unit < _divisors.length - 1 && scaled >= 1000) {
      // Rounding rolled over (999 950 gives 1000k): read it in the next unit.
      unit++;
      scaled = _roundUnit(magnitude / _divisors[unit], unit);
    }
    final suffixes = [
      '',
      strings.thousandSuffix,
      strings.millionSuffix,
      strings.billionSuffix,
    ];
    final body = unit == 0 || scaled >= 10 ? integer(scaled) : decimal(scaled);
    final sign = value < 0 && scaled > 0 ? _minus : '';
    return '$sign$body${suffixes[unit]}';
  }

  /// [ratio] as a percentage with at most [digits] decimals: 0.123 gives
  /// "12%" (or "12 %" in French). With [signed], a rise gets "+" and a fall
  /// gets the minus sign; zero gets neither.
  String percent(double ratio, {int digits = 0, bool signed = false}) {
    final value = ratio * 100;
    if (!value.isFinite) return _none;
    final text = decimal(value, digits: digits);
    final sign = signed && text != '0' && !text.startsWith(_minus) ? '+' : '';
    return '$sign$text${strings.percentSuffix}';
  }

  /// The two largest non-zero units of [value], such as "45 s", "2 min 5 s",
  /// "3 h 10 min" or "2 d 4 h". Seconds are whole: the rest is dropped. Zero
  /// is "0 s".
  String duration(Duration value) {
    final total = value.abs().inSeconds;
    if (total == 0) return '0 ${strings.secondShort}';
    final parts = [
      (total ~/ 86400, strings.dayShort),
      ((total % 86400) ~/ 3600, strings.hourShort),
      ((total % 3600) ~/ 60, strings.minuteShort),
      (total % 60, strings.secondShort),
    ];
    final first = parts.indexWhere((part) => part.$1 > 0);
    final next = first + 1 < parts.length ? parts[first + 1] : null;
    final head = '${integer(parts[first].$1)} ${parts[first].$2}';
    final tail = next == null || next.$1 == 0
        ? ''
        : ' ${integer(next.$1)} ${next.$2}';
    final sign = value.isNegative ? _minus : '';
    return '$sign$head$tail';
  }

  /// [value] with [places] decimals: grouped whole digits, the decimal
  /// separator, and a minus sign only when the rounded result is below zero.
  String _text(num value, int places) {
    final scaled = _scaled(value, places);
    final digits = scaled.abs().toString().padLeft(places + 1, '0');
    final cut = digits.length - places;
    final fraction = digits.substring(cut).replaceFirst(RegExp(r'0+$'), '');
    final sign = scaled.isNegative ? _minus : '';
    final whole = _grouped(digits.substring(0, cut));
    final decimals = fraction.isEmpty
        ? ''
        : '${strings.decimalSeparator}$fraction';
    return '$sign$whole$decimals';
  }

  /// [digits] kept within 0 to [_maxDigits].
  static int _places(int digits) =>
      digits < 0 ? 0 : (digits > _maxDigits ? _maxDigits : digits);

  /// [value] times 10 to the power [places], rounded half away from zero, as
  /// an exact integer. Falls back to whole-number arithmetic when the scaled
  /// double would overflow.
  static BigInt _scaled(num value, int places) {
    final factor = BigInt.from(10).pow(places);
    if (value is int) return BigInt.from(value) * factor;
    final product = value.toDouble() * factor.toDouble();
    if (product.isFinite) return BigInt.from(product.roundToDouble());
    return BigInt.from(value.toDouble().roundToDouble()) * factor;
  }

  /// [x] rounded to a whole number, or to one decimal under ten for a unit.
  static double _roundUnit(double x, int unit) =>
      unit == 0 || x >= 10 ? x.roundToDouble() : (x * 10).roundToDouble() / 10;

  /// [digits] with a group separator every three places from the right.
  String _grouped(String digits) {
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) {
        buffer.write(strings.groupSeparator);
      }
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }
}
