/// Customer reviews for ShipGlows Flutter apps.
///
/// Android, iOS, macOS, Windows and the web.
///
/// - [ShipglowsReviews]: opened once at startup. Counts launches and
///   successes; at the right moment ([ReviewPolicy]) asks the store for its
///   rating prompt, or shows the app's invitation where there is none
///   (Windows, the web); sends the form's reviews to the app's backend
///   through a [ReviewSink], keeping them on the device until it answers.
/// - [showShipglowsReviewInvitation]: that invitation, also on demand.
/// - [showShipglowsReviewForm] / [ShipglowsReviewForm]: stars, topic,
///   message, an optional address, consent to publish as a testimonial.
/// - [ShipglowsReviewSettings]: « Donner mon avis » and « Noter {app} »
///   (store page, or a [ReviewSite] such as Trustpilot).
/// - [ShipglowsStarRating]: the five stars alone.
/// - [ShipglowsReviewStrings] and [ShipglowsReviewStringsScope]: the texts.
/// - [CustomerReview]: what the backend receives, as plain JSON.
library;

export 'src/customer_review.dart';
export 'src/default_storage_io.dart'
    if (dart.library.js_interop) 'src/default_storage_web.dart';
export 'src/rating_page.dart';
export 'src/review_form.dart';
export 'src/review_invitation.dart';
export 'src/review_policy.dart';
export 'src/review_settings.dart';
export 'src/review_sink.dart';
export 'src/review_state.dart';
export 'src/reviews_config.dart';
export 'src/shipglows_reviews.dart';
export 'src/star_rating.dart';
export 'src/store_review.dart';
export 'src/strings.dart';
