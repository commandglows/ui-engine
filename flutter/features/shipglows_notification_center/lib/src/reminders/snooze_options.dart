import 'package:flutter/foundation.dart';

import 'daily_reminder_plan.dart';

/// The unit of a [SnoozeAfter].
enum SnoozeUnit { minutes, hours, days }

/// The day of a [SnoozeAt]. A weekday means the next one after today.
enum SnoozeDay {
  today,
  tomorrow,
  monday,
  tuesday,
  wednesday,
  thursday,
  friday,
  saturday,
  sunday;

  /// [DateTime.monday] to [DateTime.sunday]; `null` for today and tomorrow.
  int? get weekday => index >= 2 ? index - 1 : null;
}

/// One choice of a snooze menu: a delay ([SnoozeAfter]) or a day and a time
/// ([SnoozeAt]).
@immutable
sealed class SnoozeOption {
  const SnoozeOption();

  /// The moment this choice means from [from], in local time; `null` when it
  /// has passed (« today at 18:00 » in the evening).
  DateTime? nextAt(DateTime from);

  /// The stored form: `after:3:hours`, `at:monday:09:00`.
  String get id;

  /// Reads [id]; anything else is `null`.
  static SnoozeOption? parse(Object? data) {
    if (data is! String) return null;
    final after = RegExp(r'^after:(\d{1,2}):(\w+)$').firstMatch(data);
    if (after != null) {
      final amount = int.parse(after[1]!);
      final unit = SnoozeUnit.values.asNameMap()[after[2]];
      if (unit == null || amount < 1) return null;
      return SnoozeAfter(amount, unit);
    }
    final at = RegExp(r'^at:(\w+):(\d{1,2}:\d{2})$').firstMatch(data);
    if (at != null) {
      final day = SnoozeDay.values.asNameMap()[at[1]];
      final time = ReminderTime.parse(at[2]);
      if (day == null || time == null) return null;
      return SnoozeAt(day, time);
    }
    return null;
  }

  @override
  String toString() => id;
}

/// « In 3 hours »: [amount] [unit] from the moment the person chooses.
@immutable
final class SnoozeAfter extends SnoozeOption {
  const SnoozeAfter(this.amount, this.unit)
    : assert(amount >= minAmount && amount <= maxAmount);

  static const minAmount = 1;
  static const maxAmount = 99;

  final int amount;
  final SnoozeUnit unit;

  @override
  DateTime nextAt(DateTime from) {
    final local = from.toLocal();
    return switch (unit) {
      SnoozeUnit.minutes => local.add(Duration(minutes: amount)),
      SnoozeUnit.hours => local.add(Duration(hours: amount)),
      // Per calendar day: the same time of day across a daylight-saving change.
      SnoozeUnit.days => DateTime(
        local.year,
        local.month,
        local.day + amount,
        local.hour,
        local.minute,
        local.second,
      ),
    };
  }

  @override
  String get id => 'after:$amount:${unit.name}';

  @override
  bool operator ==(Object other) =>
      other is SnoozeAfter && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}

/// « Tomorrow at 09:00 », « Monday at 09:00 ».
@immutable
final class SnoozeAt extends SnoozeOption {
  const SnoozeAt(this.day, this.time);

  final SnoozeDay day;
  final ReminderTime time;

  @override
  DateTime? nextAt(DateTime from) {
    final local = from.toLocal();
    final weekday = day.weekday;
    final ahead = switch (day) {
      SnoozeDay.today => 0,
      SnoozeDay.tomorrow => 1,
      // 1 to 7: today's own weekday means a week from now.
      _ => (weekday! - local.weekday - 1) % 7 + 1,
    };
    final at = DateTime(
      local.year,
      local.month,
      local.day + ahead,
      time.hour,
      time.minute,
    );
    return at.isAfter(local) ? at : null;
  }

  @override
  String get id => 'at:${day.name}:${time.id}';

  @override
  bool operator ==(Object other) =>
      other is SnoozeAt && other.day == day && other.time == time;

  @override
  int get hashCode => Object.hash(day, time);
}

/// One line of a snooze menu: what was chosen and when it comes back.
@immutable
class SnoozeChoice {
  const SnoozeChoice(this.option, this.at);

  final SnoozeOption option;
  final DateTime at;
}

/// The choices a person keeps in every snooze menu of an app.
///
/// Rows may repeat while they are being edited (going from 1 to 4 hours passes
/// over an existing 3 hours); [menu] shows each moment once.
@immutable
class SnoozeOptions {
  SnoozeOptions([List<SnoozeOption> options = defaults])
    : options = List.unmodifiable(
        options.isEmpty ? defaults : options.take(maxOptions),
      );

  static const maxOptions = 8;

  static const defaults = <SnoozeOption>[
    SnoozeAfter(1, SnoozeUnit.hours),
    SnoozeAt(SnoozeDay.today, ReminderTime(18, 0)),
    SnoozeAfter(3, SnoozeUnit.hours),
    SnoozeAt(SnoozeDay.tomorrow, ReminderTime(9, 0)),
    SnoozeAt(SnoozeDay.monday, ReminderTime(9, 0)),
  ];

  /// Never empty, at most [maxOptions].
  final List<SnoozeOption> options;

  bool get canAdd => options.length < maxOptions;
  bool get canRemove => options.length > 1;

  /// Adds [option], unless the list is full.
  SnoozeOptions adding(SnoozeOption option) =>
      canAdd ? SnoozeOptions([...options, option]) : this;

  /// Removes the row at [index]; the last row stays.
  SnoozeOptions removingAt(int index) =>
      canRemove ? SnoozeOptions([...options]..removeAt(index)) : this;

  /// Replaces the row at [index].
  SnoozeOptions replacingAt(int index, SnoozeOption option) =>
      SnoozeOptions([...options]..[index] = option);

  /// What the menu offers from [from]: soonest first, what has passed left
  /// out, two options falling on the same minute shown once.
  List<SnoozeChoice> menu(DateTime from) {
    final seen = <int>{};
    final choices = [
      for (final option in options)
        if (option.nextAt(from) case final at?) SnoozeChoice(option, at),
    ]..sort((a, b) => a.at.compareTo(b.at));
    return [
      for (final choice in choices)
        if (seen.add(choice.at.millisecondsSinceEpoch ~/ 60000)) choice,
    ];
  }

  /// JSON-safe form, for the app's settings store.
  List<String> toJson() => [for (final option in options) option.id];

  /// Reads [toJson]; unusable rows are skipped, nothing usable is `null`.
  static SnoozeOptions? fromJson(Object? data) {
    if (data is! List) return null;
    final options = [for (final row in data) ?SnoozeOption.parse(row)];
    return options.isEmpty ? null : SnoozeOptions(options);
  }

  @override
  bool operator ==(Object other) =>
      other is SnoozeOptions && listEquals(other.options, options);

  @override
  int get hashCode => Object.hashAll(options);
}
