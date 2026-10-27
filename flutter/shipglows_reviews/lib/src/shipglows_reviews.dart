import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

import 'customer_review.dart';
import 'review_policy.dart';
import 'review_sink.dart';
import 'review_state.dart';
import 'reviews_config.dart';
import 'store_review.dart';

/// What the settings rows and the form show.
@immutable
class ShipglowsReviewsStatus {
  const ShipglowsReviewsStatus({
    this.pending = 0,
    this.sending = false,
    this.listing,
  });

  /// Reviews written and not yet accepted by the backend.
  final int pending;
  final bool sending;

  /// The store page where the person can rate the app, or `null`.
  final ReviewStore? listing;

  bool get canRateOnStore => listing != null;

  @override
  bool operator ==(Object other) =>
      other is ShipglowsReviewsStatus &&
      other.pending == pending &&
      other.sending == sending &&
      other.listing == listing;

  @override
  int get hashCode => Object.hash(pending, sending, listing);
}

/// How a review left the form.
enum ReviewSendResult {
  /// The backend accepted it.
  sent,

  /// Saved on the device; sent as soon as the backend answers.
  queued,
}

/// The review could neither be sent nor saved on the device: the form keeps
/// what the person wrote and offers to try again.
final class ReviewNotSavedException implements Exception {
  const ReviewNotSavedException(this.cause);

  final Object cause;

  @override
  String toString() => 'Review not saved: $cause';
}

/// Customer reviews for one app: the store's rating prompt at the right
/// moment, the app's own review form sent to its backend, and the store
/// page.
///
/// - [open] once at startup (after `WidgetsFlutterBinding.ensureInitialized`):
///   counts the launch and sends the reviews left from an earlier session.
/// - [recordPositiveMoment] after a success, [recordProblem] after an error.
///   With `followFeedback` (on by default) every success and error message
///   of `shipglows_feedback` counts by itself.
/// - [maybeAskForStoreReview] at a natural break (back on the home screen,
///   after a task is done, never in the middle of one): asks the store for
///   its prompt when the [ReviewPolicy] allows it.
/// - [submit] sends the form's review; [rateOnStore] opens the store page.
///
/// Never asks how the person feels before choosing between the store and the
/// private form: both stores forbid filtering who is sent to rate. The form
/// and the store are offered to everyone.
class ShipglowsReviews with WidgetsBindingObserver {
  ShipglowsReviews._({
    required this.config,
    required SettingsStorage storage,
    required ReviewSink sink,
    required StoreReviewBackend store,
    required String bucket,
    required DateTime Function() clock,
    required StoreInfo info,
    required ReviewState state,
  }) : _storage = storage,
       _sink = sink,
       _store = store,
       _bucket = bucket,
       _clock = clock,
       _info = info,
       _state = state,
       _status = ValueNotifier(
         ShipglowsReviewsStatus(
           pending: state.outbox.length,
           listing: info.listing,
         ),
       );

  /// Reads the device state and the store, counts this launch and starts
  /// sending the reviews left unsent. Never throws: an unreadable state
  /// starts afresh, an unreadable store disables the store prompt.
  ///
  /// [storage] is the app's settings storage (`FileSettingsStorage` on the
  /// app support folder, a `CallbackSettingsStorage` on the web); the state
  /// lives in its [bucket]. [store] defaults to [InAppReviewBackend] from
  /// [config].
  static Future<ShipglowsReviews> open({
    required ShipglowsReviewsConfig config,
    required SettingsStorage storage,
    required ReviewSink sink,
    StoreReviewBackend? store,
    String bucket = 'reviews',
    bool followFeedback = true,
    bool observeLifecycle = true,
    @visibleForTesting DateTime Function()? clock,
  }) async {
    final backend =
        store ??
        InAppReviewBackend(
          appStoreId: config.appStoreId,
          microsoftStoreId: config.microsoftStoreId,
          playStoreListed: config.playStoreListed,
        );
    final now = clock ?? DateTime.now;
    StoreInfo info;
    try {
      info = await backend.load();
    } on Object catch (error) {
      debugPrint('shipglows_reviews: store unavailable: $error');
      info = StoreInfo(platform: currentPlatformName());
    }
    ReviewState state;
    try {
      state = ReviewState.fromJson(await storage.read(bucket));
    } on Object catch (error) {
      debugPrint('shipglows_reviews: state unreadable, starting afresh: $error');
      state = const ReviewState();
    }
    final today = now().toUtc();
    final installedAt = info.installedAt;
    state = state.copyWith(
      firstSeenAt:
          state.firstSeenAt ??
          (installedAt != null && installedAt.isBefore(today)
              ? installedAt
              : today),
      launches: state.launches + 1,
    );
    final reviews = ShipglowsReviews._(
      config: config,
      storage: storage,
      sink: sink,
      store: backend,
      bucket: bucket,
      clock: now,
      info: info,
      state: state,
    );
    await reviews._save();
    if (observeLifecycle) WidgetsBinding.instance.addObserver(reviews);
    reviews._observing = observeLifecycle;
    if (followFeedback) reviews._followFeedback();
    unawaited(reviews.flush());
    return reviews;
  }

