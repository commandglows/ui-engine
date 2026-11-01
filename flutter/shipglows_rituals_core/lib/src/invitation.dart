/// Pure, host-driven rules for deciding when a ritual may be offered.
///
/// The host supplies the clock, availability mode and prerequisite result.
/// This library does not read time, schedule work, display notifications or
/// persist state. Eligibility rules such as health thresholds belong to apps.
enum RitualInvitationCadence { daily, weekly, monthly, rolling, event }

/// Availability mode supplied by the consuming application.
enum RitualInvitationMode { enabled, quiet, disabled }

/// Why an invitation was or was not offered for an evaluation.
enum RitualInvitationReason {
  offered,
  disabled,
  quiet,
  prerequisitesNotMet,
  notDue,
  alreadyShown,
  dismissed,
  snoozed,
  completed,
}

/// Schedule for a ritual invitation.
///
/// Daily, weekly and monthly boundaries use the civil date fields of the
/// caller-provided [DateTime]. A rolling schedule uses elapsed UTC time from
/// [anchor], divided into fixed [interval] windows. Event schedules require an
/// explicit matching event name and caller-owned event ID at evaluation time.
class RitualInvitationPolicy {
  const RitualInvitationPolicy._(
    this.cadence, {
    this.interval,
    this.anchor,
    this.eventName,
  });

  const RitualInvitationPolicy.daily() : this._(RitualInvitationCadence.daily);

  const RitualInvitationPolicy.weekly()
    : this._(RitualInvitationCadence.weekly);

  const RitualInvitationPolicy.monthly()
    : this._(RitualInvitationCadence.monthly);

  /// Fixed-duration windows anchored at [anchor], not calendar periods.
  factory RitualInvitationPolicy.rolling({
    required Duration interval,
    required DateTime anchor,
  }) {
    if (interval <= Duration.zero) {
      throw ArgumentError.value(interval, 'interval', 'Must be positive');
    }
    return RitualInvitationPolicy._(
      RitualInvitationCadence.rolling,
      interval: interval,
      anchor: anchor,
    );
  }

  /// An explicitly raised event, such as an app-owned lifecycle action.
  factory RitualInvitationPolicy.onEvent(String eventName) {
    if (eventName.trim().isEmpty) {
      throw ArgumentError.value(eventName, 'eventName', 'Must not be empty');
    }
    return RitualInvitationPolicy._(
      RitualInvitationCadence.event,
      eventName: eventName,
    );
  }

  final RitualInvitationCadence cadence;
  final Duration? interval;
  final DateTime? anchor;
  final String? eventName;

  /// Evaluates eligibility without changing [state].
  RitualInvitationDecision evaluate({
    required DateTime now,
    required RitualInvitationMode mode,
    required bool prerequisitesMet,
    required RitualInvitationState state,
    String? eventName,
    String? eventId,
  }) {
    final identity = _identity(now, eventName: eventName, eventId: eventId);
    if (mode == RitualInvitationMode.disabled) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.disabled,
        identity,
      );
    }
    if (mode == RitualInvitationMode.quiet) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.quiet,
        identity,
      );
    }
    if (!prerequisitesMet) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.prerequisitesNotMet,
        identity,
      );
    }
    if (identity == null) {
      return RitualInvitationDecision.no(RitualInvitationReason.notDue, null);
    }
    if (state.completedIdentity == identity) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.completed,
        identity,
      );
    }
    if (state.dismissedIdentity == identity) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.dismissed,
        identity,
      );
    }
    if (state.snoozedIdentity == identity &&
        state.snoozedUntil != null &&
        now.isBefore(state.snoozedUntil!)) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.snoozed,
        identity,
      );
    }
    final expiredSnooze =
        state.snoozedIdentity == identity &&
        state.snoozedUntil != null &&
        !now.isBefore(state.snoozedUntil!);
    if (state.lastShownIdentity == identity && !expiredSnooze) {
      return RitualInvitationDecision.no(
        RitualInvitationReason.alreadyShown,
        identity,
      );
    }
    return RitualInvitationDecision.yes(identity);
  }

  String? _identity(
    DateTime now, {
    required String? eventName,
    required String? eventId,
  }) {
    switch (cadence) {
      case RitualInvitationCadence.daily:
        return 'day:${_date(now)}';
      case RitualInvitationCadence.weekly:
        final monday = DateTime(now.year, now.month, now.day - now.weekday + 1);
        return 'week:${_date(monday)}';
      case RitualInvitationCadence.monthly:
        return 'month:${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
      case RitualInvitationCadence.rolling:
        final anchorUtc = anchor!.toUtc();
        final elapsed = now.toUtc().difference(anchorUtc);
        if (elapsed.isNegative) return null;
        final window = elapsed.inMicroseconds ~/ interval!.inMicroseconds;
        return 'rolling:${anchorUtc.toIso8601String()}:${interval!.inMicroseconds}:$window';
      case RitualInvitationCadence.event:
        if (eventName != this.eventName ||
            eventId == null ||
            eventId.trim().isEmpty) {
          return null;
        }
        return 'event:${_encodeIdentityPart(this.eventName!)}:${_encodeIdentityPart(eventId)}';
    }
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
}

