# shipglows_onboarding

First-run introduction: one fixed two-column card (texts and actions on the
left, a preview on the right) under a segmented progress bar, shown once per
account and replayable. Extracted from the ReplayGlows introduction. A
teaser of what the app does, not a walkthrough of its controls (that is
`shipglows_guide`). No dependency besides Flutter and `shipglows_theme`:
texts, previews, storage and the signed-in account are the app's.

- `OnboardingPage`: `title` (null when the `body` brings its own heading,
  like an embedded sign-in form), optional `eyebrow`, `leading` (icon badge, before the title on its line),
  `description` (`descriptionLines` keeps a series aligned), `note` (italic
  word from the maker), `body` (status, links), `preview` builder.
  `centered` for feature pages, `scrollable` for a page whose body grows,
  `showBack` / `showSkip`, `showPrimary` (off when the body owns the way
  forward: a sign-in form, a start-trial panel), `primaryLabel` /
  `primaryArrow`.
- `OnboardingLanguagePage`: first page, one button per
  `OnboardingLanguageOption` (label and greeting in its own language), a
  specimen of the greetings as preview; picking one moves on.
- `OnboardingThemePage`: its twin for the theme, one button per
  `OnboardingThemeOption` (`ThemeMode` and label), small light, dark and
  system windows as preview; picking one moves on.
- `OnboardingStatements`: labelled statements (mission, vision, goal) for a
  page `body`, with `scrollable: true`.
- `OnboardingFlow(pages:, strings:, onFinish:)`: Skip jumps to the last page,
  done segments of the progress bar go back, focus follows the title. Pages
  can be rebuilt (new language, a status that loads): the current one is kept
  by index. Below `narrowWidth` the card is one scrolling column without
  preview. With `index:` the app owns the page (the introduction wraps
  sign-in and access, CommandGlows): every move is asked through
  `onIndexChanged` and the app answers with a new `index`;
  `progressNavigation: false` keeps done segments still. Stable keys for
  tests: `onboarding-primary`, `onboarding-finish` (last page),
  `onboarding-back`, `onboarding-skip`, `onboarding-language-<code>`.
- `OnboardingGate`: due once per `setScope(userId)` and `version`
  (`onboarding_completed:v1:<user>`), `complete()`, `replay()` for
  Preferences. Signed out (null scope) never shows it. Keys go through an
  `OnboardingCompletionStore` (`Memory…`, `Callback…` for
  `SharedPreferences`).
- `OnboardingOverlay(pending:, introduction:, child:)` from
  `MaterialApp.builder`.
- Texts: `OnboardingStrings.en`, `.fr`, or the app's own.
- Look: `OnboardingThemeData` theme extension (title, description, eyebrow,
  skip and specimen styles merged onto the defaults, `progressGradient`,
  card color, border and shadows, radii, card size, motion); fallbacks from `ShipglowsTheme`. Motion is off
  when the platform asks to reduce it.

```dart
OnboardingFlow(
  strings: OnboardingStrings.forLocale(locale),
  onFinish: gate.complete,
  pages: [
    OnboardingLanguagePage(
      id: 'language',
      title: 'Choose your language',
      options: const [
        OnboardingLanguageOption(
            locale: Locale('fr'), label: 'Français', greeting: 'Bonjour'),
        OnboardingLanguageOption(
            locale: Locale('en'), label: 'English', greeting: 'Hello'),
      ],
      onSelected: setLocale,
    ),
    OnboardingPage(
      id: 'welcome',
      title: 'Welcome',
      description: '…',
      preview: (_) => const AppMark(),
      showBack: false,
      primaryLabel: 'Get started',
    ),
    // one page per feature, then the access summary
  ],
)
```