  final ShipglowsReviewsConfig config;
  final SettingsStorage _storage;
  final ReviewSink _sink;
  final StoreReviewBackend _store;
  final String _bucket;
  final DateTime Function() _clock;
  final StoreInfo _info;
  final ValueNotifier<ShipglowsReviewsStatus> _status;

  ReviewState _state;
  Future<void> _writes = Future.value();
  Future<void>? _flushing;
  final Map<String, ReviewRejectedException> _rejected = {};
  Object? _lastSendError;
  Timer? _retry;
  Duration _retryDelay = _firstRetry;
  bool _asking = false;
  bool _observing = false;
  bool _disposed = false;
  void Function(FeedbackRecord record)? _feedbackListener;

  static const _firstRetry = Duration(seconds: 30);
  static const _maxRetry = Duration(minutes: 5);

  /// The signed-in account id, sent with the next reviews; `null` when
  /// signed out. The app sets it when the account changes.
  String? accountId;

  ValueListenable<ShipglowsReviewsStatus> get status => _status;

  /// This install, as read at [open].
  StoreInfo get storeInfo => _info;

  /// The device state, for diagnostics.
  ReviewState get state => _state;

  bool get canRateOnStore => _info.listing != null;

  DateTime _now() => _clock().toUtc();

  String? get _version =>
      _info.appVersion.isEmpty ? null : _info.appVersion;

  /// Whether [maybeAskForStoreReview] would ask now, or why not.
  ReviewEligibility get eligibility {
    if (!kReleaseMode && !config.promptInDebug) {
      return const ReviewNotYet(ReviewWait.debugBuild);
    }
    if (!_info.canPrompt) {
      return const ReviewNotYet(ReviewWait.storeUnavailable);
    }
    return config.policy.evaluate(_state, now: _now(), version: _version);
  }

  /// A success: a task done, a file exported, a goal reached.
  Future<void> recordPositiveMoment() {
    if (_disposed) return Future.value();
    _state = _state.copyWith(positiveMoments: _state.positiveMoments + 1);
    return _save();
  }

  /// An error the person saw: the store prompt waits
  /// [ReviewPolicy.quietAfterProblem].
  Future<void> recordProblem() {
    if (_disposed) return Future.value();
    _state = _state.copyWith(lastProblemAt: _now());
    return _save();
  }

  /// Asks the store for its rating prompt when [eligibility] allows it, and
  /// returns whether it asked. The store decides whether a prompt shows; the
  /// app never learns whether the person rated. Never throws.
  Future<bool> maybeAskForStoreReview() async {
    if (_disposed || _asking || eligibility is! ReviewEligible) return false;
    _asking = true;
    try {
      // Saved first: a crash during the prompt does not ask again at once.
      _state = _state.withPrompt(_now(), version: _version);
      await _save();
      await _store.requestReview();
    } on Object catch (error) {
      debugPrint('shipglows_reviews: review prompt failed: $error');
    } finally {
      _asking = false;
    }
    return true;
  }

  /// Opens the store page to rate the app; afterwards the automatic prompt
  /// stops. Returns `false` when there is no store page or it did not open.
  Future<bool> rateOnStore() async {
    if (_disposed || _info.listing == null) return false;
    try {
      await _store.openListing();
    } on Object catch (error) {
      debugPrint('shipglows_reviews: store page did not open: $error');
      return false;
    }
    _state = _state.copyWith(ratedOnStoreAt: _now());
    await _save();
    return true;
  }

