# shipglows_journey_map

Winding journey map shared by DreamGlows (goals) and Claiire (life events).

- `JourneyMap(chapters:, onSelect:, selectedId:, style:)` — non-scrolling; put it in any scrollable.
- `JourneyChapter` → titled group drawn on one path; `JourneyNode` → one stop (state, marker/icon, caption, optional progress ring).
- `JourneyLayout.winding` — pure geometry (centres + path), shared by painter and hit targets.
- State is never colour-only: done nodes carry a check badge, the current node a thick ring, and every node a spoken label (`JourneyStateLabels`, French by default).
- Colours fall back to the ambient `ColorScheme`; override via `JourneyMapStyle`.
- No gamification built in (no stars/XP): apps decide what a node means.
