/// How firmly help is offered, from none to urgent.
enum LifelineLevel {
  none,
  gentle,
  support,
  urgent;

  /// Whether this level is firmer than [other].
  bool isAbove(LifelineLevel other) => index > other.index;
}

/// One thing a person noted on a civil day.
class LifelineSignal {
  const LifelineSignal({
    required this.id,
    required this.day,
    required this.weight,
    this.critical = false,
  });

  /// What was noted, in the app's own terms.
  final String id;

  /// The day it was noted. Only the date counts.
  final DateTime day;

  /// How much it counts towards the score.
  final int weight;

  /// Whether this alone calls for the [LifelineLevel.urgent] level.
  final bool critical;
}

/// Thresholds and cooldowns of a lifeline.
class LifelineRules {
  const LifelineRules({
    this.windowDays = 14,
    this.gentleAt = 3,
    this.supportAt = 6,
    this.urgentAt = 15,
    this.strongWeight = 5,
    this.gentleCooldownDays = 7,
    this.supportCooldownDays = 3,
    this.urgentCooldownDays = 1,
  });

  /// Days looked at, today included.
  final int windowDays;

  /// Score from which [LifelineLevel.gentle] applies.
  final int gentleAt;

  /// Score from which [LifelineLevel.support] applies.
  final int supportAt;

  /// Score from which [LifelineLevel.urgent] applies, with a strong signal.
  final int urgentAt;

  /// Weight from which a signal counts as strong.
  final int strongWeight;

  /// Days before showing [LifelineLevel.gentle] again.
  final int gentleCooldownDays;

  /// Days before showing [LifelineLevel.support] again.
  final int supportCooldownDays;

  /// Days before showing [LifelineLevel.urgent] again.
  final int urgentCooldownDays;

  /// Cooldown after a page of [level], in days.
  int cooldownDays(LifelineLevel level) => switch (level) {
    LifelineLevel.none => 0,
    LifelineLevel.gentle => gentleCooldownDays,
    LifelineLevel.support => supportCooldownDays,
    LifelineLevel.urgent => urgentCooldownDays,
  };
}

/// The level reached, and what led to it.
class LifelineAssessment {
  const LifelineAssessment({
    required this.level,
    required this.score,
    required this.signals,
    required this.hasSignalToday,
  });

  /// How firmly help should be offered.
  final LifelineLevel level;

  /// Sum of the weights in the window.
  final int score;

  /// Signals in the window, heaviest first.
  final List<LifelineSignal> signals;

  /// Whether today brought a signal.
  final bool hasSignalToday;
}

/// The last page shown, to avoid nagging. Store it with [toJson].
class LifelineMemory {
  const LifelineMemory({required this.level, required this.day});

  /// Reads a stored memory, or `null` if it is damaged.
  static LifelineMemory? fromJson(Object? json) {
    if (json is! Map<String, Object?>) return null;
    final levelName = json['level'];
    final dayText = json['day'];
    if (levelName is! String || dayText is! String) return null;
    final day = DateTime.tryParse(dayText);
    if (day == null) return null;
    for (final level in LifelineLevel.values) {
      if (level.name == levelName) {
        return LifelineMemory(level: level, day: day);
      }
    }
    return null;
  }

  /// Level of the last page.
  final LifelineLevel level;

  /// Day of the last page.
  final DateTime day;

  /// The form to store.
  Map<String, Object> toJson() => {
    'level': level.name,
    'day': _dateOnly(day).toIso8601String(),
  };
}

DateTime _dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Whole civil days from [from] to [to], whatever the clock change in between.
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(
  to.year,
  to.month,
  to.day,
).difference(DateTime.utc(from.year, from.month, from.day)).inDays;

/// Adds up the signals of the window and gives the level they reach.
///
/// [LifelineLevel.urgent] needs a critical signal, or a score of
/// [LifelineRules.urgentAt] with at least one strong signal: many light signals
/// alone stop at [LifelineLevel.support]. Signals dated after [today] are ignored.
LifelineAssessment assessLifeline(
  Iterable<LifelineSignal> signals, {
  required DateTime today,
  LifelineRules rules = const LifelineRules(),
}) {
  final kept = <LifelineSignal>[];
  for (final signal in signals) {
    final age = _daysBetween(signal.day, today);
    if (age >= 0 && age < rules.windowDays) kept.add(signal);
  }
  kept.sort((a, b) => b.weight.compareTo(a.weight));

  final score = kept.fold<int>(0, (sum, signal) => sum + signal.weight);
  final hasCritical = kept.any((signal) => signal.critical);
  final hasStrong = kept.any((signal) => signal.weight >= rules.strongWeight);
  final level = hasCritical || (score >= rules.urgentAt && hasStrong)
      ? LifelineLevel.urgent
      : score >= rules.supportAt
      ? LifelineLevel.support
      : score >= rules.gentleAt
      ? LifelineLevel.gentle
      : LifelineLevel.none;

  return LifelineAssessment(
    level: level,
    score: score,
    signals: List.unmodifiable(kept),
    hasSignalToday: kept.any((signal) => _daysBetween(signal.day, today) == 0),
  );
}

/// Whether to show the page today.
///
/// Only when today brought a signal: a good day is never interrupted because of
/// last week. After a page, the same level or a lower one waits out its cooldown;
/// a firmer one shows at once.
bool shouldShowLifeline(
  LifelineAssessment assessment,
  LifelineMemory? memory, {
  required DateTime today,
  LifelineRules rules = const LifelineRules(),
}) {
  if (assessment.level == LifelineLevel.none || !assessment.hasSignalToday) {
    return false;
  }
  if (memory == null || assessment.level.isAbove(memory.level)) return true;
  return _daysBetween(memory.day, today) >= rules.cooldownDays(memory.level);
}
