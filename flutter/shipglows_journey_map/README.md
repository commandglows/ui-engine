# shipglows_journey_map

Winding journey map shared by DreamGlows (goals) and Claiire (life events): ordered chapters of nodes drawn along a smooth path.

```dart
JourneyMapView(
  chapters: chapters,            // keep the same list instance between builds
  controller: controller,        // scroll to a node / to the current one
  selectedId: selected,
  initialScrollToCurrent: true,
  onSelect: (id) { ... },
)
```

## Widgets

| Widget | Use |
|---|---|
| `JourneyMap` | Non-scrolling column; a few chapters inside an existing list |
| `SliverJourneyMap` | Inside your own `CustomScrollView`; builds only visible rows |
| `JourneyMapView` | Ready scroll view around the sliver, optional scroll-to-current |

Data: `JourneyChapter` (title, icon, trailing summary) holds `JourneyNode`s (id, label, caption, marker or icon, state, optional progress ring, optional `semanticLabel`).

## Scale

Rows are fixed-height and flattened once (`JourneyRows`): a hundred thousand nodes cost a flat list of references and no widgets until scrolled into view. Rows paint their own path segment, so they build independently. The flatten step reruns only when the `chapters` list instance changes.

## Accessibility

- State is never colour-only: check badge on done, thick ring (and a soft pulse) on current, outline on upcoming, plus a spoken label (`label, caption, state, n of total`).
- Default node colours use the scheme's own `on*` colours (4.5:1 checked in tests, light and dark); a custom fill without `onNodeColor` gets the more readable of white/black.
- Row heights follow the text scale (labels scale freely; the mark inside the disc stops at 1.3x). A label longer than two lines is cut visually, never in semantics.
- Chapter headers are semantic headers; nodes are buttons with tap action and keyboard activation.
- The pulse stops when the platform reduces motion; `scrollTo*` jumps instead of animating.
- The path mirrors in right-to-left.

## Theming and i18n

`JourneyMapTheme` is a `ThemeExtension`: register it in your `ThemeData`, or pass `theme:` to override per map. Nulls fall back to the `ColorScheme` (so dark mode just works). `JourneyMapLabels` holds every string with `{placeholders}`; English and French presets are picked from the ambient locale, `labels:` overrides.

## Customising

`nodeBuilder` replaces the cell of a node (you own semantics and a 44 px target). `loading`, `error`/`onRetry` and `emptyBuilder` replace the map with a notice. No gamification is built in (no stars, XP, streaks): apps decide what a node means.
