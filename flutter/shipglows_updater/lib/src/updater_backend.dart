import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'update_state.dart';
import 'updater_config.dart';

/// One platform's update mechanism, driven by [ShipglowsUpdater].
abstract interface class UpdaterBackend {
  /// The installed version once [start] ran; null when unknown.
  AppVersion? get currentVersion;

  /// False when this install takes no updates from here (Android store
  /// install); the updater then stays idle.
  Future<bool> start({
    required ShipglowsUpdaterConfig config,
    required ValueSetter<ShipglowsUpdateState> emit,
    required Future<void> Function()? quitForUpdate,
  });

  Future<void> check({required bool userInitiated});

  Future<void> install();

  void dispose();
}

/// The HTTPS URL in [url], or null: updates are never read over plain HTTP.
Uri? httpsUrl(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}
