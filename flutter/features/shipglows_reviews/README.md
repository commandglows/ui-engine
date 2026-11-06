# shipglows_reviews

Customer reviews for ShipGlows Flutter apps, the same on Android, iOS,
macOS, Windows and the web:

1. **Asking at the right moment.** The store's own rating prompt where the
   install has one (Google Play In-App Review, `SKStoreReviewController`).
   Everywhere else (Windows, the web, sideloaded APKs) the app shows its own
   invitation at the same moments: « Donner mon avis », « Noter sur {page} »,
   « Plus tard », « Ne plus me demander ».
2. **The app's own review form.** Stars, a topic, a message, an optional
   address so the team can answer, consent to publish it as a testimonial.
   Reviews go to the app's backend and wait on the device while offline.
3. **The public rating page.** The store page (Google Play, App Store,
   Microsoft Store), or else a review site (`ReviewSite`: Trustpilot, Google
   reviews…) for apps without a store page: the WinSparkle Windows builds and
   the web apps.
4. **The settings rows.** « Donner mon avis » and « Noter {app} ».

## Platforms

| | Asking | Public page | Device state |
| --- | --- | --- | --- |
| Android, Google Play install | Play prompt | Play page | app support folder |
| Android, APK (`shipglows_updater`) | invitation | Play page if `playStoreListed`, else `reviewSite` | app support folder |
| iOS / macOS, App Store | App Store prompt | App Store page (`appStoreId`) | app support folder |
| Windows | invitation | Microsoft Store page (`microsoftStoreId`), else `reviewSite` | `%APPDATA%\<company>\<app>\shipglows.reviews.json` |
| Web | invitation | `reviewSite` | `localStorage` key `shipglows.reviews` |

The form works everywhere. Debug and profile builds never ask by themselves
(`promptInDebug: true` to try it).

## Store and review-site rules

Google Play, Apple, Trustpilot and Google reviews forbid *review gating*:
asking how someone feels, then sending only happy people to rate. So:

- nothing is asked before the prompt or the invitation;
- the form and the public page are offered to everyone, whatever the rating;
- the app never learns whether the person rated on a store, and the stores
  decide whether their prompt shows (Apple: three times a year at most).

## Setup

```dart
final reviews = await ShipglowsReviews.open(
  config: const ShipglowsReviewsConfig(
    appId: 'commandglows',
    appStoreId: '',            // App Store id, iOS/macOS
    microsoftStoreId: '',      // Microsoft Store product id, Windows
    playStoreListed: false,    // on Google Play: APK copies can rate there
    reviewSite: ReviewSite(    // where there is no store page
      name: 'Trustpilot',
      url: 'https://www.trustpilot.com/evaluate/commandglows.com',
    ),
  ),
  sink: CallbackReviewSink(
    (review) => convex.mutation('reviews:submit', review.toJson()),
  ),
);
reviews.accountId = clerk.session.value?.userId; // optional, on account change
```

- `storage` is optional: the app support folder on native platforms,
  `localStorage` on the web. Any `SettingsStorage` from `shipglows_settings`
  works too (the state lives in its `reviews` bucket).
- `followFeedback` (on by default): every success message of
  `shipglows_feedback` counts as a positive moment, every error as a
  problem. Turn it off and call `recordPositiveMoment()` /
  `recordProblem()` by hand for finer signals.
- At a natural break (back on the home screen, after a task is finished,
  never in the middle of one):

  ```dart
  unawaited(reviews.maybeAskForReview(context, appName: 'CommandGlows'));
  ```

- Anywhere (menu « Donner mon avis », help, an error screen with
  `topic: ReviewTopic.problem`):

  ```dart
  showShipglowsReviewForm(context, reviews: reviews, appName: 'CommandGlows');
  ```

- In the settings: `ShipglowsReviewSettings(reviews: reviews, appName: 'CommandGlows')`.
- `showShipglowsReviewInvitation(context, …)` shows the invitation on demand;
  `inviteWithoutStorePrompt: false` turns the automatic one off.
- Ctrl+Enter (Cmd+Enter) sends the form, from any field.

## When to ask

`ReviewPolicy`, the same for the store prompt and the invitation, every rule
adjustable:

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
| After « Noter sur … » | never again |
| After « Ne plus me demander » | never again |

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
| `appId`, `platform`, `appVersion`, `buildNumber`, `locale`, `installSource` | string | the context (`platform`: `android`, `ios`, `macos`, `windows`, `linux`, `web`) |

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

The mutation may be public (signed-out people can write a review): limit the
comment length and the rate on the server too.

