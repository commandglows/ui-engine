import 'package:flutter/foundation.dart';

import 'customer_review.dart';

/// What the device remembers between launches: the counters the
/// `ReviewPolicy` reads, and the reviews not sent yet.
/// Saved as one JSON object; bad stored data reads as a fresh state.
@immutable
class ReviewState {
  const ReviewState({
    this.firstSeenAt,
    this.launches = 0,
    this.positiveMoments = 0,
    this.lastProblemAt,
    this.prompts = const [],
    this.promptedVersion,
    this.lastReviewAt,
    this.ratedOnStoreAt,
    this.optedOutAt,
    this.outbox = const [],
  });

  /// Prompt dates kept: enough for any yearly limit.
  static const maxPromptsKept = 12;

  /// The install date, or the first launch with this package.
  final DateTime? firstSeenAt;
  final int launches;

  /// Successes since the last prompt.
  final int positiveMoments;
  final DateTime? lastProblemAt;

  /// When the store prompt was asked for or the invitation shown, oldest
  /// first. The system may have
  /// shown nothing: Google Play and Apple keep their own quotas.
  final List<DateTime> prompts;

  /// The app version of the last prompt.
  final String? promptedVersion;

  /// The last review sent through the app's own form.
  final DateTime? lastReviewAt;

  /// The person opened the rating page (store or review site) from the app.
  final DateTime? ratedOnStoreAt;

  /// The person chose « Ne plus me demander » in the app's invitation.
  final DateTime? optedOutAt;

  /// Reviews written and not yet accepted by the backend, oldest first.
  final List<CustomerReview> outbox;

  DateTime? get lastPromptAt => prompts.isEmpty ? null : prompts.last;

  ReviewState copyWith({
    DateTime? firstSeenAt,
    int? launches,
    int? positiveMoments,
    DateTime? lastProblemAt,
    List<DateTime>? prompts,
    String? promptedVersion,
    DateTime? lastReviewAt,
    DateTime? ratedOnStoreAt,
    DateTime? optedOutAt,
    List<CustomerReview>? outbox,
  }) => ReviewState(
    firstSeenAt: firstSeenAt ?? this.firstSeenAt,
    launches: launches ?? this.launches,
    positiveMoments: positiveMoments ?? this.positiveMoments,
    lastProblemAt: lastProblemAt ?? this.lastProblemAt,
    prompts: prompts ?? this.prompts,
    promptedVersion: promptedVersion ?? this.promptedVersion,
    lastReviewAt: lastReviewAt ?? this.lastReviewAt,
    ratedOnStoreAt: ratedOnStoreAt ?? this.ratedOnStoreAt,
    optedOutAt: optedOutAt ?? this.optedOutAt,
    outbox: outbox ?? this.outbox,
  );

  /// [at] added to [prompts], the oldest dropped past [maxPromptsKept].
  ReviewState withPrompt(DateTime at, {required String? version}) {
    final all = [...prompts, at.toUtc()];
    return copyWith(
      prompts: all.length > maxPromptsKept
          ? all.sublist(all.length - maxPromptsKept)
          : all,
      promptedVersion: version,
      positiveMoments: 0,
    );
  }

  Map<String, Object?> toJson() => {
    'version': 1,
    'firstSeenAt': _time(firstSeenAt),
    'launches': launches,
    'positiveMoments': positiveMoments,
    'lastProblemAt': _time(lastProblemAt),
    'prompts': [for (final at in prompts) at.millisecondsSinceEpoch],
    'promptedVersion': promptedVersion,
    'lastReviewAt': _time(lastReviewAt),
    'ratedOnStoreAt': _time(ratedOnStoreAt),
    'optedOutAt': _time(optedOutAt),
    'outbox': [for (final review in outbox) review.toJson()],
  };

  static ReviewState fromJson(Map<String, Object?>? json) {
    if (json == null) return const ReviewState();
    final prompts = json['prompts'];
    final outbox = json['outbox'];
    return ReviewState(
      firstSeenAt: _readTime(json['firstSeenAt']),
      launches: _count(json['launches']),
      positiveMoments: _count(json['positiveMoments']),
      lastProblemAt: _readTime(json['lastProblemAt']),
      prompts: prompts is List
          ? [
              for (final at in prompts)
                if (_readTime(at) case final time?) time,
            ]
          : const [],
      promptedVersion: json['promptedVersion'] is String
          ? json['promptedVersion']! as String
          : null,
      lastReviewAt: _readTime(json['lastReviewAt']),
      ratedOnStoreAt: _readTime(json['ratedOnStoreAt']),
      optedOutAt: _readTime(json['optedOutAt']),
      outbox: outbox is List
          ? [
              for (final entry in outbox)
                if (entry is Map)
                  if (CustomerReview.tryFromJson(entry.cast<String, Object?>())
                      case final review?)
                    review,
            ]
          : const [],
    );
  }

  static int? _time(DateTime? at) => at?.millisecondsSinceEpoch;

  static DateTime? _readTime(Object? value) => value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
      : null;

  static int _count(Object? value) =>
      value is num && value >= 0 ? value.toInt() : 0;
}
