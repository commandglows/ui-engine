import 'dart:async';

import 'package:auto_updater/auto_updater.dart';
import 'package:flutter/foundation.dart';

import 'app_version.dart';
import 'update_state.dart';
import 'updater_backend.dart';
import 'updater_config.dart';

/// Thin seam over the auto_updater plugin so the policy stays testable.
abstract interface class WinSparklePlatform {
  Future<void> setFeedURL(String feedUrl);
  Future<void> setScheduledCheckInterval(int seconds);
  Future<void> checkForUpdates({bool? inBackground});
  void addListener(UpdaterListener listener);
  void removeListener(UpdaterListener listener);
}

final class AutoUpdaterWinSparklePlatform implements WinSparklePlatform {
  const AutoUpdaterWinSparklePlatform();

  @override
  Future<void> setFeedURL(String feedUrl) => autoUpdater.setFeedURL(feedUrl);

  @override
  Future<void> setScheduledCheckInterval(int seconds) =>
      autoUpdater.setScheduledCheckInterval(seconds);

  @override
  Future<void> checkForUpdates({bool? inBackground}) =>
      autoUpdater.checkForUpdates(inBackground: inBackground);

  @override
  void addListener(UpdaterListener listener) =>
      autoUpdater.addListener(listener);

  @override
  void removeListener(UpdaterListener listener) =>
      autoUpdater.removeListener(listener);
}

/// WinSparkle reads the signed appcast, shows its own window, downloads the
/// installer, checks its DSA signature against the `DSAPub` resource of the
/// runner and runs it; the app quits first so the installer can replace it.
/// Taken from ContentGlows' `windows_app_updater.dart`.
final class WindowsUpdaterBackend
    with UpdaterListener
    implements UpdaterBackend {
  WindowsUpdaterBackend({
    required this.feedUrl,
    this.platform = const AutoUpdaterWinSparklePlatform(),
  });

  final Uri feedUrl;
  final WinSparklePlatform platform;
  ValueSetter<ShipglowsUpdateState>? _emit;
  Future<void> Function()? _quit;

  @override
  AppVersion? get currentVersion => null;

  @override
  Future<bool> start({
    required ShipglowsUpdaterConfig config,
    required ValueSetter<ShipglowsUpdateState> emit,
    required Future<void> Function()? quitForUpdate,
  }) async {
    _emit = emit;
    _quit = quitForUpdate;
    platform.addListener(this);
    await platform.setFeedURL(feedUrl.toString());
    final seconds = config.checkInterval.inSeconds;
    await platform.setScheduledCheckInterval(seconds < 3600 ? 3600 : seconds);
    await platform.checkForUpdates(inBackground: true);
    return true;
  }

  @override
  Future<void> check({required bool userInitiated}) =>
      platform.checkForUpdates(inBackground: !userInitiated);

  /// WinSparkle installs from its own window: show it.
  @override
  Future<void> install() => platform.checkForUpdates(inBackground: false);

  @override
  Future<void> openInstallPermission() async {}

  @override
  void dispose() => platform.removeListener(this);

  @override
  void onUpdaterCheckingForUpdate(Appcast? appcast) =>
      _emit?.call(const ShipglowsUpdateChecking());

  @override
  void onUpdaterUpdateAvailable(AppcastItem? appcastItem) =>
      _emit?.call(const ShipglowsUpdateAvailable(null));

  @override
  void onUpdaterUpdateNotAvailable(UpdaterError? error) =>
      _emit?.call(ShipglowsUpdateUpToDate(DateTime.now()));

  @override
  void onUpdaterError(UpdaterError? error) => _emit?.call(
    ShipglowsUpdateFailed(
      ShipglowsUpdateError(ShipglowsUpdateErrorKind.network, error?.message),
    ),
  );

  @override
  void onUpdaterUpdateDownloaded(AppcastItem? appcastItem) {}

  @override
  void onUpdaterBeforeQuitForUpdate(AppcastItem? appcastItem) {
    _emit?.call(const ShipglowsUpdateInstalling(null));
    // The installer replaces app.exe; a resident shell must release it.
    final quit = _quit;
    if (quit != null) unawaited(quit());
  }
}
