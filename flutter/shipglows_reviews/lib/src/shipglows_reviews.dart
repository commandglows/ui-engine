import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_settings/shipglows_settings.dart';
import 'package:url_launcher/url_launcher.dart';

import 'customer_review.dart';
import 'default_storage_io.dart'
    if (dart.library.js_interop) 'default_storage_web.dart';
import 'rating_page.dart';
import 'review_invitation.dart';
import 'review_policy.dart';
import 'review_sink.dart';
import 'review_state.dart';
import 'reviews_config.dart';
import 'store_review.dart';
import 'strings.dart';

/// What the settings rows and the form show.
@immutable
class ShipglowsReviewsStatus {
  const ShipglowsReviewsStatus({
    this.pending = 0,
    this.sending = false,
    this.ratingPage,
  });

  /// Reviews written and not yet accepted by the backend.
  final int pending;
  final bool sending;

  /// Where the person can rate the app publicly, or `null`.
  final RatingPage? ratingPage;

  bool get canRate => ratingPage != null;

  @override
  bool operator ==(Object other) =>
      other is ShipglowsReviewsStatus &&
      other.pending == pending &&
      other.sending == sending &&
      other.ratingPage == ratingPage;

  @override
  int get hashCode => Object.hash(pending, sending, ratingPage);
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

/// Customer reviews for one app, on Android, iOS, macOS, Windows and the
/// web: the store's rating prompt (or the app's own invitation where there
/// is none) at the right moment, the app's review form sent to its backend,
/// and the public rating page (store page or review site).
///
/// - [open] once at startup (after `WidgetsFlutterBinding.ensureInitialized`):
///   counts the launch and sends the reviews left from an earlier session.
/// - [recordPositiveMoment] after a success, [recordProblem] after an error.
///   With `followFeedback` (on by default) every success and error message
///   of `shipglows_feedback` counts by itself.
/// - [maybeAskForReview] at a natural break (back on the home screen, after
///   a task is done, never in the middle of one): when the [ReviewPolicy]
///   allows it, asks the store for its prompt (Google Play, App Store), or
///   shows the app's invitation (Windows, the web, sideloaded APKs).
/// - [submit] sends the form's review; [openRatingPage] opens the store page
///   or the review site.
///
/// Never asks how the person feels before choosing between the public page
/// and the private form: the stores and review sites forbid filtering who is
/// sent to rate. Both are offered to everyone.
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
    required Future<bool> Function(Uri url) openUrl,
  }) : _storage = storage,
       _openUrl = openUrl,
       _sink = sink,
       _store = store,
       _bucket = bucket,
       _clock = clock,
       _info = info,
       _state = state,
       _status = ValueNotifier(
         ShipglowsReviewsStatus(
           pending: state.outbox.length,
           ratingPage: _ratingPageOf(info, config),
         ),
       );

  /// Reads the device state and the store, counts this launch and starts
  /// sending the reviews left unsent. Never throws: an unreadable state
  /// starts afresh, an unreadable store disables the store prompt.
  ///
  /// [storage] defaults to `shipglows.reviews.json` in the app support
  /// folder (`%APPDATA%` on Windows), and to `localStorage` on the web; any
  /// `SettingsStorage` works, the app's own included (the state lives in its
  /// [bucket]). [store] defaults to [InAppReviewBackend] from [config].
  static Future<ShipglowsReviews> open({
    required ShipglowsReviewsConfig config,
    required ReviewSink sink,
    SettingsStorage? storage,
    StoreReviewBackend? store,
    String bucket = 'reviews',
    bool followFeedback = true,
    bool observeLifecycle = true,
    @visibleForTesting DateTime Function()? clock,
    @visibleForTesting Future<bool> Function(Uri url)? openUrl,
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
    var deviceStorage = storage;
    ReviewState state;
    try {
      deviceStorage ??= await defaultReviewStorage();
      state = ReviewState.fromJson(await deviceStorage.read(bucket));
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
      storage: deviceStorage ?? MemorySettingsStorage(),
      sink: sink,
      store: backend,
      bucket: bucket,
      clock: now,
      info: info,
      state: state,
      openUrl:
          openUrl ??
          (url) => launchUrl(url, mode: LaunchMode.externalApplication),
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
  final Future<bool> Function(Uri url) _openUrl;
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

  /// The store page, or else [ShipglowsReviewsConfig.reviewSite].
  RatingPage? get ratingPage => _ratingPageOf(_info, config);

  static RatingPage? _ratingPageOf(
    StoreInfo info,
    ShipglowsReviewsConfig config,
  ) {
    if (info.listing case final store?) return StoreRatingPage(store);
    if (config.reviewSite case final site?) return SiteRatingPage(site);
    return null;
  }

  /// The store's own prompt where the install has one; otherwise the app's
  /// invitation, unless [ShipglowsReviewsConfig.inviteWithoutStorePrompt] is
  /// off.
  bool get usesStorePrompt => _info.canPrompt;

  DateTime _now() => _clock().toUtc();

  String? get _version =>
      _info.appVersion.isEmpty ? null : _info.appVersion;

  /// Whether [maybeAskForReview] would ask now, or why not.
  ReviewEligibility get eligibility {
    if (!kReleaseMode && !config.promptInDebug) {
      return const ReviewNotYet(ReviewWait.debugBuild);
    }
    if (!_info.canPrompt && !config.inviteWithoutStorePrompt) {
      return const ReviewNotYet(ReviewWait.noPrompt);
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

  /// When [eligibility] allows it, asks for a review and returns `true`:
  /// the store's rating prompt where the install has one (the store decides
  /// whether it shows; the app never learns whether the person rated),
  /// otherwise the app's invitation ([showShipglowsReviewInvitation]) over
  /// [context]. Never throws.
  Future<bool> maybeAskForReview(
    BuildContext context, {
    required String appName,
    ShipglowsReviewStrings? strings,
  }) async {
    if (_disposed || _asking || eligibility is! ReviewEligible) return false;
    _asking = true;
    try {
      // Saved first: a crash during the prompt does not ask again at once.
      _state = _state.withPrompt(_now(), version: _version);
      await _save();
      if (_info.canPrompt) {
        await _store.requestReview();
      } else if (context.mounted) {
        await showShipglowsReviewInvitation(
          context,
          reviews: this,
          appName: appName,
          strings: strings,
        );
      }
    } on Object catch (error) {
      debugPrint('shipglows_reviews: review prompt failed: $error');
    } finally {
      _asking = false;
    }
    return true;
  }

  /// Opens [ratingPage]: the store page, or the review site in the browser.
  /// Afterwards the automatic prompt stops. Returns `false` when there is no
  /// page or it did not open.
  Future<bool> openRatingPage() async {
    final page = ratingPage;
    if (_disposed || page == null) return false;
    try {
      switch (page) {
        case StoreRatingPage():
          await _store.openListing();
        case SiteRatingPage(:final site):
          final url = Uri.tryParse(site.url);
          if (url == null || !await _openUrl(url)) return false;
      }
    } on Object catch (error) {
      debugPrint('shipglows_reviews: rating page did not open: $error');
      return false;
    }
    _state = _state.copyWith(ratedOnStoreAt: _now());
    await _save();
    return true;
  }

  /// « Ne plus me demander »: no automatic prompt or invitation any more.
  /// The form and the settings rows stay.
  Future<void> optOut() {
    if (_disposed) return Future.value();
    _state = _state.copyWith(optedOutAt: _now());
    return _save();
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
      ratingPage: ratingPage,
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
