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
  /// `https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/appcast.xml`.
  final String windowsFeedUrl;

  /// Android manifest ([ShipglowsRelease] JSON), usually
  /// `https://github.com/dianedef/shipglows-releases/releases/download/<app>-latest/android.json`.
  final String androidManifestUrl;

  /// Background check while the app runs; WinSparkle refuses less than one
  /// hour.
  final Duration checkInterval;

  /// Debug builds are signed with the debug key and cannot take a release
  /// update; turn this on only to try the flow on a release-signed debug
  /// build.
  final bool enableInDebug;
}

/// Texts of the update widgets. `{app}` is the app name, `{version}` the
/// release version, `{current}` the installed one, `{percent}` the download.
final class ShipglowsUpdaterStrings {
  const ShipglowsUpdaterStrings({
    required this.title,
    required this.check,
    required this.checking,
    required this.upToDate,
    required this.upToDateLong,
    required this.available,
    required this.dialogTitle,
    required this.dialogAvailable,
    required this.whatHappensAndroid,
    required this.notesLabel,
    required this.install,
    required this.installNow,
    required this.later,
    required this.skipVersion,
    required this.hide,
    required this.close,
    required this.seeUpdate,
    required this.downloading,
    required this.needsPermission,
    required this.needsPermissionLong,
    required this.allow,
    required this.installing,
    required this.installingAndroid,
    required this.reopenInstaller,
    required this.failedNetwork,
    required this.failedManifest,
    required this.failedChecksum,
    required this.failedSignature,
    required this.failedDowngrade,
    required this.failedInstall,
    required this.retry,
    required this.currentVersion,
    required this.pillAvailable,
    required this.pillAvailableShort,
    required this.pillDownloading,
    required this.pillInstalling,
    required this.pillFailed,
  });

  static const fr = ShipglowsUpdaterStrings(
    title: 'Mises à jour',
    check: 'Rechercher une mise à jour',
    checking: 'Recherche en cours…',
    upToDate: 'L’application est à jour.',
    upToDateLong: 'Vous avez la dernière version de {app} ({version}).',
    available: 'La version {version} est disponible.',
    dialogTitle: 'Nouvelle version disponible',
    dialogAvailable: '{app} {version} est prêt à être installé. Vous utilisez la version {current}.',
    whatHappensAndroid: 'Android vous demandera de confirmer l’installation. Vos comptes et réglages restent en place.',
    notesLabel: 'Nouveautés',
    install: 'Installer',
    installNow: 'Installer maintenant',
    later: 'Plus tard',
    skipVersion: 'Ne plus me rappeler pour cette version',
    hide: 'Masquer',
    close: 'Fermer',
    seeUpdate: 'Voir la mise à jour',
    downloading: 'Téléchargement de la version {version}…',
    needsPermission: 'Autorisez l’installation d’applications pour cette app : l’installation reprendra à votre retour.',
    needsPermissionLong: 'Pour installer la mise à jour, Android doit autoriser {app} à installer des applications. C’est à faire une seule fois : activez l’option, puis revenez ici, l’installation reprendra.',
    allow: 'Ouvrir les réglages',
    installing: 'Installation de la version {version}…',
    installingAndroid: 'L’installateur Android est ouvert : touchez « Mettre à jour » pour terminer. Si vous l’avez fermé, vous pouvez le rouvrir.',
    reopenInstaller: 'Rouvrir l’installateur',
    failedNetwork:
        'Impossible de vérifier les mises à jour. Réessayez plus tard.',
    failedManifest: 'Les informations de mise à jour sont invalides.',
    failedChecksum: 'Le fichier téléchargé est corrompu. Réessayez.',
    failedSignature: 'Cette mise à jour n’est pas signée par l’éditeur de l’application. Elle n’a pas été installée.',
    failedDowngrade: 'Cette version n’est pas plus récente que la vôtre.',
    failedInstall: 'L’installation n’a pas pu démarrer.',
    retry: 'Réessayer',
    currentVersion: 'Version installée : {version}',
    pillAvailable: 'Version {version} disponible',
    pillAvailableShort: 'Mise à jour disponible',
    pillDownloading: 'Mise à jour : {percent} %',
    pillInstalling: 'Installation en cours…',
    pillFailed: 'Mise à jour interrompue',
  );

  static const en = ShipglowsUpdaterStrings(
    title: 'Updates',
    check: 'Check for updates',
    checking: 'Checking…',
    upToDate: 'The app is up to date.',
    upToDateLong: 'You have the latest version of {app} ({version}).',
    available: 'Version {version} is available.',
    dialogTitle: 'New version available',
    dialogAvailable:
        '{app} {version} is ready to install. You are using version {current}.',
    whatHappensAndroid: 'Android will ask you to confirm the install. Your accounts and settings stay as they are.',
    notesLabel: 'What’s new',
    install: 'Install',
    installNow: 'Install now',
    later: 'Later',
    skipVersion: 'Don’t remind me about this version',
    hide: 'Hide',
    close: 'Close',
    seeUpdate: 'See the update',
    downloading: 'Downloading version {version}…',
    needsPermission: 'Allow this app to install apps: the install carries on when you come back.',
    needsPermissionLong: 'To install the update, Android needs to let {app} install apps. You only do this once: turn the option on, then come back here and the install carries on.',
    allow: 'Open settings',
    installing: 'Installing version {version}…',
    installingAndroid: 'The Android installer is open: tap « Update » to finish. If you closed it, you can open it again.',
    reopenInstaller: 'Open the installer again',
    failedNetwork: 'Could not check for updates. Try again later.',
    failedManifest: 'The update information is not valid.',
    failedChecksum: 'The downloaded file is damaged. Try again.',
    failedSignature: 'This update is not signed by the app’s publisher. It was not installed.',
    failedDowngrade: 'This version is not newer than yours.',
    failedInstall: 'The installer could not start.',
    retry: 'Try again',
    currentVersion: 'Installed version: {version}',
    pillAvailable: 'Version {version} available',
    pillAvailableShort: 'Update available',
    pillDownloading: 'Update: {percent} %',
    pillInstalling: 'Installing…',
    pillFailed: 'Update interrupted',
  );

  final String title;
  final String check;
  final String checking;
  final String upToDate;
  final String upToDateLong;
  final String available;
  final String dialogTitle;
  final String dialogAvailable;
  final String whatHappensAndroid;
  final String notesLabel;
  final String install;
  final String installNow;
  final String later;
  final String skipVersion;
  final String hide;
  final String close;
  final String seeUpdate;
  final String downloading;
  final String needsPermission;
  final String needsPermissionLong;
  final String allow;
  final String installing;
  final String installingAndroid;
  final String reopenInstaller;
  final String failedNetwork;
  final String failedManifest;
  final String failedChecksum;
  final String failedSignature;
  final String failedDowngrade;
  final String failedInstall;
  final String retry;
  final String currentVersion;
  final String pillAvailable;
  final String pillAvailableShort;
  final String pillDownloading;
  final String pillInstalling;
  final String pillFailed;
}
