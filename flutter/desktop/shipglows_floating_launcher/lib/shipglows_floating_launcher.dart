/// A persistent floating launcher (Windows; no-op elsewhere): a round bubble
/// in its own always-on-top window whose actions fan out on hover.
///
/// The app's engine publishes a [ShipglowsFloatingLauncherSnapshot] and shows
/// the launcher with [ShipglowsFloatingLauncher]; the launcher runs in its
/// own engine, started by [runShipglowsFloatingLauncherOverlay], and reports
/// the action clicked. The app runs it itself.
library;

export 'src/floating_launcher.dart';
export 'src/geometry.dart' show ShipglowsFloatingLauncherGeometry;
export 'src/launcher_overlay.dart';
export 'src/snapshot.dart';
