import 'package:flutter/foundation.dart';

import 'review_policy.dart';

/// The app's reviews setup, given once to `ShipglowsReviews.open`.
@immutable
class ShipglowsReviewsConfig {
  const ShipglowsReviewsConfig({
    required this.appId,
    this.appStoreId = '',
    this.microsoftStoreId = '',
    this.playStoreListed = false,
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

  /// When the store prompt is asked for.
  final ReviewPolicy policy;

  /// Lets debug and profile builds ask for the store prompt (to try it with
  /// Google Play's internal app sharing or a TestFlight build). Off: the
  /// automatic prompt never interrupts development.
  final bool promptInDebug;
}
