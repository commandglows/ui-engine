# Changelog

## 0.1.0

- `JourneyMap` (column), `SliverJourneyMap` and `JourneyMapView` (virtualised: only rows near the viewport are built).
- `JourneyMapController`: scroll to any node or to the current one, jump when motion is reduced.
- `JourneyMapTheme` (`ThemeExtension`): light and dark from the `ColorScheme`, brand overrides, per-state contrast.
- `JourneyMapLabels`: every string, English and French presets chosen from the ambient locale.
- Path segments coloured by progress, soft pulse on the current node (off when the platform reduces motion).
- Text-scale aware row heights, right-to-left mirroring, maximum content width on large screens.
- Custom `nodeBuilder`; loading, error and empty states.
