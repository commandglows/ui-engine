# shipglows_guide

In-app guidance: guided tours across screens, coach marks on a precise
widget (spotlight, « this control is for… », « try it »), one-step tips,
shown on a screen's first visit and replayable. Extracted from the
ContentGlows guided tour. No dependency besides Flutter: routing, storage and
translations are the app's, passed as callbacks. Not the first-launch
onboarding (`shipglows_onboarding`).

### Tours and steps

```dart
const videosTour = GuideTour(
  id: 'videos.intro',
  steps: [
    GuideStep(
      id: 'filter',
      targetId: 'videos.filter',          // a GuideTarget on screen
      route: '/videos',                   // opened when the step starts
      title: 'guide.videos.filterTitle',  // text or translation key
      body: 'guide.videos.filterBody',
      hint: 'guide.videos.filterHint',    // optional call to action
    ),
    GuideStep(
      id: 'play',
      targetId: 'videos.play',
      advanceOnTargetTap: true,           // « try it »: tapping moves on
      title: '…',
      body: '…',
    ),
  ],
);
```

- `GuideStep.targetId`: the step points at that `GuideTarget`; a ring and a
  pulsing halo mark it (still under reduce-motion). The card sits below it,
  else above, else beside it, never over it; it is measured, kept inside the
  safe area and scrolls when taller than the screen, so it is never cut. The
  target is scrolled into view and tracked while it moves. A target not on screen (narrow layout, offstage
  tab) leaves the card floating at the bottom center.
- `spotlight` (default on): dims the rest of the screen and absorbs taps
  there; the target stays usable. Off: a ring around the target only, the
  screen keeps working.
- `advanceOnTargetTap`: the card says « Try it » and the target's own tap
  (its action runs first) moves to the next step.
- `route` / `routeLabel`: the controller opens the route when the step
  starts; if the user leaves it, the card offers « Open {routeLabel} ».
- `link`: `GuideLink(label:, url:)`, a web page the step sends the user to
  (create an API key…), shown as an underlined link under the body; the
  label goes through `resolveText`. Needs `GuideScope.openLink`.
- A tour of one step is a tip: « Tip » header, no progress, « Got it » and
  the close button end it for good.
- The card can be dragged anywhere (kept on screen), reset at each step.

### Controller

```dart
final guide = GuideController(
  tours: [videosTour],
  store: CallbackGuideStore(
    onRead: (id) async => GuideProgress.decode(
      (await SharedPreferences.getInstance()).getString('guide:$id')),
    onWrite: (id, p) async =>
      (await SharedPreferences.getInstance()).setString('guide:$id', p.encode()),
  ),
  navigate: (route) => router.go(route),
  location: () => router.routerDelegate.currentConfiguration.uri.path,
);
```

One per app (a Riverpod `Provider` with `ref.onDispose(guide.dispose)`).
It is a `ChangeNotifier`: a settings row rebuilds with `ListenableBuilder`.

- `start(id, {step})`, `resume(id)` (where the user left it, from the start
  once completed), `pause()` (resumable), `skip()` (completed), `next()`,
  `previous()`, `openStepRoute()`.
- `startIfFirstVisit(id)`: starts a tour never shown, unless another runs.
- `reset(id)` / `resetAll()`: « Show tips again ».
- `progressOf(id)` (after `load(id)`): `stepIndex`, `started`, `completed`.
- A tour is never resumed on its own at startup.
- `store`: `MemoryGuideStore` by default; `CallbackGuideStore` for the
  app's storage (`GuideProgress.encode` / `decode` for one string per tour).

### Widgets

```dart
GuideScope(                       // around the shell, under the navigator
  controller: guide,
  strings: GuideStrings.forLocale(Localizations.localeOf(context)),
  resolveText: (context, key) => t(key, locale: appLocale(context)),
  child: shell,
)

GuideTrigger(tourId: 'videos.intro', child: VideosScreen())  // first visit
GuideTarget(id: 'videos.filter', child: IconButton(...))      // pointable
```

- `GuideScope.navigate` / `location`: context-based routing
  (`(context, route) => context.go(route)`) for an app whose controller has
  no `navigate` of its own; used while the scope is mounted. A tour started
  outside the shell (onboarding) opens its first route itself:
  `context.go(guide.activeStep?.route ?? '/home')`.
- `GuideScope.openLink`: opens a step's `link` (`(context, url) =>
  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)`); the
  package has no `url_launcher`, so links stay hidden without it.
- `GuideScope.of(context)` / `maybeOf`: the controller, for a « Replay the
  tour » button inside the shell.
- `GuideTrigger.enabled: false` while the screen is not ready (loading); it
  fires when it turns on, after `delay` (600 ms), and only while its screen
  is shown (an offstage tab waits).
- `GuideTarget` ids are unique among mounted screens.

### Texts, look, accessibility

- Card texts: `GuideStrings.en`, `.fr`, `forLocale(locale)` or the app's
  own (`{current}`, `{total}`, `{screen}` are filled in). Step texts go
  through `resolveText`.
- Look: `GuideThemeData` theme extension (accent, surface, scrim, max width,
  radii, spotlight padding, bottom offset of a floating card), every value
  falls back on the `ColorScheme`.
- Accessibility: the card is a live region (read when a step changes), the
  primary button takes focus, Esc pauses (closes a tip), every button is
  44 px at least, icons are excluded from semantics, reduce-motion turns the
  card's entrance and the scroll to the target off.
