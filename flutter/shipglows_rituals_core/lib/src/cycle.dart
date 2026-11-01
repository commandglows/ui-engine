/// Generic, storage-independent links between intentions and reviews.
///
/// Text and identifiers are supplied and stored by the host application. No
/// product-specific prompts, health fields, scores or persistence are defined.
class RitualIntentionSnapshot {
  const RitualIntentionSnapshot({
    required this.id,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String text;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  /// Strict v1 reader; malformed or forward-versioned data is never blanked.
  static RitualIntentionSnapshot read(Map<String, Object?> json) {
    _requireKeys(json, const {'version', 'id', 'text', 'createdAt'});
    if (json['version'] != 1 ||
        json['id'] is! String ||
        (json['id'] as String).trim().isEmpty ||
        json['text'] is! String ||
        (json['createdAt'] is! String)) {
      throw const FormatException('Invalid or unsupported intention snapshot');
    }
    return RitualIntentionSnapshot(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: _parseDate(json['createdAt'] as String),
    );
  }

  /// Human-readable text, preserving the supplied snapshot verbatim.
  String toReadableText() => text;
}

/// A review linked to the intention and previous review it was written against.
///
/// Both links retain an optional text snapshot so a host can render the context
/// even after its original intention or review has been edited or removed.
class RitualCycleReview {
  const RitualCycleReview({
    required this.id,
    required this.text,
    required this.createdAt,
    this.intentionId,
    this.intentionTextSnapshot,
    this.previousReviewId,
    this.previousReviewTextSnapshot,
  }) : assert((intentionId == null) == (intentionTextSnapshot == null)),
       assert(
         (previousReviewId == null) == (previousReviewTextSnapshot == null),
       );

  final String id;
  final String text;
  final DateTime createdAt;
  final String? intentionId;
  final String? intentionTextSnapshot;
  final String? previousReviewId;
  final String? previousReviewTextSnapshot;

  Map<String, Object?> toJson() => {
    'version': 1,
    'id': id,
    'text': text,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'intentionId': intentionId,
    'intentionTextSnapshot': intentionTextSnapshot,
    'previousReviewId': previousReviewId,
    'previousReviewTextSnapshot': previousReviewTextSnapshot,
  };

  /// Strict v1 reader; each reference and its readable snapshot are paired.
  static RitualCycleReview read(Map<String, Object?> json) {
    _requireKeys(json, const {
      'version',
      'id',
      'text',
      'createdAt',
      'intentionId',
      'intentionTextSnapshot',
      'previousReviewId',
      'previousReviewTextSnapshot',
    });
    final intentionId = _optionalText(json['intentionId'], 'intentionId');
    final intentionSnapshot = _optionalText(
      json['intentionTextSnapshot'],
      'intentionTextSnapshot',
    );
    final previousId = _optionalText(
      json['previousReviewId'],
      'previousReviewId',
    );
    final previousSnapshot = _optionalText(
      json['previousReviewTextSnapshot'],
      'previousReviewTextSnapshot',
    );
    if (json['version'] != 1 ||
        json['id'] is! String ||
        (json['id'] as String).trim().isEmpty ||
        json['text'] is! String ||
        json['createdAt'] is! String ||
        (intentionId == null) != (intentionSnapshot == null) ||
        (previousId == null) != (previousSnapshot == null)) {
      throw const FormatException('Invalid or unsupported cycle review');
    }
    return RitualCycleReview(
      id: json['id'] as String,
      text: json['text'] as String,
      createdAt: _parseDate(json['createdAt'] as String),
      intentionId: intentionId,
      intentionTextSnapshot: intentionSnapshot,
      previousReviewId: previousId,
      previousReviewTextSnapshot: previousSnapshot,
    );
  }

  /// Readable summary including retained link snapshots when present.
  String toReadableText({
    String intentionLabel = 'Intention',
    String previousReviewLabel = 'Previous review',
  }) {
    final lines = <String>[];
    if (intentionTextSnapshot != null) {
      lines.add('$intentionLabel: $intentionTextSnapshot');
    }
    if (previousReviewTextSnapshot != null) {
      lines.add('$previousReviewLabel: $previousReviewTextSnapshot');
    }
    lines.add(text);
    return lines.join('\n\n');
  }
}

void _requireKeys(Map<String, Object?> json, Set<String> expected) {
  if (json.length != expected.length ||
      !json.keys.toSet().containsAll(expected)) {
    throw const FormatException('Invalid or unsupported cycle data');
  }
}

String? _optionalText(Object? value, String field) {
  if (value == null) return null;
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Invalid $field');
  }
  return value;
}

DateTime _parseDate(String value) {
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
