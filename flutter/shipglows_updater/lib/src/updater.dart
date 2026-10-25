import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'platform_backend_stub.dart'
    if (dart.library.io) 'platform_backend_io.dart';
import 'update_state.dart';
import 'updater_backend.dart';
import 'updater_config.dart';

/// The app's update service: one per process, started once after the first
/// frame. Wire `checkNow` to « Rechercher une mise à jour » (tray, menu) and
/// show [ShipglowsUpdateSetting] in the settings.
///
/// ```dart
/// unawaited(ShipglowsUpdater.instance.start(
///   const ShipglowsUpdaterConfig(
///     windowsFeedUrl: String.fromEnvironment('WINDOWS_UPDATE_FEED_URL'),
///     androidManifestUrl: String.fromEnvironment('ANDROID_UPDATE_MANIFEST_URL'),
///   ),
///   quitForUpdate: () => ShipglowsTray.instance.quit(),
/// ));
/// ```
class ShipglowsUpdater {
  ShipglowsUpdater._();

  static final instance = ShipglowsUpdater._();

  final ValueNotifier<ShipglowsUpdateState> _state = ValueNotifier(
    const ShipglowsUpdateIdle(),
  );
  UpdaterBackend? _backend;
  Future<void>? _starting;

  ValueListenable<ShipglowsUpdateState> get state => _state;

  /// True once started on a platform and install that take updates here.
  bool get isActive => _backend != null;

  /// The installed version as Android reports it; null on Windows, where
  /// WinSparkle reads it from the executable.
  AppVersion? get currentVersion => _backend?.currentVersion;

  /// Idempotent. Release builds only, unless
  /// [ShipglowsUpdaterConfig.enableInDebug]. [quitForUpdate] runs on Windows
  /// right before the installer replaces the executable: close the tray and
  /// any resident window there.
  Future<void> start(
    ShipglowsUpdaterConfig config, {
    Future<void> Function()? quitForUpdate,
    @visibleForTesting UpdaterBackend? backend,
  }) => _starting ??= _start(config, quitForUpdate, backend);

  Future<void> _start(
    ShipglowsUpdaterConfig config,
    Future<void> Function()? quitForUpdate,
    UpdaterBackend? override,
  ) async {
    if (!kReleaseMode && !config.enableInDebug && override == null) return;
    final backend = override ?? createPlatformBackend(config);
    if (backend == null) return;
    try {
      final active = await backend.start(
        config: config,
        emit: (state) => _state.value = state,
        quitForUpdate: quitForUpdate,
      );
      if (active) {
        _backend = backend;
      } else {
        backend.dispose();
      }
    } on Exception catch (error) {
      // An updater that cannot start must never stop the app.
      debugPrint('shipglows_updater: not started: $error');
      backend.dispose();
    }
  }

  /// A check the user asked for: Windows shows WinSparkle's window, Android
  /// updates [state].
  Future<void> checkNow() async {
    await _starting;
    await _backend?.check(userInitiated: true);
  }

  /// Installs the release found by the last check (Android), or shows
  /// WinSparkle's window (Windows).
  Future<void> install() async {
    await _starting;
    await _backend?.install();
  }
}
