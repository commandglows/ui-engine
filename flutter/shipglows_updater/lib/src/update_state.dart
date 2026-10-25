import 'update_release.dart';

/// Where the update check stands. On Windows WinSparkle draws its own window;
/// these states follow its events so a settings row can still show them.
sealed class ShipglowsUpdateState {
  const ShipglowsUpdateState();
}

/// Not started, or not supported here (debug build, store install, web).
final class ShipglowsUpdateIdle extends ShipglowsUpdateState {
  const ShipglowsUpdateIdle();
}

final class ShipglowsUpdateChecking extends ShipglowsUpdateState {
  const ShipglowsUpdateChecking();
}

final class ShipglowsUpdateUpToDate extends ShipglowsUpdateState {
  const ShipglowsUpdateUpToDate(this.checkedAt);

  final DateTime checkedAt;
}

/// A newer release; [release] is null on Windows, where WinSparkle keeps it.
final class ShipglowsUpdateAvailable extends ShipglowsUpdateState {
  const ShipglowsUpdateAvailable(this.release);

  final ShipglowsRelease? release;
}

/// Android: the APK is downloading; [progress] is null while the size is
/// unknown.
final class ShipglowsUpdateDownloading extends ShipglowsUpdateState {
  const ShipglowsUpdateDownloading(this.release, this.progress);

  final ShipglowsRelease release;
  final double? progress;
}

/// Android: the user must allow this app to install apps first
/// ([ShipglowsUpdater.openInstallPermission]); the install carries on by
/// itself when the app comes back to the foreground.
final class ShipglowsUpdateNeedsPermission extends ShipglowsUpdateState {
  const ShipglowsUpdateNeedsPermission(this.release);

  final ShipglowsRelease release;
}

/// The installer is running (Android: the system dialog is open; Windows:
/// the app is about to quit).
final class ShipglowsUpdateInstalling extends ShipglowsUpdateState {
  const ShipglowsUpdateInstalling(this.release);

  final ShipglowsRelease? release;
}

final class ShipglowsUpdateFailed extends ShipglowsUpdateState {
  const ShipglowsUpdateFailed(this.error, {this.release});

  final ShipglowsUpdateError error;

  /// The release that failed to install; null when the check failed.
  final ShipglowsRelease? release;
}

enum ShipglowsUpdateErrorKind {
  /// The manifest or appcast could not be reached.
  network,

  /// The manifest is not valid.
  manifest,

  /// The downloaded file does not match the manifest's SHA-256.
  checksum,

  /// The APK is not signed with this app's certificate, or is another app.
  signature,

  /// The APK is not newer than the installed version.
  downgrade,

  /// The system refused to open the installer, or anything else.
  install,
}

final class ShipglowsUpdateError {
  const ShipglowsUpdateError(this.kind, [this.detail]);

  final ShipglowsUpdateErrorKind kind;

  /// Technical detail for logs and « Copy details », never shown alone.
  final String? detail;

  @override
  String toString() =>
      detail == null ? 'update ${kind.name}' : 'update ${kind.name}: $detail';
}
