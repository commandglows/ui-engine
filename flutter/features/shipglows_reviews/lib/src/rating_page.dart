import 'package:flutter/foundation.dart';

import 'customer_review.dart';

/// A public page where people rate the app outside the stores (Trustpilot,
/// Google reviews, G2, Product Hunt): for installs without a store page,
/// such as Windows installer builds and the web.
@immutable
class ReviewSite {
  const ReviewSite({required this.name, required this.url});

  /// Shown in « Noter sur {name} » (`Trustpilot`).
  final String name;

  /// HTTPS address of the page where a review is written.
  final String url;

  @override
  bool operator ==(Object other) =>
      other is ReviewSite && other.name == name && other.url == url;

  @override
  int get hashCode => Object.hash(name, url);
}

/// Where the person can rate the app publicly: its store page, or else the
/// app's [ReviewSite].
sealed class RatingPage {
  const RatingPage();
}

final class StoreRatingPage extends RatingPage {
  const StoreRatingPage(this.store);

  final ReviewStore store;

  @override
  bool operator ==(Object other) =>
      other is StoreRatingPage && other.store == store;

  @override
  int get hashCode => store.hashCode;
}

final class SiteRatingPage extends RatingPage {
  const SiteRatingPage(this.site);

  final ReviewSite site;

  @override
  bool operator ==(Object other) =>
      other is SiteRatingPage && other.site == site;

  @override
  int get hashCode => site.hashCode;
}