  /// Saves [draft] on the device, then sends it.
  ///
  /// Throws [ArgumentError] when [draft] is not valid,
  /// [ReviewRejectedException] when the backend refuses it for good, and
  /// [ReviewNotSavedException] when it could neither be sent nor saved.
  /// [locale] is the app's locale, sent with the review.
  Future<ReviewSendResult> submit(ReviewDraft draft, {Locale? locale}) async {
    if (!draft.isValid) {
      throw ArgumentError.value(
        draft,
        'draft',
        'needs a rating or a message, and a valid email',
      );
    }
    if (_disposed) throw StateError('ShipglowsReviews is disposed.');
    final now = _now();
    final review = CustomerReview.fromDraft(
      draft,
      context: ReviewContext(
        appId: config.appId,
        platform: _info.platform,
        appVersion: _info.appVersion,
        buildNumber: _info.buildNumber,
        locale: locale?.toLanguageTag() ?? '',
        installSource: _info.installSource,
      ),
      createdAt: now,
      accountId: accountId,
    );
    _state = _state.copyWith(
      outbox: [..._state.outbox, review],
      lastReviewAt: now,
    );
    _emit();
    final saved = await _save();
    await flush();
    if (_rejected.remove(review.id) case final rejection?) throw rejection;
    if (_state.outbox.every((entry) => entry.id != review.id)) {
      return ReviewSendResult.sent;
    }
    if (saved) return ReviewSendResult.queued;
    // Kept nowhere but here: taken back so a new try does not send it twice.
    _state = _state.copyWith(
      outbox: [
        for (final entry in _state.outbox)
          if (entry.id != review.id) entry,
      ],
    );
    _emit();
    throw ReviewNotSavedException(_lastSendError ?? 'storage');
  }

  /// Sends the unsent reviews, oldest first, and stops at the first failure
  /// (then tries again after 30 s, doubling up to 5 min, and on app resume).
  /// One run at a time; never throws.
  Future<void> flush() => _flushing ??= _flushOutbox().whenComplete(() {
    _flushing = null;
  });

  Future<void> _flushOutbox() async {
    _retry?.cancel();
    _retry = null;
    while (!_disposed && _state.outbox.isNotEmpty) {
      final review = _state.outbox.first;
      _emit(sending: true);
      try {
        await _sink.send(review);
        _lastSendError = null;
      } on ReviewRejectedException catch (error) {
        debugPrint('shipglows_reviews: review ${review.id} dropped: $error');
        _rejected[review.id] = error;
      } on Object catch (error) {
        debugPrint('shipglows_reviews: review ${review.id} not sent: $error');
        _lastSendError = error;
        _scheduleRetry();
        break;
      }
      _retryDelay = _firstRetry;
      _state = _state.copyWith(
        outbox: [
          for (final entry in _state.outbox)
            if (entry.id != review.id) entry,
        ],
      );
      await _save();
    }
    _emit(sending: false);
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _retry?.cancel();
    _retry = Timer(_retryDelay, () => unawaited(flush()));
    final doubled = _retryDelay * 2;
    _retryDelay = doubled > _maxRetry ? _maxRetry : doubled;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState lifecycle) {
    if (lifecycle == AppLifecycleState.resumed && _state.outbox.isNotEmpty) {
      unawaited(flush());
    }
  }

  void _followFeedback() {
    void listener(FeedbackRecord record) {
      switch (record.kind) {
        case FeedbackKind.success:
          unawaited(recordPositiveMoment());
        case FeedbackKind.error:
          unawaited(recordProblem());
        case FeedbackKind.info:
        case FeedbackKind.warning:
          break;
      }
    }

    _feedbackListener = listener;
    FeedbackLog.addListener(listener);
  }

  void _emit({bool? sending}) {
    if (_disposed) return;
    _status.value = ShipglowsReviewsStatus(
      pending: _state.outbox.length,
      sending: sending ?? _status.value.sending,
      listing: _info.listing,
    );
  }

  /// Writes the current state after the writes already queued; `false` when
  /// the storage failed (logged, never thrown).
  Future<bool> _save() {
    final data = _state.toJson();
    final write = _writes.then((_) => _storage.write(_bucket, data));
    _writes = write.then<void>((_) {}, onError: (Object _) {});
    return write.then<bool>(
      (_) => true,
      onError: (Object error) {
        debugPrint('shipglows_reviews: state not saved: $error');
        return false;
      },
    );
  }

  /// Stops the retries and listeners. Unsent reviews stay on the device for
  /// the next [open].
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _retry?.cancel();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    if (_feedbackListener case final listener?) {
      FeedbackLog.removeListener(listener);
    }
    _status.dispose();
  }
}