/// Immutable result of evaluating a [RitualInvitationPolicy].
class RitualInvitationDecision {
  const RitualInvitationDecision._(
    this.shouldOffer,
    this.reason,
    this.identity,
  );

  const RitualInvitationDecision.yes(String identity)
    : this._(true, RitualInvitationReason.offered, identity);

  const RitualInvitationDecision.no(
    RitualInvitationReason reason,
    String? identity,
  ) : this._(false, reason, identity);

  final bool shouldOffer;
  final RitualInvitationReason reason;

  /// Civil-period identity or caller-provided event identity; null if an event
  /// schedule did not receive a matching event.
  final String? identity;
}

/// Persistable, immutable invitation facts, deliberately kept independent.
///
/// Dismissing or snoozing does not imply completion. A host can construct a
/// new value with one of the transition methods and save its v1 JSON.
/// Keep state per occurrence when event IDs may be replayed out of order;
/// this value stores the latest fact of each kind, not an event ledger.
class RitualInvitationState {
  const RitualInvitationState({
    this.lastShownAt,
    this.lastShownIdentity,
    this.dismissedAt,
    this.dismissedIdentity,
    this.snoozedUntil,
    this.snoozedIdentity,
    this.completedAt,
    this.completedIdentity,
  }) : assert((lastShownAt == null) == (lastShownIdentity == null)),
       assert((dismissedAt == null) == (dismissedIdentity == null)),
       assert((snoozedUntil == null) == (snoozedIdentity == null)),
       assert((completedAt == null) == (completedIdentity == null));

  final DateTime? lastShownAt;
  final String? lastShownIdentity;
  final DateTime? dismissedAt;
  final String? dismissedIdentity;
  final DateTime? snoozedUntil;
  final String? snoozedIdentity;
  final DateTime? completedAt;
  final String? completedIdentity;

  RitualInvitationState markShown(DateTime at, String identity) =>
      RitualInvitationState(
        lastShownAt: at,
        lastShownIdentity: _requireIdentity(identity),
        dismissedAt: dismissedAt,
        dismissedIdentity: dismissedIdentity,
        snoozedUntil:
            snoozedIdentity == identity &&
                snoozedUntil != null &&
                !at.isBefore(snoozedUntil!)
            ? null
            : snoozedUntil,
        snoozedIdentity:
            snoozedIdentity == identity &&
                snoozedUntil != null &&
                !at.isBefore(snoozedUntil!)
            ? null
            : snoozedIdentity,
        completedAt: completedAt,
        completedIdentity: completedIdentity,
      );

  RitualInvitationState dismiss(DateTime at, String identity) =>
      RitualInvitationState(
        lastShownAt: lastShownAt,
        lastShownIdentity: lastShownIdentity,
        dismissedAt: at,
        dismissedIdentity: _requireIdentity(identity),
        snoozedUntil: snoozedUntil,
        snoozedIdentity: snoozedIdentity,
        completedAt: completedAt,
        completedIdentity: completedIdentity,
      );

