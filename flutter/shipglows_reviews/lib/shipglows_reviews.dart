/// Customer reviews for ShipGlows Flutter apps.
///
/// - [ShipglowsReviews]: opened once at startup. Counts launches and
///   successes, asks the store for its rating prompt at the right moment
///   ([ReviewPolicy]), sends the form's reviews to the app's backend through
///   a [ReviewSink], keeping them on the device until it answers.
/// - [showShipglowsReviewForm] / [ShipglowsReviewForm]: stars, topic,
///   message, an optional address, consent to publish as a testimonial.
/// - [ShipglowsReviewSettings]: « Donner mon avis » and « Noter {app} ».
/// - [ShipglowsStarRating]: the five stars alone.
/// - [ShipglowsReviewStrings] and [ShipglowsReviewStringsScope]: the texts.
/// - [CustomerReview]: what the backend receives, as plain JSON.
library;

export 'src/customer_review.dart';
export 'src/review_form.dart';
export 'src/review_policy.dart';
export 'src/review_settings.dart';
export 'src/review_sink.dart';
export 'src/review_state.dart';
export 'src/reviews_config.dart';
export 'src/shipglows_reviews.dart';
export 'src/star_rating.dart';
export 'src/store_review.dart';
export 'src/strings.dart';
