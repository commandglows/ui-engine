/// One theme for every ShipGlows Flutter app and package: semantic roles
/// ([ShipglowsTheme]) that each app fills from its own brand tokens, the
/// bundled fonts ([ShipglowsFonts]) and scrollbars, and the base components
/// drawn from them ([ShipglowsKeycap], [ShipglowsKeyButton],
/// [ShipglowsKeyHint], [ShipglowsEmptyState], [ShipglowsFocusRing]).
///
/// `ShipglowsTheme(...).applyTo(themeData)` sets the fonts, scrollbars and
/// roles in one call.
///
/// Shared packages (command bar, menu, guide, title bar) read
/// [ShipglowsTheme.of] for every value their own theme leaves out, so one
/// declaration in the app theme dresses them all alike.
library;

export 'src/components.dart';
export 'src/empty_state.dart';
export 'src/focus_ring.dart';
export 'src/theme.dart';
export 'src/typography.dart';
