import 'package:flutter/foundation.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'customer_review.dart';

/// What the device says about this install and its store, read once at
/// start.
@immutable
class StoreInfo {
  const StoreInfo({
    this.platform = '',
    this.installSource = InstallSource.unknown,
    this.appVersion = '',
    this.buildNumber = '',
    this.installedAt,
    this.canPrompt = false,
    this.listing,
  });

  /// `android`, `ios`, `macos`, `windows`, `linux` or `web`.
  final String platform;
  final InstallSource installSource;
  final String appVersion;
  final String buildNumber;

  /// When the app was first installed, when the system knows.
  final DateTime? installedAt;

  /// The store's own rating prompt can be asked for (Google Play and App
  /// Store installs only).
  final bool canPrompt;

  /// The store page where the person can rate the app, or `null`.
  final ReviewStore? listing;
}

/// The store side: reads the install, asks for the rating prompt, opens the
/// store page. [InAppReviewBackend] on devices; a fake in tests.
abstract interface class StoreReviewBackend {
  Future<StoreInfo> load();

  /// Asks the store for its rating prompt. It may show nothing (quotas).
  Future<void> requestReview();

  /// Opens the store page on its review section.
  Future<void> openListing();
}

/// Google Play In-App Review on Android, `SKStoreReviewController` on iOS and
/// macOS (through `in_app_review`), the Microsoft Store page on Windows.
///
/// - [appStoreId]: the App Store id (`1234567890`), for iOS and macOS.
/// - [microsoftStoreId]: the Microsoft Store product id (`9NBLGGH4R315`).
/// - [playStoreListed]: the app is on Google Play, so a sideloaded Android
///   copy can still open its Play page (the in-app prompt needs a Play
///   install).
///
/// An empty id leaves that store out.
class InAppReviewBackend implements StoreReviewBackend {
  InAppReviewBackend({
    this.appStoreId = '',
    this.microsoftStoreId = '',
    this.playStoreListed = false,
    InAppReview? inAppReview,
  }) : _review = inAppReview ?? InAppReview.instance;

  final String appStoreId;
  final String microsoftStoreId;
  final bool playStoreListed;
  final InAppReview _review;

  static const _playInstaller = 'com.android.vending';

  /// Installers that mean « not from a store »: the system package
  /// installer (an APK opened by hand or by `shipglows_updater`) and adb.
  static const _directInstallers = {
    'com.google.android.packageinstaller',
    'com.android.packageinstaller',
    'com.android.shell',
  };

  @override
  Future<StoreInfo> load() async {
    final platform = currentPlatformName();
    PackageInfo? info;
    try {
      info = await PackageInfo.fromPlatform();
    } on Object catch (error) {
      debugPrint('shipglows_reviews: package info unavailable: $error');
    }
    final source = installSourceOf(platform, info?.installerStore);
    var canPrompt = false;
    if (source == InstallSource.googlePlay ||
        source == InstallSource.appStore) {
      try {
        canPrompt = await _review.isAvailable();
      } on Object catch (error) {
        debugPrint('shipglows_reviews: review prompt unavailable: $error');
      }
    }
    final listing = switch (platform) {
      'android' when source == InstallSource.googlePlay || playStoreListed =>
        ReviewStore.googlePlay,
      'ios' || 'macos' when appStoreId.isNotEmpty => ReviewStore.appStore,
      'windows' when microsoftStoreId.isNotEmpty => ReviewStore.microsoftStore,
      _ => null,
    };
    return StoreInfo(
      platform: platform,
      installSource: source,
      appVersion: info?.version ?? '',
      buildNumber: info?.buildNumber ?? '',
      installedAt: info?.installTime?.toUtc(),
      canPrompt: canPrompt,
      listing: listing,
    );
  }

  @override
  Future<void> requestReview() => _review.requestReview();

  @override
  Future<void> openListing() => _review.openStoreListing(
    appStoreId: appStoreId.isEmpty ? null : appStoreId,
    microsoftStoreId: microsoftStoreId.isEmpty ? null : microsoftStoreId,
  );

  /// Where [installer] (`PackageInfo.installerStore`) says this copy came
  /// from on [platform].
  @visibleForTesting
  static InstallSource installSourceOf(String platform, String? installer) {
    if (platform == 'web') return InstallSource.web;
    if (platform == 'android') {
      if (installer == _playInstaller) return InstallSource.googlePlay;
      if (installer == null || _directInstallers.contains(installer)) {
        return InstallSource.direct;
      }
      return InstallSource.unknown;
    }
    return switch (installer) {
      'com.apple' => InstallSource.appStore,
      'com.apple.testflight' => InstallSource.testFlight,
      null => InstallSource.direct,
      _ => InstallSource.unknown,
    };
  }
}

/// `android`, `ios`, `macos`, `windows`, `linux`, `fuchsia` or `web`.
String currentPlatformName() =>
    kIsWeb ? 'web' : defaultTargetPlatform.name.toLowerCase();
