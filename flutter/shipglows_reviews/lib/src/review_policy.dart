import 'package:flutter/foundation.dart';

import 'review_state.dart';

/// Why no review is asked for now.
enum ReviewWait {
  /// A debug or profile build ([ShipglowsReviewsConfig.promptInDebug]).
  debugBuild,

  /// This install has no store prompt (outside Google Play and the App
  /// Store) and the app's own invitation is off
  /// ([ShipglowsReviewsConfig.inviteWithoutStorePrompt]).
  noPrompt,

  /// The person already opened the rating page from the app.
  alreadyRated,

  /// The person chose « Ne plus me demander ».
  optedOut,

  /// [ReviewPolicy.maxPromptsPerYear] reached.
  yearlyLimit,

  /// The last prompt is more recent than [ReviewPolicy.minTimeBetweenPrompts].
  recentPrompt,

  /// Already asked during this version ([ReviewPolicy.oncePerVersion]).
  sameVersion,

  /// The person sent a review through the app's own form lately.
  recentOwnReview,

  /// An error was shown lately ([ReviewPolicy.quietAfterProblem]).
  recentProblem,

  /// Installed for less than [ReviewPolicy.minTimeInstalled].
  tooNew,

  /// Fewer launches than [ReviewPolicy.minLaunches].
  fewLaunches,

  /// Fewer successes than [ReviewPolicy.minPositiveMoments] since the last
  /// prompt.
  fewPositiveMoments,
}

/// Whether a review may be asked for now.
sealed class ReviewEligibility {
  const ReviewEligibility();
}

final class ReviewEligible extends ReviewEligibility {
  const ReviewEligible();
}

final class ReviewNotYet extends ReviewEligibility {
  const ReviewNotYet(this.reason);

  final ReviewWait reason;

  @override
  bool operator ==(Object other) =>
      other is ReviewNotYet && other.reason == reason;

  @override
  int get hashCode => reason.hashCode;

  @override
  String toString() => 'ReviewNotYet(${reason.name})';
}

/// When a review is asked for (the store's rating prompt, or the app's own
/// invitation where there is none): someone who has used the app for a while, just succeeded at something, has not met an error
/// lately, and was not asked recently. Google Play and Apple add their own
/// quotas on top (Apple: three times a year at most), so asking does not
/// mean a prompt is shown.
///
/// The defaults follow the stores' guidance; an app changes a threshold,
/// not the rule.
@immutable
class ReviewPolicy {
  const ReviewPolicy({
    this.minTimeInstalled = const Duration(days: 7),
    this.minLaunches = 5,
    this.minPositiveMoments = 3,
    this.quietAfterProblem = const Duration(days: 3),
    this.quietAfterOwnReview = const Duration(days: 30),
    this.minTimeBetweenPrompts = const Duration(days: 120),
    this.maxPromptsPerYear = 3,
    this.oncePerVersion = true,
  });

  final Duration minTimeInstalled;
  final int minLaunches;
  final int minPositiveMoments;
  final Duration quietAfterProblem;
  final Duration quietAfterOwnReview;
  final Duration minTimeBetweenPrompts;
  final int maxPromptsPerYear;

  /// At most one prompt per app version.
  final bool oncePerVersion;

  static const _year = Duration(days: 365);

  /// The first rule [state] does not meet at [now], or [ReviewEligible].
  /// [version] is the running app version (`null` when unknown).
  ReviewEligibility evaluate(
    ReviewState state, {
    required DateTime now,
    required String? version,
  }) {
    bool within(DateTime? at, Duration window) =>
        at != null && now.difference(at) < window;

    if (state.ratedOnStoreAt != null) {
      return const ReviewNotYet(ReviewWait.alreadyRated);
    }
    if (state.optedOutAt != null) {
      return const ReviewNotYet(ReviewWait.optedOut);
    }
    final lastYear = state.prompts.where((at) => within(at, _year)).length;
    if (lastYear >= maxPromptsPerYear) {
      return const ReviewNotYet(ReviewWait.yearlyLimit);
    }
    if (within(state.lastPromptAt, minTimeBetweenPrompts)) {
      return const ReviewNotYet(ReviewWait.recentPrompt);
    }
    if (oncePerVersion &&
        version != null &&
        version.isNotEmpty &&
        state.promptedVersion == version) {
      return const ReviewNotYet(ReviewWait.sameVersion);
    }
    if (within(state.lastReviewAt, quietAfterOwnReview)) {
      return const ReviewNotYet(ReviewWait.recentOwnReview);
    }
    if (within(state.lastProblemAt, quietAfterProblem)) {
      return const ReviewNotYet(ReviewWait.recentProblem);
    }
    final firstSeen = state.firstSeenAt;
    if (firstSeen == null || now.difference(firstSeen) < minTimeInstalled) {
      return const ReviewNotYet(ReviewWait.tooNew);
    }
    if (state.launches < minLaunches) {
      return const ReviewNotYet(ReviewWait.fewLaunches);
    }
    if (state.positiveMoments < minPositiveMoments) {
      return const ReviewNotYet(ReviewWait.fewPositiveMoments);
    }
    return const ReviewEligible();
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewPolicy &&
      other.minTimeInstalled == minTimeInstalled &&
      other.minLaunches == minLaunches &&
      other.minPositiveMoments == minPositiveMoments &&
      other.quietAfterProblem == quietAfterProblem &&
      other.quietAfterOwnReview == quietAfterOwnReview &&
      other.minTimeBetweenPrompts == minTimeBetweenPrompts &&
      other.maxPromptsPerYear == maxPromptsPerYear &&
      other.oncePerVersion == oncePerVersion;

  @override
  int get hashCode => Object.hash(
    minTimeInstalled,
    minLaunches,
    minPositiveMoments,
    quietAfterProblem,
    quietAfterOwnReview,
    minTimeBetweenPrompts,
    maxPromptsPerYear,
    oncePerVersion,
  );
}
