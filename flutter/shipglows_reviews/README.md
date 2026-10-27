# shipglows_reviews

Customer reviews for ShipGlows Flutter apps, the same on every app:

1. **The store's rating prompt, at the right moment.** Google Play In-App
   Review on Android, `SKStoreReviewController` on iOS and macOS. The prompt
   is asked for only when someone has used the app for a while, just
   succeeded at something, saw no error lately, and was not asked recently.
2. **The app's own review form.** Stars, a topic, a message, an optional
   address so the team can answer, and consent to publish it as a
   testimonial. Reviews go to the app's backend and wait on the device while
   offline.
3. **The settings rows.** « Donner mon avis » and « Noter {app} » (the store
   page, where the app has one).

## Store rules

The package follows the store rules. Google Play and Apple forbid
*review gating*: asking how someone feels, then sending only happy people to
the store. So:

- the automatic prompt never asks a question first;
- the form and the store page are offered to everyone, whatever the rating;
- the app never learns whether the person rated (the stores do not say),
  and they decide whether a prompt shows at all (Apple allows three a year).

## Setup

```dart
final reviews = await ShipglowsReviews.open(
  config: const ShipglowsReviewsConfig(
    appId: 'commandglows',
    appStoreId: '',            // App Store id, iOS/macOS
    microsoftStoreId: '',      // Microsoft Store product id, Windows
    playStoreListed: false,    // on Google Play: sideloaded copies can rate there
  ),
  storage: FileSettingsStorage(supportDir, prefix: 'shipglows.'),
  sink: CallbackReviewSink(
    (review) => convex.mutation('reviews:submit', review.toJson()),
  ),
);
reviews.accountId = clerk.session.value?.userId; // optional, on account change
```

- `storage` is any `SettingsStorage` from `shipglows_settings`: the app's
  existing one is fine (the state lives in its own `reviews` bucket). Use a
  `CallbackSettingsStorage` on the web.
- `followFeedback` (on by default): every success message of
  `shipglows_feedback` counts as a positive moment, every error as a
  problem. Turn it off and call `recordPositiveMoment()` /
  `recordProblem()` by hand for finer signals.
- At a natural break (back on the home screen, after a task is finished,
  never in the middle of one):

  ```dart
  unawaited(reviews.maybeAskForStoreReview());
  ```

- Anywhere (menu « Donner mon avis », help, an error screen with
  `topic: ReviewTopic.problem`):

  ```dart
  showShipglowsReviewForm(context, reviews: reviews, appName: 'CommandGlows');
  ```

- In the settings: `ShipglowsReviewSettings(reviews: reviews, appName: 'CommandGlows')`.

## When the prompt is asked for

`ReviewPolicy`, every rule adjustable:

| Rule | Default |
| --- | --- |
| Installed for at least | 7 days |
| Launches | 5 |
| Successes since the last prompt | 3 |
| Quiet after an error | 3 days |
| Quiet after a review sent through the form | 30 days |
| Between two prompts | 120 days |
| Prompts per year | 3 |
| Once per app version | yes |
| After « Noter sur le Store » | never again |

Never in debug or profile builds (`promptInDebug: true` to try it, with
Google Play internal app sharing or TestFlight; a debug build from
`flutter run` has no Play install, so Play shows nothing). Never where the
install cannot show it: sideloaded APKs, WinSparkle installs, web.
`reviews.eligibility` says why it waits (`ReviewNotYet(ReviewWait.…)`).

## What the backend receives

`CustomerReview.toJson()`, plain JSON; absent values are left out:

| Field | Type | |
| --- | --- | --- |
| `id` | string | 32 hex chars, made on the device: keep one per id (retries) |
| `createdAt` | number | ms since epoch, UTC |
| `rating` | number? | 1 to 5; absent for a message without stars |
| `topic` | string | `praise`, `idea`, `problem`, `other` |
| `comment` | string | trimmed, ≤ 2000 chars, may be empty |
| `email` | string? | only to answer |
| `publishConsent` | bool | may be published as a testimonial |
| `publicName` | string? | only with consent; absent = anonymous |
| `accountId` | string? | when the app sets `reviews.accountId` |
| `appId`, `platform`, `appVersion`, `buildNumber`, `locale`, `installSource` | string | the context |

Nothing else: no device id, no IP. A failed `send` is retried (30 s doubling
to 5 min, on resume, at the next launch); throw `ReviewRejectedException` to
drop a review for good.

Convex example:

```ts
// convex/schema.ts
reviews: defineTable({
  id: v.string(),
  createdAt: v.number(),
  rating: v.optional(v.number()),
  topic: v.string(),
  comment: v.string(),
  email: v.optional(v.string()),
  publishConsent: v.boolean(),
  publicName: v.optional(v.string()),
  accountId: v.optional(v.string()),
  appId: v.string(),
  platform: v.string(),
  appVersion: v.string(),
  buildNumber: v.string(),
  locale: v.string(),
  installSource: v.string(),
})
  .index("by_review_id", ["id"])
  .index("by_app", ["appId", "createdAt"]),

// convex/reviews.ts
export const submit = mutation({
  args: { /* the fields above */ },
  handler: async (ctx, review) => {
    const known = await ctx.db
      .query("reviews")
      .withIndex("by_review_id", (q) => q.eq("id", review.id))
      .unique();
    if (known === null) await ctx.db.insert("reviews", review);
  },
});
```

The mutation may be public (signed out users can write a review): limit the
comment length and the rate on the server too.

## Store ids

- Android: nothing to declare; `in_app_review` brings the Play library.
- iOS / macOS: `appStoreId` for the store page; the prompt needs nothing.
- Windows: `microsoftStoreId` (Partner Center → Product identity → Store ID).
  Without it, Windows offers the form only.
