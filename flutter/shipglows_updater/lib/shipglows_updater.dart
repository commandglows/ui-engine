/// Release updates for ShipGlows Flutter apps behind one API:
/// `ShipglowsUpdater.instance.start(config)`, `checkNow()`, `install()` and
/// a `state` to listen to.
///
/// - Windows (release builds): WinSparkle through `auto_updater`, fed by a
///   signed appcast; WinSparkle shows its own window and runs the installer.
/// - Android (release builds installed from an APK): a JSON manifest, the
///   APK downloaded, its SHA-256 and signing certificate checked, then the
///   system installer. Builds installed from the Play Store are left to the
///   store.
///
/// Elsewhere (debug builds, web, other platforms) every call does nothing.
library;

export 'src/app_version.dart';
export 'src/update_release.dart';
export 'src/update_state.dart';
export 'src/update_widgets.dart';
export 'src/updater.dart';
export 'src/updater_config.dart';
