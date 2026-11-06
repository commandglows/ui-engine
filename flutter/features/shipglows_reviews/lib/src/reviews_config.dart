import 'package:flutter/foundation.dart';

import 'rating_page.dart';
import 'review_policy.dart';

/// The app's reviews setup, given once to `ShipglowsReviews.open`.
@immutable
class ShipglowsReviewsConfig {
  const ShipglowsReviewsConfig({
    required this.appId,
    this.appStoreId = '',
    this.microsoftStoreId = '',
    this.playStoreListed = false,
    this.reviewSite,
    this.inviteWithoutStorePrompt = true,
    this.policy = const ReviewPolicy(),
    this.promptInDebug = false,
  });

  /// The app's stable id (`commandglows`), sent with every review so one
  /// backend can collect them for several apps.
  final String appId;

  /// App Store id (`1234567890`) for iOS and macOS; empty when the app is
  /// not on the App Store.
  final String appStoreId;

  /// Microsoft Store product id (`9NBLGGH4R315`); empty when the app is not
  /// on the Microsoft Store.
  final String microsoftStoreId;

  /// The app is on Google Play: a sideloaded Android copy can still open its
  /// Play page to rate it.
  final bool playStoreListed;

  /// The public page to rate the app where it has no store page (Windows
  /// installer builds, the web, sideloaded APKs); `null` offers the form
  /// only there.
  final ReviewSite? reviewSite;

  /// Where the store has no rating prompt (Windows, the web, sideloaded
  /// APKs), the app shows its own invitation at the same moments: the form,
  /// the [reviewSite], « Plus tard », « Ne plus me demander ». No store rule
  /// applies there; the invitation still offers the same choices to
  /// everyone.
  final bool inviteWithoutStorePrompt;

  /// When the store prompt or the invitation is shown.
  final ReviewPolicy policy;

  /// Lets debug and profile builds ask (to try the invitation, or the store
  /// prompt with Google Play's internal app sharing or TestFlight). Off: the
  /// automatic prompt never interrupts development.
  final bool promptInDebug;
}
