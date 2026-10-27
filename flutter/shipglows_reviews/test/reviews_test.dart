import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shipglows_feedback/shipglows_feedback.dart';
import 'package:shipglows_reviews/shipglows_reviews.dart';
import 'package:shipglows_settings/shipglows_settings.dart';

class FakeStore implements StoreReviewBackend {
  FakeStore({this.canPrompt = true, this.listing = ReviewStore.googlePlay});

  final bool canPrompt;
  final ReviewStore? listing;
  int requests = 0;
  int listingsOpened = 0;

  @override
  Future<StoreInfo> load() async => StoreInfo(
    platform: 'android',
    installSource: InstallSource.googlePlay,
    appVersion: '1.2.0',
    buildNumber: '12',
    installedAt: DateTime.utc(2026),
    canPrompt: canPrompt,
    listing: listing,
  );

  @override
  Future<void> requestReview() async {
    requests++;
  }

  @override
  Future<void> openListing() async {
    listingsOpened++;
  }
}

class FailingStorage extends MemorySettingsStorage {
  @override
  Future<void> write(String bucket, Map<String, Object?> data) =>
      throw StateError('disk full');
}

const config = ShipglowsReviewsConfig(appId: 'testglows', promptInDebug: true);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  var now = DateTime.utc(2026, 6);
  DateTime clock() => now;

  setUp(() => now = DateTime.utc(2026, 6));

  final openedUrls = <Uri>[];

  Future<ShipglowsReviews> open({
    SettingsStorage? storage,
    ReviewSink? sink,
    FakeStore? store,
    ShipglowsReviewsConfig settings = config,
  }) => ShipglowsReviews.open(
    config: settings,
    storage: storage ?? MemorySettingsStorage(),
    sink: sink ?? MemoryReviewSink(),
    store: store ?? FakeStore(),
    followFeedback: false,
    observeLifecycle: false,
    clock: clock,
    openUrl: (url) async {
      openedUrls.add(url);
      return true;
    },
  );

  /// A screen whose context the prompts are shown over.
  Future<BuildContext> screen(WidgetTester tester) async {
    late BuildContext context;
    await tester.pumpWidget(
      MaterialApp(
        home: ShipglowsReviewStringsScope(
          strings: ShipglowsReviewStrings.en,
          child: Builder(
            builder: (inner) {
              context = inner;
              return const Scaffold();
            },
          ),
        ),
      ),
    );
    return context;
  }

  /// Five launches of a settled install.
  Future<ShipglowsReviews> settled(FakeStore store, {
    ShipglowsReviewsConfig settings = config,
  }) async {
    final storage = MemorySettingsStorage();
    for (var i = 0; i < 4; i++) {
      (await open(storage: storage, store: store, settings: settings))
          .dispose();
    }
    final reviews = await open(storage: storage, store: store, settings: settings);
    for (var i = 0; i < 3; i++) {
      await reviews.recordPositiveMoment();
    }
    return reviews;
  }

  group('ReviewPolicy', () {
    const policy = ReviewPolicy();
    final ready = ReviewState(
      firstSeenAt: DateTime.utc(2026),
      launches: 10,
      positiveMoments: 3,
    );

    ReviewEligibility evaluate(ReviewState state, {String? version = '2.0'}) =>
        policy.evaluate(state, now: DateTime.utc(2026, 6), version: version);

    test('asks a settled, happy user', () {
      expect(evaluate(ready), isA<ReviewEligible>());
    });

    test('waits for time, launches and successes', () {
      expect(
        evaluate(ready.copyWith(firstSeenAt: DateTime.utc(2026, 5, 30))),
        const ReviewNotYet(ReviewWait.tooNew),
      );
      expect(
        evaluate(ready.copyWith(launches: 4)),
        const ReviewNotYet(ReviewWait.fewLaunches),
      );
      expect(
        evaluate(ready.copyWith(positiveMoments: 2)),
        const ReviewNotYet(ReviewWait.fewPositiveMoments),
      );
    });

    test('stays quiet after a problem or the app form', () {
      expect(
        evaluate(ready.copyWith(lastProblemAt: DateTime.utc(2026, 5, 30))),
        const ReviewNotYet(ReviewWait.recentProblem),
      );
      expect(
        evaluate(ready.copyWith(lastReviewAt: DateTime.utc(2026, 5, 20))),
        const ReviewNotYet(ReviewWait.recentOwnReview),
      );
    });

    test('limits how often it asks', () {
      final asked = ready.withPrompt(
        DateTime.utc(2026, 4),
        version: '1.0',
      ).copyWith(positiveMoments: 3);
      expect(evaluate(asked), const ReviewNotYet(ReviewWait.recentPrompt));

      final sameVersion = ready.withPrompt(
        DateTime.utc(2025, 12),
        version: '2.0',
      ).copyWith(positiveMoments: 3);
      expect(
        evaluate(sameVersion),
        const ReviewNotYet(ReviewWait.sameVersion),
      );
      expect(evaluate(sameVersion, version: '2.1'), isA<ReviewEligible>());

      final thrice = ReviewState(
        firstSeenAt: DateTime.utc(2025),
        launches: 10,
        positiveMoments: 3,
        prompts: [
          DateTime.utc(2025, 7),
          DateTime.utc(2025, 10),
          DateTime.utc(2026, 1),
        ],
      );
      expect(
        const ReviewPolicy(minTimeBetweenPrompts: Duration.zero).evaluate(
          thrice,
          now: DateTime.utc(2026, 6),
          version: '3.0',
        ),
        const ReviewNotYet(ReviewWait.yearlyLimit),
      );
    });

    test('never asks again once rated on the store', () {
      expect(
        evaluate(ready.copyWith(ratedOnStoreAt: DateTime.utc(2025))),
        const ReviewNotYet(ReviewWait.alreadyRated),
      );
    });
  });

  group('CustomerReview', () {
    test('a draft needs a rating or a message and a well-formed address', () {
      expect(const ReviewDraft().isValid, isFalse);
      expect(const ReviewDraft(rating: 4).isValid, isTrue);
      expect(const ReviewDraft(comment: '  ').isValid, isFalse);
      expect(const ReviewDraft(comment: 'Super').isValid, isTrue);
      expect(const ReviewDraft(rating: 4, email: 'nope').isValid, isFalse);
      expect(const ReviewDraft(rating: 4, email: 'a@b.fr').isValid, isTrue);
      expect(const ReviewDraft(rating: 6).isValid, isFalse);
    });

    test('is trimmed, and keeps a name only with consent', () {
      const context = ReviewContext(appId: 'testglows', platform: 'android');
      final private = CustomerReview.fromDraft(
        const ReviewDraft(
          rating: 5,
          comment: '  Merci  ',
          email: ' a@b.fr ',
          publicName: 'Alex',
        ),
        context: context,
        createdAt: DateTime.utc(2026),
      );
      expect(private.comment, 'Merci');
      expect(private.email, 'a@b.fr');
      expect(private.publicName, isNull);
      expect(private.id, hasLength(32));

      final public = CustomerReview.fromDraft(
        const ReviewDraft(rating: 5, publishConsent: true, publicName: 'Alex'),
        context: context,
        createdAt: DateTime.utc(2026),
      );
      expect(public.publicName, 'Alex');
    });

    test('goes through JSON unchanged', () {
      final review = CustomerReview.fromDraft(
        const ReviewDraft(
          rating: 3,
          topic: ReviewTopic.idea,
          comment: 'Un mode sombre',
          publishConsent: true,
          publicName: 'Alex',
        ),
        context: const ReviewContext(
          appId: 'testglows',
          platform: 'windows',
          appVersion: '1.2.0',
          buildNumber: '12',
          locale: 'fr-FR',
          installSource: InstallSource.direct,
        ),
        createdAt: DateTime.utc(2026, 3, 4, 5, 6, 7),
        accountId: 'user_1',
      );
      expect(CustomerReview.tryFromJson(review.toJson()), review);
      expect(CustomerReview.tryFromJson({'rating': 3}), isNull);
    });

    test('a damaged state reads as a fresh one', () {
      final state = ReviewState.fromJson({
        'launches': 'many',
        'prompts': ['x', 1000],
        'outbox': [
          {'broken': true},
          42,
        ],
      });
      expect(state.launches, 0);
      expect(state.prompts, [DateTime.fromMillisecondsSinceEpoch(1000, isUtc: true)]);
      expect(state.outbox, isEmpty);
    });

    test('install sources', () {
      expect(
        InAppReviewBackend.installSourceOf('android', 'com.android.vending'),
        InstallSource.googlePlay,
      );
      expect(
        InAppReviewBackend.installSourceOf('android', null),
        InstallSource.direct,
      );
      expect(
        InAppReviewBackend.installSourceOf('ios', 'com.apple.testflight'),
        InstallSource.testFlight,
      );
      expect(
        InAppReviewBackend.installSourceOf('web', null),
        InstallSource.web,
      );
    });
  });

  group('ShipglowsReviews', () {
    test('counts launches and keeps the install date', () async {
      final storage = MemorySettingsStorage();
      (await open(storage: storage)).dispose();
      final reviews = await open(storage: storage);
      expect(reviews.state.launches, 2);
      expect(reviews.state.firstSeenAt, DateTime.utc(2026));
      reviews.dispose();
    });

    testWidgets('asks the store once the policy allows it, then waits', (
      tester,
    ) async {
      final context = await screen(tester);
      final store = FakeStore();
      final reviews = await settled(store);
      await reviews.recordProblem();
      expect(
        await reviews.maybeAskForReview(context, appName: 'TestGlows'),
        isFalse,
      );
      now = now.add(const Duration(days: 4));
      expect(
        await reviews.maybeAskForReview(context, appName: 'TestGlows'),
        isTrue,
      );
      expect(store.requests, 1);
      expect(reviews.state.positiveMoments, 0);
      expect(
        reviews.eligibility,
        const ReviewNotYet(ReviewWait.recentPrompt),
      );
      await tester.pump();
      expect(find.byType(AlertDialog), findsNothing);
      reviews.dispose();
    });

    testWidgets('invites by itself where the store has no prompt', (
      tester,
    ) async {
      final context = await screen(tester);
      final store = FakeStore(canPrompt: false, listing: null);
      final reviews = await settled(
        store,
        settings: const ShipglowsReviewsConfig(
          appId: 'testglows',
          promptInDebug: true,
          reviewSite: ReviewSite(
            name: 'Trustpilot',
            url: 'https://example.com/review',
          ),
        ),
      );
      expect(reviews.eligibility, isA<ReviewEligible>());
      final asked = reviews.maybeAskForReview(context, appName: 'TestGlows');
      await tester.pumpAndSettle();
      expect(find.text('Your opinion on TestGlows'), findsOneWidget);
      expect(find.text('Rate on Trustpilot'), findsOneWidget);
      expect(store.requests, 0);

      await tester.tap(find.text('Rate on Trustpilot'));
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      expect(openedUrls.last, Uri.parse('https://example.com/review'));
      expect(reviews.eligibility, const ReviewNotYet(ReviewWait.alreadyRated));
      reviews.dispose();
    });

    testWidgets('« Give feedback » in the invitation opens the form', (
      tester,
    ) async {
      final context = await screen(tester);
      final reviews = await settled(FakeStore(canPrompt: false, listing: null));
      final asked = reviews.maybeAskForReview(context, appName: 'TestGlows');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Give feedback'));
      await tester.pumpAndSettle();
      expect(find.text('Your feedback on TestGlows'), findsOneWidget);
      await tester.ensureVisible(find.text('Cancel'));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      reviews.dispose();
    });

    testWidgets('« Don’t ask again » stops the invitation', (tester) async {
      final context = await screen(tester);
      final reviews = await settled(FakeStore(canPrompt: false, listing: null));
      final asked = reviews.maybeAskForReview(context, appName: 'TestGlows');
      await tester.pumpAndSettle();
      expect(find.text('Rate on Trustpilot'), findsNothing);
      await tester.tap(find.text('Don’t ask again'));
      await tester.pumpAndSettle();
      expect(await asked, isTrue);
      expect(reviews.eligibility, const ReviewNotYet(ReviewWait.optedOut));
      reviews.dispose();
    });

    test('asks nothing where the invitation is off and no prompt exists',
        () async {
      final reviews = await open(
        store: FakeStore(canPrompt: false, listing: null),
        settings: const ShipglowsReviewsConfig(
          appId: 'testglows',
          promptInDebug: true,
          inviteWithoutStorePrompt: false,
        ),
      );
      expect(reviews.eligibility, const ReviewNotYet(ReviewWait.noPrompt));
      expect(reviews.ratingPage, isNull);
      reviews.dispose();
    });

    test('the store page comes before the review site', () async {
      const site = ReviewSite(name: 'Trustpilot', url: 'https://example.com');
      const withSite = ShipglowsReviewsConfig(
        appId: 'testglows',
        reviewSite: site,
      );
      final onStore = await open(settings: withSite);
      expect(
        onStore.ratingPage,
        const StoreRatingPage(ReviewStore.googlePlay),
      );
      onStore.dispose();
      final offStore = await open(
        store: FakeStore(canPrompt: false, listing: null),
        settings: withSite,
      );
      expect(offStore.ratingPage, const SiteRatingPage(site));
      expect(
        ShipglowsReviewStrings.fr.pageName(offStore.ratingPage!),
        'Trustpilot',
      );
      offStore.dispose();
    });

    test('rating on the store stops the prompt', () async {
      final store = FakeStore();
      final reviews = await open(store: store);
      expect(await reviews.openRatingPage(), isTrue);
      expect(store.listingsOpened, 1);
      expect(reviews.eligibility, const ReviewNotYet(ReviewWait.alreadyRated));
      reviews.dispose();
    });

    test('sends a review with its context', () async {
      final sink = MemoryReviewSink();
      final reviews = await open(sink: sink);
      reviews.accountId = 'user_1';
      final result = await reviews.submit(
        const ReviewDraft(rating: 5, comment: 'Top'),
        locale: const Locale('fr', 'FR'),
      );
      expect(result, ReviewSendResult.sent);
      final review = sink.received.single;
      expect(review.context.appId, 'testglows');
      expect(review.context.appVersion, '1.2.0');
      expect(review.context.locale, 'fr-FR');
      expect(review.accountId, 'user_1');
      expect(reviews.status.value.pending, 0);
      reviews.dispose();
    });

    test('keeps a review offline and sends it at the next launch', () async {
      final storage = MemorySettingsStorage();
      final offline = MemoryReviewSink()..failWith = StateError('offline');
      final first = await open(storage: storage, sink: offline);
      final result = await first.submit(const ReviewDraft(rating: 4));
      expect(result, ReviewSendResult.queued);
      expect(first.status.value.pending, 1);
      first.dispose();

      final online = MemoryReviewSink();
      final second = await open(storage: storage, sink: online);
      await second.flush();
      expect(online.received, hasLength(1));
      expect(second.state.outbox, isEmpty);
      second.dispose();
    });

    test('a refused review is dropped and reported', () async {
      final sink = MemoryReviewSink()
        ..failWith = const ReviewRejectedException('bad app');
      final reviews = await open(sink: sink);
      await expectLater(
        reviews.submit(const ReviewDraft(rating: 1)),
        throwsA(isA<ReviewRejectedException>()),
      );
      expect(reviews.state.outbox, isEmpty);
      reviews.dispose();
    });

    test('a review neither sent nor saved is handed back', () async {
      final sink = MemoryReviewSink()..failWith = StateError('offline');
      final reviews = await open(storage: FailingStorage(), sink: sink);
      await expectLater(
        reviews.submit(const ReviewDraft(rating: 2)),
        throwsA(isA<ReviewNotSavedException>()),
      );
      expect(reviews.state.outbox, isEmpty);
      reviews.dispose();
    });

    test('follows success and error messages', () async {
      final reviews = await ShipglowsReviews.open(
        config: config,
        storage: MemorySettingsStorage(),
        sink: MemoryReviewSink(),
        store: FakeStore(),
        observeLifecycle: false,
        clock: clock,
      );
      FeedbackLog.record(
        FeedbackRecord(
          message: 'Saved',
          kind: FeedbackKind.success,
          shownAt: now,
        ),
      );
      FeedbackLog.record(
        FeedbackRecord(
          message: 'Failed',
          kind: FeedbackKind.error,
          shownAt: now,
        ),
      );
      expect(reviews.state.positiveMoments, 1);
      expect(reviews.state.lastProblemAt, now);
      reviews.dispose();
      expect(FeedbackLog.hasListeners, isFalse);
    });
  });

  group('form', () {
    Future<ShipglowsReviews> pump(WidgetTester tester, MemoryReviewSink sink) async {
      final reviews = await open(sink: sink);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ShipglowsReviewForm(
              reviews: reviews,
              appName: 'TestGlows',
              strings: ShipglowsReviewStrings.en,
            ),
          ),
        ),
      );
      return reviews;
    }

    testWidgets('asks for a rating or a message before sending', (
      tester,
    ) async {
      final sink = MemoryReviewSink();
      final reviews = await pump(tester, sink);
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pump();
      expect(find.text('Pick a rating or write a message.'), findsOneWidget);
      expect(sink.received, isEmpty);
      reviews.dispose();
    });

    testWidgets('Ctrl+Enter sends from the message field', (tester) async {
      final sink = MemoryReviewSink();
      final reviews = await pump(tester, sink);
      await tester.enterText(find.byType(TextField).first, 'Great app');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(sink.received.single.comment, 'Great app');
      reviews.dispose();
    });

    testWidgets('sends the stars and offers the store to everyone', (
      tester,
    ) async {
      final sink = MemoryReviewSink();
      final reviews = await pump(tester, sink);
      await tester.tap(find.byTooltip('2 out of 5, Poor'));
      await tester.pump();
      expect(find.text('Poor'), findsOneWidget);
      await tester.ensureVisible(find.text('Send'));
      await tester.tap(find.text('Send'));
      await tester.pumpAndSettle();
      expect(sink.received.single.rating, 2);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text('Rate on Google Play'), findsOneWidget);
      reviews.dispose();
    });
  });
}
