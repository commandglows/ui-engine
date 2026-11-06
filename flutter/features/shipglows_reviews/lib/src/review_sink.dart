import 'customer_review.dart';

/// Where reviews go: the app's backend (a Convex mutation, a Firestore
/// collection, a REST endpoint). The package keeps unsent reviews on the
/// device and calls [send] again until it returns.
abstract interface class ReviewSink {
  /// Delivers [review]. Throwing keeps it for a later try; throwing
  /// [ReviewRejectedException] drops it (the backend will never take it).
  /// The same review may come twice after a lost answer: the backend keeps
  /// one per [CustomerReview.id].
  Future<void> send(CustomerReview review);
}

/// The backend refused a review for good (invalid data, unknown app): it is
/// dropped instead of retried forever.
final class ReviewRejectedException implements Exception {
  const ReviewRejectedException(this.message, {this.code});

  final String message;

  /// The backend's own code, when it gives one.
  final String? code;

  @override
  String toString() => 'Review rejected${code == null ? '' : ' ($code)'}: '
      '$message';
}

/// Plugs the app's backend call in without a dependency in this package:
///
/// ```dart
/// CallbackReviewSink((review) =>
///     convex.mutation('reviews:submit', review.toJson()));
/// ```
class CallbackReviewSink implements ReviewSink {
  const CallbackReviewSink(this._send);

  final Future<void> Function(CustomerReview review) _send;

  @override
  Future<void> send(CustomerReview review) => _send(review);
}

/// Keeps what it receives: tests, previews, demo mode. [failWith] makes the
/// next sends throw it until it is cleared.
class MemoryReviewSink implements ReviewSink {
  MemoryReviewSink();

  final List<CustomerReview> received = [];
  Object? failWith;

  @override
  Future<void> send(CustomerReview review) async {
    final error = failWith;
    if (error != null) throw error;
    if (received.every((sent) => sent.id != review.id)) received.add(review);
  }
}