  RitualInvitationState snoozeUntil(DateTime until, String identity) =>
      RitualInvitationState(
        lastShownAt: lastShownAt,
        lastShownIdentity: lastShownIdentity,
        dismissedAt: dismissedAt,
        dismissedIdentity: dismissedIdentity,
        snoozedUntil: until,
        snoozedIdentity: _requireIdentity(identity),
        completedAt: completedAt,
        completedIdentity: completedIdentity,
      );

  RitualInvitationState complete(DateTime at, String identity) =>
      RitualInvitationState(
        lastShownAt: lastShownAt,
        lastShownIdentity: lastShownIdentity,
        dismissedAt: dismissedAt,
        dismissedIdentity: dismissedIdentity,
        snoozedUntil: snoozedUntil,
        snoozedIdentity: snoozedIdentity,
        completedAt: at,
        completedIdentity: _requireIdentity(identity),
      );

  Map<String, Object?> toJson() => {
    'version': 1,
    'lastShownAt': lastShownAt?.toUtc().toIso8601String(),
    'lastShownIdentity': lastShownIdentity,
    'dismissedAt': dismissedAt?.toUtc().toIso8601String(),
    'dismissedIdentity': dismissedIdentity,
    'snoozedUntil': snoozedUntil?.toUtc().toIso8601String(),
    'snoozedIdentity': snoozedIdentity,
    'completedAt': completedAt?.toUtc().toIso8601String(),
    'completedIdentity': completedIdentity,
  };

  /// Strictly reads v1 JSON, rejecting unknown keys and partial fact pairs.
  static RitualInvitationState read(Map<String, Object?> json) {
    const keys = {
      'version',
      'lastShownAt',
      'lastShownIdentity',
      'dismissedAt',
      'dismissedIdentity',
      'snoozedUntil',
      'snoozedIdentity',
      'completedAt',
      'completedIdentity',
    };
    if (json.length != keys.length ||
        !json.keys.toSet().containsAll(keys) ||
        json['version'] != 1) {
      throw const FormatException('Invalid or unsupported invitation state');
    }
    final shownAt = _readDate(json['lastShownAt']);
    final dismissedAt = _readDate(json['dismissedAt']);
    final snoozedUntil = _readDate(json['snoozedUntil']);
    final completedAt = _readDate(json['completedAt']);
    final shownId = _readOptionalIdentity(json['lastShownIdentity']);
    final dismissedId = _readOptionalIdentity(json['dismissedIdentity']);
    final snoozedId = _readOptionalIdentity(json['snoozedIdentity']);
    final completedId = _readOptionalIdentity(json['completedIdentity']);
    if (!_paired(shownAt, shownId) ||
        !_paired(dismissedAt, dismissedId) ||
        !_paired(snoozedUntil, snoozedId) ||
        !_paired(completedAt, completedId)) {
      throw const FormatException(
        'Invitation facts require both time and identity',
      );
    }
    return RitualInvitationState(
      lastShownAt: shownAt,
      lastShownIdentity: shownId,
      dismissedAt: dismissedAt,
      dismissedIdentity: dismissedId,
      snoozedUntil: snoozedUntil,
      snoozedIdentity: snoozedId,
      completedAt: completedAt,
      completedIdentity: completedId,
    );
  }
}

bool _paired(Object? time, String? identity) =>
    (time == null) == (identity == null);

DateTime? _readDate(Object? value) {
  if (value == null) return null;
  if (value is! String) throw const FormatException('Expected ISO date-time');
  try {
    final parsed = DateTime.parse(value);
    if (!parsed.isUtc || parsed.toIso8601String() != value) {
      throw const FormatException('Expected canonical UTC date-time');
    }
    return parsed;
  } on FormatException {
    throw const FormatException('Invalid ISO date-time');
  }
}

String? _readOptionalIdentity(Object? value) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw const FormatException('Invalid invitation identity');
  }
  return value;
}

String _requireIdentity(String value) {
  if (value.trim().isEmpty) throw ArgumentError.value(value, 'identity');
  return value;
}

String _encodeIdentityPart(String value) => Uri.encodeComponent(value);
