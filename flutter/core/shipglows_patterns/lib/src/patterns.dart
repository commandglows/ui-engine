/// One tracked period: a day, an entry or any unit the app compares.
class PatternObservation {
  const PatternObservation({required this.value, this.tags = const {}});

  /// The tracked value, on the app's own scale. Non-finite values are ignored.
  final double value;

  /// What the person noted for this period. Stable ids, not display labels.
  final Set<String> tags;
}

/// Guards below which [findPatterns] stays silent.
class PatternRules {
  const PatternRules({
    this.minObservations = 10,
    this.minWithTag = 3,
    this.minWithoutTag = 3,
    this.minGap = 0.25,
  });

  /// Observations needed before anything is reported.
  final int minObservations;

  /// Observations carrying the tag needed to report it.
  final int minWithTag;

  /// Observations without the tag needed to compare against.
  final int minWithoutTag;

  /// Smallest difference between the two means, in the unit of the value.
  final double minGap;
}

/// How a tracked value differs on periods with [tag] and without it.
class PatternFinding {
  const PatternFinding({
    required this.tag,
    required this.countWith,
    required this.countWithout,
    required this.meanWith,
    required this.meanWithout,
  });

  /// The tag this finding is about.
  final String tag;

  /// Number of observations carrying the tag.
  final int countWith;

  /// Number of observations without the tag.
  final int countWithout;

  /// Mean value with the tag.
  final double meanWith;

  /// Mean value without the tag.
  final double meanWithout;

  /// [meanWith] minus [meanWithout]: positive when the value is higher with
  /// the tag.
  double get gap => meanWith - meanWithout;
}

/// Tolerance on [PatternRules.minGap], so a gap of exactly the minimum passes
/// despite floating-point rounding.
const double _epsilon = 1e-9;

/// Tags whose periods differ from the others, widest gap first.
///
/// Ties go to the tag seen most often, then to alphabetical order, so the same
/// data always gives the same answer. Descriptive only: no significance test
/// runs and a finding does not prove a cause.
List<PatternFinding> findPatterns(
  Iterable<PatternObservation> observations, {
  PatternRules rules = const PatternRules(),
}) {
  final usable = [
    for (final observation in observations)
      if (observation.value.isFinite) observation,
  ];
  if (usable.length < rules.minObservations) return const [];

  var total = 0.0;
  final sums = <String, double>{};
  final counts = <String, int>{};
  for (final observation in usable) {
    total += observation.value;
    for (final tag in observation.tags) {
      sums[tag] = (sums[tag] ?? 0) + observation.value;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }

  final findings = <PatternFinding>[];
  counts.forEach((tag, countWith) {
    final countWithout = usable.length - countWith;
    if (countWith < rules.minWithTag || countWithout < rules.minWithoutTag) {
      return;
    }
    final sum = sums[tag]!;
    final finding = PatternFinding(
      tag: tag,
      countWith: countWith,
      countWithout: countWithout,
      meanWith: sum / countWith,
      meanWithout: (total - sum) / countWithout,
    );
    if (finding.gap.abs() >= rules.minGap - _epsilon) {
      findings.add(finding);
    }
  });

  findings.sort((a, b) {
    final byGap = b.gap.abs() - a.gap.abs();
    if (byGap.abs() > _epsilon) return byGap.sign.toInt();
    final byCount = b.countWith.compareTo(a.countWith);
    if (byCount != 0) return byCount;
    return a.tag.compareTo(b.tag);
  });
  return findings;
}
