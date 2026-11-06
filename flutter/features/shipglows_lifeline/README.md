# shipglows_lifeline

A full page that offers help when a person seems to need it, more or less firmly:
from a breathing exercise to calling a helpline. The decision logic and verified
helplines are in `shipglows_lifeline_core`. The app writes every sentence and
places the calls, so this package has no native dependency and works offline.

```dart
await showLifelinePage(
  context: context,
  content: LifelineContent(
    title: 'Ces derniers jours ont l’air lourds',
    message: 'Voici ce qui peut aider, si tu veux.',
    reason: 'Parce que tu as noté « Désespoir ».',
    dismissLabel: 'Pas maintenant',
    callFailed: (number) => 'L’appel n’a pas pu partir. Compose le $number.',
    suggestions: [
      LifelineSuggestion.action(
        title: 'Respirer un moment',
        emphasis: LifelineEmphasis.strong,
        onSelected: openBreathing,
      ),
      const LifelineSuggestion.contact(FrenchHelplines.suicidePrevention),
    ],
  ),
  onContact: (contact) => launcher.call(contact.number),
);
```

- `LifelineSuggestion.contact(contact, emphasis:)`: one tap to call or text. The
  page stays open afterwards. If `onContact` returns `false`, `callFailed` gives
  the number to dial by hand.
- `LifelineSuggestion.action(title:, detail:, emphasis:, onSelected:)`: closes the
  page, then runs `onSelected`.
- `LifelineEmphasis.strong`, `normal` or `quiet`: how firmly it is offered, by a
  filled button, an outlined one or a text one. The danger color is reserved for
  a strong contact marked `emergency`.
- `LifelineContent`: one per level, written by the app. `emergencyColor` and
  `onEmergencyColor` let it use its own emergency color.

## Rules kept by the page

- **Always easy to leave.** The dismiss button is always on screen and the system
  back gesture works. A person is never trapped by a page meant to help.
- **No animation and no timer**, so the page is calm and works under reduced motion.
- **No diagnosis.** Saying why the page appears (`reason`) is up to the app, as an
  observation of what the person noted.

Have the wording reviewed by a specialist, and keep help visible elsewhere in the
app: this page is an addition, never the only way to reach help.