## Store ids

- Android: nothing to declare; `in_app_review` brings the Play library.
- iOS / macOS: `appStoreId` for the store page; the prompt needs nothing.
- Windows: `microsoftStoreId` (Partner Center → Product identity → Store ID)
  for apps on the Microsoft Store; otherwise `reviewSite`.

## Example

`example/` is a playground for Windows and the web (invitation, form,
settings rows, offline sending), with an in-memory sink and a policy that
asks after one success:

```powershell
s start -ProjectPath flutter\shipglows_reviews\example -FlutterDevice windows
s start -ProjectPath flutter\shipglows_reviews\example -FlutterDevice web-server
```

Flutter apps only: the Vue/Tauri apps (CommunityGlows, ToolGlows) need their
own client for the same backend contract.

## More

Customer reviews, the same on Android, iOS, macOS, Windows and the web:
asking at the right moment, the app's own review form sent to its backend,
the public rating page and the settings rows. Depends on `in_app_review`,
`package_info_plus`, `path_provider`, `url_launcher`, `web`,
`shipglows_settings` (device state), `shipglows_feedback`, `shipglows_theme`
and `shipglows_icons`.

- `ShipglowsReviews.open(config: ShipglowsReviewsConfig(appId:, appStoreId:,
  microsoftStoreId:, playStoreListed:, reviewSite:, policy:), sink:)` once
  at startup; never throws. Counts launches, reads the install (Google Play,
  App Store, TestFlight, direct installer or APK, web), sends the reviews
  left unsent. The state lives in the app support folder
  (`%APPDATA%\<company>\<app>\shipglows.reviews.json` on Windows), in
  `localStorage` on the web, or in any `SettingsStorage` given.
- `maybeAskForReview(context, appName:)` at a natural break: the store's
  rating prompt on Google Play and App Store installs; elsewhere (Windows,
  the web, APKs) the app's invitation « Donner mon avis » / « Noter sur
  {page} » / « Plus tard » / « Ne plus me demander »
  (`showShipglowsReviewInvitation` on demand, `inviteWithoutStorePrompt`).
  The `ReviewPolicy` asks only after 7 days, 5 launches and 3 successes
  since the last prompt, never within 3 days of an error or 30 of a form
  review, 120 days apart, 3 a year, once per version, never again after
  rating or « Ne plus me demander ». Never in debug builds
  (`promptInDebug`). `eligibility` says why it waits. With `followFeedback`
  (default) every `shipglows_feedback` success counts as a positive moment
  and every error as a problem.
- Form: `showShipglowsReviewForm(context, reviews:, appName:, topic:)` (a
  bottom sheet on compact windows, a dialog otherwise): stars, topic
  (praise, idea, problem, other), message, optional address, consent to
  publish as a testimonial with an optional display name, a note on what is
  sent. Ctrl+Enter sends from any field. The thank-you offers the public
  page to everyone, whatever the rating: stores and review sites forbid
  sending only happy people to rate.
- Public page (`ratingPage`, `openRatingPage()`): the store page (Google
  Play, App Store, Microsoft Store), or else the `ReviewSite` (Trustpilot,
  Google reviews…) for the WinSparkle Windows builds and the web.
- `ShipglowsReviewSettings(reviews:, appName:)`: « Donner mon avis » (with
  the reviews waiting offline) and « Noter {app} ». `ShipglowsStarRating`
  alone. `ShipglowsReviewStrings.fr` / `.en`, `ShipglowsReviewStringsScope`.
- Backend: a `ReviewSink` (`CallbackReviewSink` over a Convex mutation, a
  Firestore collection, a REST call). `CustomerReview.toJson()` is plain
  JSON with a device-made `id` for deduplication; no device id, no IP.
  Unsent reviews stay on the device, retried 30 s doubling to 5 min, on
  resume and at the next launch; `ReviewRejectedException` drops one.
  Platform table, field table and Convex example in
  this README; a Windows and web playground in
  `example/`.

```dart
final reviews = await ShipglowsReviews.open(
  config: const ShipglowsReviewsConfig(
    appId: 'commandglows',
    reviewSite: ReviewSite(name: 'Trustpilot', url: 'https://…'),
  ),
  sink: CallbackReviewSink(
    (review) => convex.mutation('reviews:submit', review.toJson()),
  ),
);
unawaited(reviews.maybeAskForReview(context, appName: 'CommandGlows'));
showShipglowsReviewForm(context, reviews: reviews, appName: 'CommandGlows');
```
