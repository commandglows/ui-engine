/// Where each platform reads its releases. An empty or non-HTTPS URL turns
/// updates off on that platform.
final class ShipglowsUpdaterConfig {
  const ShipglowsUpdaterConfig({
    this.windowsFeedUrl = '',
    this.androidManifestUrl = '',
    this.checkInterval = const Duration(days: 1),
    this.enableInDebug = false,
  });

  /// WinSparkle appcast, usually
  /// `https://github.com/<owner>/shipglows-releases/releases/download/<app>-latest/appcast.xml`.
  final String windowsFeedUrl;

  /// Android manifest ([ShipglowsRelease] JSON), usually
  /// `https://github.com/<owner>/shipglows-releases/releases/download/<app>-latest/android.json`.
  final String androidManifestUrl;

  /// Background check while the app runs; WinSparkle refuses less than one
  /// hour.
  final Duration checkInterval;

  /// Debug builds are signed with the debug key and cannot take a release
  /// update; turn this on only to try the flow on a release-signed debug
  /// build.
  final bool enableInDebug;
}

/// Texts of [ShipglowsUpdateSetting]. `{version}` is the release version.
final class ShipglowsUpdaterStrings {
  const ShipglowsUpdaterStrings({
    required this.title,
    required this.check,
    required this.checking,
    required this.upToDate,
    required this.available,
    required this.install,
    required this.downloading,
    required this.needsPermission,
    required this.allow,
    required this.installing,
    required this.failedNetwork,
    required this.failedManifest,
    required this.failedChecksum,
    required this.failedSignature,
    required this.failedDowngrade,
    required this.failedInstall,
    required this.retry,
    required this.currentVersion,
  });

  static const fr = ShipglowsUpdaterStrings(
    title: 'Mises à jour',
    check: 'Rechercher une mise à jour',
    checking: 'Recherche en cours…',
    upToDate: 'L’application est à jour.',
    available: 'La version {version} est disponible.',
    install: 'Installer',
    downloading: 'Téléchargement de la version {version}…',
    needsPermission:
        'Autorisez l’installation d’applications pour cette app, puis '
        'revenez ici.',
    allow: 'Autoriser',
    installing: 'Installation de la version {version}…',
    failedNetwork: 'Impossible de vérifier les mises à jour. Réessayez plus '
        'tard.',
    failedManifest: 'Les informations de mise à jour sont invalides.',
    failedChecksum: 'Le fichier téléchargé est corrompu. Réessayez.',
    failedSignature:
        'Cette mise à jour n’est pas signée par l’éditeur de l’application. '
        'Elle n’a pas été installée.',
    failedDowngrade: 'Cette version n’est pas plus récente que la vôtre.',
    failedInstall: 'L’installation n’a pas pu démarrer.',
    retry: 'Réessayer',
    currentVersion: 'Version installée : {version}',
  );

  static const en = ShipglowsUpdaterStrings(
    title: 'Updates',
    check: 'Check for updates',
    checking: 'Checking…',
    upToDate: 'The app is up to date.',
    available: 'Version {version} is available.',
    install: 'Install',
    downloading: 'Downloading version {version}…',
    needsPermission:
        'Allow this app to install apps, then come back here.',
    allow: 'Allow',
    installing: 'Installing version {version}…',
    failedNetwork: 'Could not check for updates. Try again later.',
    failedManifest: 'The update information is not valid.',
    failedChecksum: 'The downloaded file is damaged. Try again.',
    failedSignature:
        'This update is not signed by the app’s publisher. It was not '
        'installed.',
    failedDowngrade: 'This version is not newer than yours.',
    failedInstall: 'The installer could not start.',
    retry: 'Try again',
    currentVersion: 'Installed version: {version}',
  );

  final String title;
  final String check;
  final String checking;
  final String upToDate;
  final String available;
  final String install;
  final String downloading;
  final String needsPermission;
  final String allow;
  final String installing;
  final String failedNetwork;
  final String failedManifest;
  final String failedChecksum;
  final String failedSignature;
  final String failedDowngrade;
  final String failedInstall;
  final String retry;
  final String currentVersion;
}
